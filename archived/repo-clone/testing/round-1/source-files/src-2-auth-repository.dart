import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';

// Custom auth exceptions for better error handling
class AuthInvalidCredentialsError implements Exception {
  final String message;
  AuthInvalidCredentialsError([this.message = 'Invalid email or password']);

  @override
  String toString() => message;
}

class AuthUserNotFoundError implements Exception {
  final String email;
  final String message;
  AuthUserNotFoundError(this.email, [String? customMessage])
    : message = customMessage ?? 'No account found with email: $email';

  @override
  String toString() => message;
}

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository() : _client = SupabaseConfig.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      if (response.session != null) {
        await SupabaseConfig.persistSession(response.session!);
      }

      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during sign up');
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        await SupabaseConfig.persistSession(response.session!);
      }

      return response;
    } on AuthException catch (e) {
      // For sign in, we want to provide more specific error messages
      // Note: Supabase returns "Invalid login credentials" for both wrong password
      // and non-existent user for security reasons
      if (e.message.toLowerCase().contains('invalid login credentials') ||
          e.message.toLowerCase().contains('invalid password') ||
          e.message.toLowerCase().contains('user not found')) {
        // We'll throw a special exception that the UI can handle
        // to provide helpful options without revealing if user exists
        throw AuthInvalidCredentialsError('Invalid email or password');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (e is AuthInvalidCredentialsError) {
        rethrow;
      }
      throw Exception('An unexpected error occurred during sign in');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      await SupabaseConfig.clearSession();
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during sign out');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'pm-master://reset-password',
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during password reset');
    }
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during password update');
    }
  }

  Future<Session?> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      if (response.session != null) {
        await SupabaseConfig.persistSession(response.session!);
      }
      return response.session;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      return null;
    }
  }

  Future<UserResponse> updateProfile({
    String? email,
    String? phone,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          email: email,
          phone: phone,
          data: data,
        ),
      );
      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during profile update');
    }
  }

  Future<void> verifyOTP({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during OTP verification');
    }
  }

  Future<Session?> recoverSession() async {
    try {
      // First check if we have a current valid session
      final currentSession = _client.auth.currentSession;
      if (currentSession != null) {
        // Check if session is not expired
        final expiresAt = currentSession.expiresAt;
        if (expiresAt != null) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (now < expiresAt) {
            // Session is still valid
            return currentSession;
          }
        }
      }

      // If no valid session, let Supabase handle the refresh internally
      // The SDK should automatically refresh if it has a valid refresh token
      try {
        final response = await _client.auth.refreshSession();
        if (response.session != null) {
          await SupabaseConfig.persistSession(response.session!);
          return response.session;
        }
      } catch (e) {
        // If refresh fails (e.g., token already used), clear session
        await SupabaseConfig.clearSession();
        return null;
      }

      return null;
    } catch (e) {
      // Clear session on any error to avoid stale tokens
      await SupabaseConfig.clearSession();
      return null;
    }
  }

  Exception _handleAuthException(AuthException e) {
    switch (e.statusCode) {
      case '400':
        if (e.message.contains('email')) {
          return Exception('Invalid email address');
        } else if (e.message.contains('password')) {
          return Exception('Password must be at least 6 characters');
        }
        return Exception('Invalid credentials');
      case '422':
        return Exception('Email already registered');
      case '429':
        return Exception('Too many attempts. Please try again later');
      default:
        return Exception(e.message);
    }
  }
}