import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  
  factory SupabaseService() {
    return _instance;
  }
  
  SupabaseService._internal();

  static Future<void> initialize() async {
    // Load credentials from the .env file
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Supabase URL and Anon Key must be provided in .env file');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Auth shortcuts
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;
  static AppAuthState get authState => client.auth.currentSession != null 
    ? AppAuthState.signedIn 
    : AppAuthState.signedOut;
  static Stream<AuthState> get onAuthStateChange => client.auth.onAuthStateChange;
}

// Renamed to avoid conflict with Supabase's AuthState
enum AppAuthState {
  signedIn,
  signedOut
}
