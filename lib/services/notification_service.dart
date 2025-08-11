import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Initializes the notification service
  Future<void> init() async {
    // Request permission for notifications from the user (for iOS and Android 13+)
    await _firebaseMessaging.requestPermission();

    // Get the FCM token for this device
    final fcmToken = await _firebaseMessaging.getToken();
    print('FCM Token: $fcmToken');
    if (fcmToken != null) {
      await _saveTokenToSupabase(fcmToken);
    }

    // Listen for token refresh and save the new token
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToSupabase);

    // Listen for incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Here you could show a local notification using a package like flutter_local_notifications
      }
    });
  }

  // Saves the FCM token to the current user's profile in Supabase
  Future<void> _saveTokenToSupabase(String token) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      try {
        // We assume you have a 'profiles' table with an 'fcm_token' column
        await _supabase
            .from('profiles')
            .update({'fcm_token': token}).eq('id', currentUser.id);
        print('FCM token saved to Supabase for user ${currentUser.id}');
      } catch (e) {
        print('Error saving FCM token to Supabase: $e');
      }
    }
  }

  // Call this method on logout to remove the token
  Future<void> removeTokenOnLogout() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'fcm_token': null}).eq('id', currentUser.id);
        print('FCM token removed from Supabase for user ${currentUser.id}');
      } catch (e) {
        print('Error removing FCM token from Supabase: $e');
      }
    }
  }
}
