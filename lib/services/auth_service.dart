import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class that handles all authentication operations
/// using Supabase Auth with phone OTP verification.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the currently authenticated user, or `null` if not logged in.
  User? get currentUser => _client.auth.currentUser;

  /// Returns `true` if there is a currently authenticated session.
  bool get isLoggedIn => _client.auth.currentSession != null;

  /// Returns the current session, or `null` if not authenticated.
  Session? get currentSession => _client.auth.currentSession;

  /// Stream of authentication state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─────────────────────────────────────────────────────────────────────────
  // OTP AUTHENTICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends an OTP code to the given [phone] number.
  ///
  /// The phone number must include the country code (e.g., "+91XXXXXXXXXX").
  /// Supabase will send an SMS with the verification code.
  ///
  /// Throws [AuthServiceException] if the operation fails.
  Future<void> sendOtp(String phone) async {
    try {
      final formattedPhone = _formatPhoneNumber(phone);
      await _client.auth.signInWithOtp(
        phone: formattedPhone,
      );
    } on AuthException catch (e) {
      throw AuthServiceException(
        'Failed to send OTP: ${e.message}',
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw AuthServiceException('Failed to send OTP: $e');
    }
  }

  /// Verifies the OTP [token] sent to the given [phone] number.
  ///
  /// Returns an [AuthResponse] containing the session and user data
  /// on successful verification.
  ///
  /// Throws [AuthServiceException] if verification fails.
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    try {
      final formattedPhone = _formatPhoneNumber(phone);
      final response = await _client.auth.verifyOTP(
        phone: formattedPhone,
        token: token,
        type: OtpType.sms,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthServiceException(
        'Failed to verify OTP: ${e.message}',
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw AuthServiceException('Failed to verify OTP: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────────────────────────────────

  /// Signs out the current user and clears the session.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthServiceException(
        'Failed to sign out: ${e.message}',
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw AuthServiceException('Failed to sign out: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  /// Refreshes the current session if it exists.
  /// Useful for checking if the session is still valid on app launch.
  Future<Session?> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response.session;
    } on AuthException {
      // Session expired or invalid; return null
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Ensures the phone number is formatted with country code.
  /// Defaults to Indian country code (+91) if not present.
  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // Remove leading 0 if present
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Default to India country code
    return '+91$cleaned';
  }
}

/// Custom exception class for AuthService errors.
class AuthServiceException implements Exception {
  final String message;
  final String? statusCode;

  AuthServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthServiceException: $message (status: $statusCode)';
}
