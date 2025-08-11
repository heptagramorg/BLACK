import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  final String uid;
  final String name;
  final String email;
  final String? profilePictureUrl;

  const UserSelectionScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
    this.profilePictureUrl,
  });

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Directly insert the new user's profile with the selected role.
      final supabase = Supabase.instance.client;
      await supabase.from('profiles').insert({
        'id': widget.uid,
        'name': widget.name,
        'email': widget.email,
        'role': role,
        'profile_picture': widget.profilePictureUrl,
        // Generate a simple default username. Consider a more robust unique username strategy.
        'username': widget.email.split('@').first,
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(userId: widget.uid, userRole: role)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save role: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome! To get started, please tell us who you are.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 40),
                    _buildRoleCard(
                      context,
                      icon: Icons.school_outlined,
                      role: 'Student',
                      onTap: () => _selectRole('Student'),
                    ),
                    const SizedBox(height: 20),
                    _buildRoleCard(
                      context,
                      icon: Icons.work_outline,
                      role: 'Teacher',
                      onTap: () => _selectRole('Teacher'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context,
      {required IconData icon,
      required String role,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 280,
          height: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Theme.of(context).primaryColor),
              const SizedBox(height: 10),
              Text(
                'I am a $role',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
