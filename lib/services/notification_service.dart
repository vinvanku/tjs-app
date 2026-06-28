import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level function to handle background messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message - show local notification
  await NotificationService.instance.showLocalNotification(
    title: message.notification?.title ?? 'New Job Alert',
    body: message.notification?.body ?? 'A new job has been posted.',
    payload: jsonEncode(message.data),
  );
}

/// Service class that manages Firebase Cloud Messaging (FCM) and
/// local notifications for the Telangana Jobs app.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging? _messaging = _getMessagingInstance();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static FirebaseMessaging? _getMessagingInstance() {
    try {
      return FirebaseMessaging.instance;
    } catch (e) {
      return null;
    }
  }

  /// Callback triggered when the FCM token is refreshed.
  /// Set this from outside to handle token updates (e.g., save to Supabase).
  void Function(String token)? onTokenRefresh;

  /// Callback triggered when user taps a notification.
  void Function(String? payload)? onNotificationTapped;

  bool _isInitialized = false;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Initializes the notification service:
  /// 1. Requests notification permissions
  /// 2. Configures local notification channels
  /// 3. Gets the FCM token
  /// 4. Sets up foreground/background message handlers
  /// 5. Registers token refresh listener
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_messaging == null) {
      debugPrint('NotificationService: Firebase not available, skipping FCM setup');
      _isInitialized = true;
      return;
    }

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set up Firebase Messaging handlers
    await _setupFirebaseMessaging();

    // Get initial FCM token
    await _getAndStoreToken();

    // Listen for token refresh
    _messaging!.onTokenRefresh.listen((newToken) {
      onTokenRefresh?.call(newToken);
    });

    _isInitialized = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERMISSIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Requests notification permissions from the user.
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return settings;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCAL NOTIFICATIONS SETUP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'telangana_jobs_channel',
        'Telangana Jobs Notifications',
        description: 'Notifications for new job postings and updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Handles notification tap response.
  void _onNotificationResponse(NotificationResponse response) {
    onNotificationTapped?.call(response.payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIREBASE MESSAGING SETUP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _setupFirebaseMessaging() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from a notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle the case where the app was terminated and opened via notification
    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Set background message handler (top-level function)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set foreground notification presentation options (iOS)
    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Handles messages received while the app is in the foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await showLocalNotification(
        title: notification.title ?? 'New Job Alert',
        body: notification.body ?? 'A new job has been posted.',
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handles when user taps a notification that opened the app.
  void _handleMessageOpenedApp(RemoteMessage message) {
    onNotificationTapped?.call(jsonEncode(message.data));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM TOKEN
  // ─────────────────────────────────────────────────────────────────────────

  /// Retrieves the current FCM token.
  Future<String?> getToken() async {
    try {
      return await _messaging?.getToken();
    } catch (e) {
      return null;
    }
  }

  /// Gets the FCM token and triggers the onTokenRefresh callback.
  Future<void> _getAndStoreToken() async {
    final token = await getToken();
    if (token != null) {
      onTokenRefresh?.call(token);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHOW LOCAL NOTIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Displays a local notification with the given [title] and [body].
  ///
  /// Optionally includes a [payload] that will be passed to the
  /// notification tap handler.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'telangana_jobs_channel',
      'Telangana Jobs Notifications',
      channelDescription: 'Notifications for new job postings and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC SUBSCRIPTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Subscribes to a notification topic (e.g., job category).
  Future<void> subscribeToTopic(String topic) async {
    await _messaging?.subscribeToTopic(topic);
  }

  /// Unsubscribes from a notification topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging?.unsubscribeFromTopic(topic);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  /// Deletes the FCM token (useful on logout).
  Future<void> deleteToken() async {
    await _messaging?.deleteToken();
  }
}
