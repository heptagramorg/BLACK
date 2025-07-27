import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart' as app_supabase; // aliased import

class AuthService {
  final SupabaseClient _supabase = app_supabase.SupabaseService.client;

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<User> signInWithEmail(String email, String password) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const AuthException('Sign in failed: No user returned.');
      }
      // Optionally update last login time in profiles table
      await _supabase
          .from('profiles')
          .update({'last_login': DateTime.now().toIso8601String()})
          .eq('id', response.user!.id);
      return response.user!;
    } on AuthException catch (e) {
      print("AuthService - signInWithEmail Error: ${e.message}");
      rethrow;
    } catch (e) {
      print("AuthService - signInWithEmail Unexpected Error: $e");
      throw Exception("An unexpected error occurred during sign in.");
    }
  }

  /// **Signs in with Google and links the account to Supabase.**
  Future<User?> signInWithGoogle() async {
    try {
      final webClientId = dotenv.env['WEB_CLIENT_ID'];
      if (webClientId == null) {
        throw 'WEB_CLIENT_ID not found in .env file. Please add it.';
      }

      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print("Google Sign-In was cancelled by the user.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Google Sign-In failed: Missing ID Token.';
      }

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      
      final user = response.user;
      if (user == null) {
        throw const AuthException('Supabase sign-in failed after Google auth.');
      }

      // Check if a profile exists to determine if this is the first login
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      final userMetadata = user.userMetadata;
      final Map<String, dynamic> profileData = {
        'id': user.id,
        'name': userMetadata?['full_name'] ?? userMetadata?['name'] ?? 'No Name',
        'username': user.email?.split('@').first ?? 'user${user.id.substring(0, 5)}',
        'email': user.email,
        'profile_picture': userMetadata?['avatar_url'] ?? userMetadata?['picture'],
        'provider': 'Google',
        'last_login': DateTime.now().toIso8601String(),
      };

      // ******************** THE FIX IS HERE ********************
      // If the profile doesn't exist yet, it's a new user, so set the default role.
      if (profileResponse == null) {
        profileData['role'] = 'User'; // Set default role for new users
      }
      // **********************************************************

      // Use upsert to create or update the profile
      await _supabase.from('profiles').upsert(profileData, onConflict: 'id');

      print("Successfully signed in with Google and updated Supabase profile for user: ${user.id}");
      return user;

    } on AuthException catch (e) {
      print("AuthService - signInWithGoogle AuthException: ${e.message}");
      rethrow;
    } catch (e) {
      print("AuthService - signInWithGoogle Unexpected Error: $e");
      throw Exception("An unexpected error occurred during Google sign in.");
    }
  }

  Future<User> signUpWithEmail(String email, String password, String name, String username) async {
    try {
      final usernameCheck = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (usernameCheck != null) {
        throw AuthException("Username '$username' is already taken. Please choose another.");
      }

      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const AuthException('Sign up failed: No user created.');
      }
      
      // ******************** THE FIX IS HERE ********************
      // Also add the default role for email sign-ups
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'name': name,
        'username': username,
        'email': email,
        'provider': 'Email',
        'role': 'User' // Set default role
      });
      // **********************************************************

      return response.user!;
    } on AuthException catch (e) {
      print("AuthService - signUpWithEmail Error: ${e.message}");
      rethrow;
    } catch (e) {
      print("AuthService - signUpWithEmail Unexpected Error: $e");
      throw Exception("An unexpected error occurred during sign up.");
    }
  }

  // ... (rest of the methods remain the same) ...
  
  Future<void> sendPasswordRecoveryOtp(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      print("Password recovery token (OTP) request sent to $email.");
    } on AuthException catch (e) {
      print("AuthService - sendPasswordRecoveryOtp AuthException: ${e.message}");
      if (e.message.toLowerCase().contains("user not found")) {
        throw AuthException("No account found for this email address.");
      }
      rethrow;
    } catch (e) {
      print("AuthService - sendPasswordRecoveryOtp Error: $e");
      throw Exception("Failed to send password recovery OTP: ${e.toString()}");
    }
  }

  Future<void> verifyRecoveryOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      print("Attempting to verify recovery OTP for $email");
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: email,
        token: otp,
      );

      if (response.session == null || response.user == null) {
        throw const AuthException("Invalid or expired OTP. Please request a new one.");
      }
      print("Recovery OTP verified successfully for user: ${response.user!.id}.");

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      print("Password updated successfully for user: ${response.user!.id}");

      await _supabase.auth.signOut();
      print("User signed out after password reset for security.");

    } on AuthException catch (e) {
      print("AuthService - verifyRecoveryOtpAndResetPassword AuthException: ${e.message}");
      if (e.message.toLowerCase().contains("token not found") ||
          e.message.toLowerCase().contains("invalid token") ||
          e.message.toLowerCase().contains("expired")) {
        throw AuthException("The OTP is invalid or has expired. Please request a new one.");
      }
      rethrow;
    } catch (e) {
      print("AuthService - verifyRecoveryOtpAndResetPassword Error: $e");
      throw Exception("An unexpected error occurred while resetting password: ${e.toString()}");
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await _supabase.auth.signOut();
    } catch (e) {
      print("AuthService - signOut Error: $e");
      throw AuthException("Failed to sign out: ${e.toString()}");
    }
  }

  Future<String> getUserRole(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      return profile['role'] ?? "User";
    } catch (e) {
      print("Error fetching user role for $userId: $e");
      return 'User'; // Default role on error
    }
  }
}
