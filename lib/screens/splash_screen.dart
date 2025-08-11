import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    await Future.delayed(
        const Duration(seconds: 2)); // ✅ Simulated Splash Delay

    // Check if user is signed in with Supabase
    User? user = SupabaseService.currentUser;

    if (user != null) {
      // Get user role from Supabase
      String userRole = "User";
      try {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single();

        userRole = profile['role'] ?? "User";
      } catch (e) {
        print("Error fetching user role: $e");
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(userId: user.id, userRole: userRole)),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFF1E6FF)
            ], // ✅ White to light purple
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Text(
            "Black",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black, // ✅ Now in Black
            ),
          ),
        ),
      ),
    );
  }
}
