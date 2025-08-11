import 'package:flutter/material.dart';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreenAnimation extends StatefulWidget {
  // FIX: Use const with the constructor for performance improvement.
  const SplashScreenAnimation({super.key});

  @override
  State<SplashScreenAnimation> createState() => _SplashScreenAnimationState();
}

class _SplashScreenAnimationState extends State<SplashScreenAnimation> {
  // FIX: This field was unused and has been removed.
  // bool _checkingAuth = false;

  // HTML content for splash screen animation
  final String htmlContent = '''
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>BLACK Logo Animation</title>
    <style>
      body { margin: 0; background-color: #000; height: 100vh; display: flex; justify-content: center; align-items: center; font-family: Arial, sans-serif; overflow: hidden; }
      .logo-container { position: relative; display: flex; align-items: center; }
      .logo-text { display: flex; font-size: 3rem; font-weight: bold; color: white; z-index: 1; }
      .letter { opacity: 0; animation: fadeInLetter 0.4s ease forwards; }
      .letter:nth-child(1) { animation-delay: 1.6s; }
      .letter:nth-child(2) { animation-delay: 1.8s; }
      .letter:nth-child(3) { animation-delay: 2s; }
      .letter:nth-child(4) { animation-delay: 2.2s; }
      .letter:nth-child(5) { animation-delay: 2.4s; }
      .letter:nth-child(6) { animation-delay: 2.6s; }
      @keyframes fadeInLetter { 0% { opacity: 0; transform: translateY(10px); } 100% { opacity: 1; transform: translateY(0); } }
      .logo-text.glow { animation: glowText 2s ease-in-out forwards; animation-delay: 1.5s; }
      @keyframes glowText { 0% { text-shadow: 0 0 0px white; } 50% { text-shadow: 0 0 20px white; } 100% { text-shadow: 0 0 0px white; } }
      .burst-spinner { position: absolute; left: -25px; top: -50px; width: 60px; height: 60px; animation: spinOnce 1.5s ease-out forwards; pointer-events: none; }
      .burst-line { position: absolute; width: 2px; height: 30px; background-color: white; top: 50%; left: 50%; transform-origin: bottom center; }
      .burst-line:nth-child(1) { transform: rotate(0deg) translateY(-50%); }
      .burst-line:nth-child(2) { transform: rotate(45deg) translateY(-50%); }
      .burst-line:nth-child(3) { transform: rotate(90deg) translateY(-50%); }
      .burst-line:nth-child(4) { transform: rotate(135deg) translateY(-50%); }
      .burst-line:nth-child(5) { transform: rotate(180deg) translateY(-50%); }
      .burst-line:nth-child(6) { transform: rotate(225deg) translateY(-50%); }
      .burst-line:nth-child(7) { transform: rotate(270deg) translateY(-50%); }
      .burst-line:nth-child(8) { transform: rotate(315deg) translateY(-50%); }
      @keyframes spinOnce { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
      @keyframes fadeUp { from { opacity: 1; transform: rotate(var(--angle)) translateY(-50%); } to { opacity: 0; transform: rotate(0deg) translateY(-50%); } }
    </style>
  </head>
  <body>
    <div class="logo-container">
      <div class="burst-spinner" id="spinner">
        <div class="burst-line" style="--angle: 0deg;"></div> <div class="burst-line" style="--angle: 45deg;"></div> <div class="burst-line" style="--angle: 90deg;"></div> <div class="burst-line" style="--angle: 135deg;"></div> <div class="burst-line" style="--angle: 180deg;"></div> <div class="burst-line" style="--angle: 225deg;"></div> <div class="burst-line" style="--angle: 270deg;"></div> <div class="burst-line" style="--angle: 315deg;"></div>
      </div>
      <div class="logo-text glow">
        <span class="letter">B</span> <span class="letter">L</span> <span class="letter">A</span> <span class="letter">C</span> <span class="letter">K</span> <span class="letter">.</span>
      </div>
    </div>
    <script>
      setTimeout(() => {
        const spinner = document.getElementById('spinner');
        if (spinner) {
            const lines = spinner.querySelectorAll('.burst-line');
           [2, 3, 4].forEach(i => { if (lines[i]) { lines[i].style.animation = "fadeUp 1s ease forwards"; } });
           spinner.style.animation = "none"; spinner.style.transform = "rotate(0deg)";
        }
      }, 1500);
    </script>
  </body>
  </html>
  ''';

  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ConnectivityResult> _currentConnectivity = [ConnectivityResult.none];

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

    _startAnimationSequence();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 4000));
    if (mounted) {
      await _checkConnectivityAndProceed();
      _listenForConnectivityChanges();
    }
  }

  Future<void> _checkConnectivityAndProceed() async {
    if (!mounted) return;

    try {
      _currentConnectivity = await Connectivity().checkConnectivity();
      // FIX: Replaced print with debugPrint for better practice.
      debugPrint("Initial Connectivity Check: $_currentConnectivity");

      final bool isOffline = _currentConnectivity
              .every((result) => result == ConnectivityResult.none) ||
          _currentConnectivity.isEmpty;

      if (isOffline) {
        await _showNoConnectionDialog();
      } else {
        await _checkUserSessionAndNavigate();
      }
    } catch (e) {
      debugPrint("Error checking connectivity: $e");
      if (mounted) {
        await _showNoConnectionDialog(error: "Could not check connection.");
      }
    }
  }

  Future<void> _showNoConnectionDialog({String? error}) async {
    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);
      if (currentRoute is DialogRoute) {
        debugPrint("Dialog already potentially showing.");
        return;
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('No Internet Connection')),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                error ??
                    'An active internet connection is required to use Black. Please connect and try again.',
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Retry'),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    await _checkConnectivityAndProceed();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _listenForConnectivityChanges() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      debugPrint("Connectivity Changed: $result");
      if (!mounted) return;

      bool wasOffline =
          _currentConnectivity.every((res) => res == ConnectivityResult.none) ||
              _currentConnectivity.isEmpty;
      _currentConnectivity = result;
      bool isOffline =
          _currentConnectivity.every((res) => res == ConnectivityResult.none) ||
              _currentConnectivity.isEmpty;

      if (isOffline && !wasOffline) {
        _showNoConnectionDialog();
      } else if (!isOffline && wasOffline) {
        debugPrint(
            "Connection restored. Closing potential no-connection dialog.");
        if (Navigator.of(context).canPop()) {
          final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);
          if (currentRoute is DialogRoute) {
            Navigator.of(context).pop();
            _checkConnectivityAndProceed();
          }
        }
      }
    });
  }

  Future<void> _checkUserSessionAndNavigate() async {
    if (!mounted) return;

    final bool isOffline = _currentConnectivity
            .every((result) => result == ConnectivityResult.none) ||
        _currentConnectivity.isEmpty;

    if (isOffline) {
      debugPrint(
          "Still offline, showing dialog again instead of checking session.");
      await _showNoConnectionDialog();
      return;
    }

    debugPrint("Connection OK. Checking user session...");

    try {
      await Future.delayed(const Duration(milliseconds: 50));

      final session = SupabaseService.client.auth.currentSession;
      final user = SupabaseService.client.auth.currentUser;

      debugPrint("Current Session: ${session != null}");
      debugPrint("Current User: ${user?.id}");

      if (session != null && user != null) {
        String userRole = "User";
        try {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .single();
          userRole = profile['role'] ?? "User";
          debugPrint("User role fetched: $userRole");
        } catch (e) {
          debugPrint("Error fetching user role: $e. Using default role.");
        }

        if (mounted) {
          debugPrint("Navigating to HomeScreen for user ${user.id}");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    HomeScreen(userId: user.id, userRole: userRole)),
          );
        }
      } else {
        if (mounted) {
          debugPrint("Navigating to LoginScreen");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint("Error during authentication check/navigation: $e");
      if (mounted) {
        debugPrint(
            "Error checking session, navigating to LoginScreen as fallback.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error checking login status: ${e.toString()}"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
