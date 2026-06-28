import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

/// Enum representing the various authentication states.
enum AuthState {
  /// Initial state before any auth check has been performed.
  initial,

  /// Authentication operation is in progress.
  loading,

  /// OTP has been sent, waiting for verification.
  otpSent,

  /// User is authenticated and session is active.
  authenticated,

  /// User is not authenticated.
  unauthenticated,

  /// An error occurred during authentication.
  error,
}

/// Provider class that manages authentication state and user profile.
///
/// Uses [ChangeNotifier] for state management with Flutter's Provider package.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  AuthState _state = AuthState.initial;
  Profile? _profile;
  String? _errorMessage;
  String? _phoneNumber;
  User? _user;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Current authentication state.
  AuthState get state => _state;

  /// Current user profile (null if not loaded or not authenticated).
  Profile? get profile => _profile;

  /// Error message from the last failed operation.
  String? get errorMessage => _errorMessage;

  /// The phone number used for OTP authentication.
  String get phoneNumber => _phoneNumber ?? '';

  /// The currently authenticated Supabase user.
  User? get user => _user;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _state == AuthState.authenticated;

  /// Whether an auth operation is in progress.
  bool get isLoading => _state == AuthState.loading;

  /// The user's ID, or null if not authenticated.
  String? get userId => _user?.id;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks the current authentication state on app startup.
  ///
  /// If a session exists, loads the user profile and sets state to authenticated.
  Future<void> initialize() async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      if (_authService.isLoggedIn) {
        _user = _authService.currentUser;
        await _loadProfile();
        await _setupNotifications();
        _state = AuthState.authenticated;
      } else {
        // Try to refresh session
        final session = await _authService.refreshSession();
        if (session != null) {
          _user = _authService.currentUser;
          await _loadProfile();
          await _setupNotifications();
          _state = AuthState.authenticated;
        } else {
          _state = AuthState.unauthenticated;
        }
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OTP AUTHENTICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends an OTP to the given [phone] number.
  ///
  /// On success, sets state to [AuthState.otpSent].
  /// On failure, sets state to [AuthState.error] with error message.
  Future<void> sendOtp(String phone) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      await _authService.sendOtp(phone);
      _phoneNumber = phone;
      _state = AuthState.otpSent;
    } on AuthServiceException catch (e) {
      _state = AuthState.error;
      _errorMessage = e.message;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'An unexpected error occurred. Please try again.';
    }

    notifyListeners();
  }

  /// Verifies the OTP [code] for the previously submitted phone number.
  ///
  /// On success, sets state to [AuthState.authenticated] and loads profile.
  /// On failure, sets state to [AuthState.error] with error message.
  Future<void> verifyOtp(String code) async {
    if (_phoneNumber == null) {
      _state = AuthState.error;
      _errorMessage = 'Phone number not set. Please request OTP again.';
      notifyListeners();
      return;
    }

    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.verifyOtp(_phoneNumber!, code);
      _user = response.user;

      // Load or create profile
      await _loadProfile();

      // Setup push notifications
      await _setupNotifications();

      _state = AuthState.authenticated;
    } on AuthServiceException catch (e) {
      _state = AuthState.error;
      _errorMessage = e.message;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Verification failed. Please try again.';
    }

    notifyListeners();
  }

  /// Resends the OTP to the current phone number.
  Future<void> resendOtp() async {
    if (_phoneNumber == null) return;
    await sendOtp(_phoneNumber!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────────────────────

  /// Signs out the user and resets all state.
  Future<void> logout() async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      // Delete FCM token before signing out
      await _notificationService.deleteToken();

      await _authService.signOut();

      _user = null;
      _profile = null;
      _phoneNumber = null;
      _errorMessage = null;
      _state = AuthState.unauthenticated;
    } catch (e) {
      // Even if sign out fails on server, clear local state
      _user = null;
      _profile = null;
      _state = AuthState.unauthenticated;
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  /// Updates the user's profile with the given [profile] data or named fields.
  Future<void> updateProfile({
    Profile? profile,
    String? name,
    String? district,
    String? qualification,
  }) async {
    try {
      final Profile p;
      if (profile != null) {
        p = profile;
      } else if (_profile != null) {
        p = _profile!.copyWith(name: name, district: district, qualification: qualification);
      } else {
        return;
      }
      await _supabaseService.updateProfile(p);
      _profile = p;
      notifyListeners();
    } on SupabaseServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Refreshes the profile from the database.
  Future<void> refreshProfile() async {
    await _loadProfile();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Loads the user profile from Supabase.
  Future<void> _loadProfile() async {
    if (_user == null) return;

    try {
      _profile = await _supabaseService.getUserProfile(_user!.id);
    } catch (_) {
      // Profile might not exist yet (first login)
      _profile = null;
    }
  }

  /// Sets up push notifications and stores FCM token.
  Future<void> _setupNotifications() async {
    if (_user == null) return;

    try {
      _notificationService.onTokenRefresh = (token) async {
        await _supabaseService.updateFcmToken(_user!.id, token);
      };

      await _notificationService.initialize();

      // Store current token
      final token = await _notificationService.getToken();
      if (token != null) {
        await _supabaseService.updateFcmToken(_user!.id, token);
      }
    } catch (_) {
      // Non-critical: don't fail auth if notifications setup fails
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADDITIONAL MEMBERS (stub implementations for screens)
  // ─────────────────────────────────────────────────────────────────────────

  /// User's display name.
  String get userName => _profile?.name ?? 'User';

  /// User's district preference.
  String get userDistrict => _profile?.district ?? 'All Telangana';

  /// User's qualification preference.
  String get userQualification => _profile?.qualification ?? 'Degree';

  /// Notification preference: new jobs.
  bool notifNewJobs = true;

  /// Notification preference: last date reminders.
  bool notifLastDate = true;

  /// Notification preference: results.
  bool notifResults = true;

  /// Whether language is Telugu.
  bool get isTeluguLanguage => _profile?.language == 'te';

  /// Whether the profile is complete.
  bool get isProfileComplete => _profile?.isComplete ?? false;

  /// User's phone number (non-nullable for UI).
  String get phoneNumberDisplay => _phoneNumber ?? '';

  /// Sends OTP with named parameter (used by login_screen).
  Future<String?> sendOTP({required String phoneNumber}) async {
    await sendOtp(phoneNumber);
    return 'verification_id';
  }

  /// Verifies OTP with named parameters (used by login_screen).
  Future<bool> verifyOTP({required String verificationId, required String otp}) async {
    await verifyOtp(otp);
    return _state == AuthState.authenticated;
  }

  /// Marks onboarding as seen.
  Future<void> setOnboardingSeen() async {
    // Stub — could store in shared preferences
  }

  /// Saves initial profile during setup.
  Future<void> saveProfile({
    required String name,
    required String district,
    required String qualification,
    required List<String> categories,
  }) async {
    if (_user == null) return;
    final profile = Profile(
      id: _user!.id,
      phone: _phoneNumber ?? '',
      name: name,
      district: district,
      qualification: qualification,
      preferredCategories: categories,
    );
    await _supabaseService.updateProfile(profile);
    _profile = profile;
    notifyListeners();
  }

  /// Updates profile with named parameters (used by profile_screen).
  Future<void> updateProfileFields({
    String? name,
    String? district,
    String? qualification,
  }) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(
      name: name,
      district: district,
      qualification: qualification,
    );
    await updateProfile(profile: updated);
  }

  /// Updates a notification preference.
  Future<void> updateNotificationPreference(String key, bool value) async {
    switch (key) {
      case 'new_jobs':
        notifNewJobs = value;
        break;
      case 'last_date':
        notifLastDate = value;
        break;
      case 'results':
        notifResults = value;
        break;
    }
    notifyListeners();
  }

  /// Sets the app language.
  Future<void> setLanguage(String lang) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(language: lang);
      await _supabaseService.updateProfile(_profile!);
      notifyListeners();
    }
  }

  /// Clears the current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Resets state to unauthenticated (e.g., to go back to phone entry).
  void resetToInitial() {
    _state = AuthState.unauthenticated;
    _phoneNumber = null;
    _errorMessage = null;
    notifyListeners();
  }
}
