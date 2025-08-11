// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoadingEvents = false;

  static const String _localEventsKey = 'calendar_local_events';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadLocalEvents();
  }

  Future<void> _loadLocalEvents() async {
    if (!mounted) return;
    setState(() => _isLoadingEvents = true);
    final prefs = await SharedPreferences.getInstance();
    final String? eventsString = prefs.getString(_localEventsKey);

    final Map<DateTime, List<Map<String, dynamic>>> loadedEvents = {};
    if (eventsString != null && eventsString.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedEventsJson = jsonDecode(eventsString);
        decodedEventsJson.forEach((dateString, eventListJson) {
          final DateTime dayKey = DateTime.parse(dateString);
          final List<Map<String, dynamic>> eventsOnDay =
              (eventListJson as List).map((eventData) {
            final Map<String, dynamic> eventMap =
                Map<String, dynamic>.from(eventData);
            if (eventMap['date'] != null) {
              eventMap['date'] = DateTime.tryParse(eventMap['date'] as String);
            }
            if (eventMap['created_at'] != null) {
              eventMap['created_at'] =
                  DateTime.tryParse(eventMap['created_at'] as String);
            }
            return eventMap;
          }).toList();
          loadedEvents[dayKey] = eventsOnDay;
        });
      } catch (e) {
        // Handle error silently in production
        debugPrint("Failed to decode local events: $e");
        await prefs.remove(_localEventsKey);
      }
    }

    if (mounted) {
      setState(() {
        _events = loadedEvents;
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _saveLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> eventsToSaveJson = {};

    _events.forEach((dateTimeKey, eventList) {
      eventsToSaveJson[dateTimeKey.toIso8601String()] = eventList.map((event) {
        final Map<String, dynamic> eventMap = Map<String, dynamic>.from(event);
        if (eventMap['date'] != null && eventMap['date'] is DateTime) {
          eventMap['date'] = (eventMap['date'] as DateTime).toIso8601String();
        }
        if (eventMap['created_at'] != null &&
            eventMap['created_at'] is DateTime) {
          eventMap['created_at'] =
              (eventMap['created_at'] as DateTime).toIso8601String();
        }
        return eventMap;
      }).toList();
    });

    final String eventsString = jsonEncode(eventsToSaveJson);
    await prefs.setString(_localEventsKey, eventsString);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _events[dayKey] ?? [];
  }

  void _addEvent(String title, DateTime date) {
    final dayKey = DateTime(date.year, date.month, date.day);
    final newEvent = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'date': date,
      'created_at': DateTime.now(),
    };

    setState(() {
      if (_events[dayKey] == null) {
        _events[dayKey] = [];
      }
      _events[dayKey]!.add(newEvent);
      _events[dayKey]!.sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    });
    _saveLocalEvents();
  }

  void _deleteEventFromLocal(String eventId, DateTime eventDate) {
    final dayKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
    setState(() {
      _events[dayKey]?.removeWhere((event) => event['id'] == eventId);
      if (_events[dayKey]?.isEmpty ?? false) {
        _events.remove(dayKey);
      }
    });
    _saveLocalEvents();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendar & Events"),
        elevation: 0.5,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<CalendarFormat>(
              initialValue: _calendarFormat,
              onSelected: (format) {
                if (_calendarFormat != format) {
                  setState(() => _calendarFormat = format);
                }
              },
              icon: Icon(Icons.calendar_view_month_outlined,
                  color: theme.appBarTheme.foregroundColor),
              tooltip: "Change Calendar View",
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                    value: CalendarFormat.month, child: Text('Month View')),
                const PopupMenuItem(
                    value: CalendarFormat.twoWeeks,
                    child: Text('2 Weeks View')),
                const PopupMenuItem(
                    value: CalendarFormat.week, child: Text('Week View')),
              ],
              offset: const Offset(0, kToolbarHeight),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(theme, isDarkMode),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  _selectedDay != null
                      ? DateFormat('EEEE, MMMM d').format(_selectedDay!)
                      : "Events",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isLoadingEvents && _events.isEmpty)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Expanded(child: _buildEventList(theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEventDialog(theme),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add Event"),
        elevation: 4.0,
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.2).round() = 51, (255 * 0.1).round() = 26
            color: theme.shadowColor.withAlpha(isDarkMode ? 51 : 26),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(DateTime.now().year - 5, 1, 1),
        lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle:
              theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: theme.iconTheme.color),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: theme.iconTheme.color),
          headerPadding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle:
              theme.textTheme.bodyMedium!.copyWith(color: theme.hintColor),
          // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.8).round() = 204
          weekendStyle: theme.textTheme.bodyMedium!
              .copyWith(color: theme.colorScheme.primary.withAlpha(204)),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: theme.textTheme.bodyMedium!,
          weekendTextStyle: theme.textTheme.bodyMedium!
              .copyWith(color: theme.colorScheme.primary),
          todayDecoration: BoxDecoration(
            // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.2).round() = 51
            color: theme.colorScheme.primary.withAlpha(51),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
          todayTextStyle: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          markersAlignment: Alignment.bottomCenter,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              return Positioned(
                right: 5,
                bottom: 5,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.9).round() = 230
                    color: theme.colorScheme.secondary.withAlpha(230),
                  ),
                  width: 6.0,
                  height: 6.0,
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  void _addEventDialog(ThemeData theme) {
    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select a day first."),
            backgroundColor: Colors.orange),
      );
      return;
    }
    TextEditingController eventController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title:
              Text("Add Event for ${DateFormat.yMMMd().format(_selectedDay!)}"),
          content: TextField(
            controller: eventController,
            decoration: InputDecoration(
              hintText: "Enter Event Details",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.3).round() = 77
              fillColor:
                  theme.colorScheme.surfaceContainerHighest.withAlpha(77),
            ),
            autofocus: true,
            minLines: 1,
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (eventController.text.trim().isNotEmpty) {
                  _addEvent(eventController.text.trim(), _selectedDay!);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Event added locally."),
                        backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text("Event title cannot be empty."),
                        backgroundColor: Colors.orange),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventList(ThemeData theme) {
    if (_selectedDay == null) {
      return const Center(
          child: Text("Select a day to see events.",
              style: TextStyle(color: Colors.grey)));
    }
    final eventsForSelectedDay = _getEventsForDay(_selectedDay!);

    if (eventsForSelectedDay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text("No events for this day.",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text("Tap the '+' button to add an event.",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: eventsForSelectedDay.length,
      itemBuilder: (context, index) {
        var event = eventsForSelectedDay[index];
        DateTime createdAt = event['created_at'] is DateTime
            ? event['created_at']
            : DateTime.parse(event['created_at'] as String);
        DateTime eventDate = event['date'] is DateTime
            ? event['date']
            : DateTime.parse(event['date'] as String);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            leading: CircleAvatar(
              // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.15).round() = 38
              backgroundColor: theme.colorScheme.primary.withAlpha(38),
              child: Icon(Icons.event_note_outlined,
                  color: theme.colorScheme.primary),
            ),
            title: Text(
              event['title'] ?? "Event",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "Added: ${DateFormat('MMM d, HH:mm').format(createdAt)}",
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            trailing: IconButton(
              // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.8).round() = 204
              icon: Icon(Icons.delete_outline_rounded,
                  color: theme.colorScheme.error.withAlpha(204)),
              onPressed: () =>
                  _deleteEventDialog(event['id'] as String, eventDate, theme),
              tooltip: "Delete Event",
            ),
          ),
        );
      },
    );
  }

  void _deleteEventDialog(
      String eventId, DateTime eventDate, ThemeData theme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Event?"),
        content: const Text(
            "Are you sure you want to delete this event? This will only remove it from this device."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _deleteEventFromLocal(eventId, eventDate);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Event deleted from this device."),
            backgroundColor: Colors.green),
      );
    }
  }
}
