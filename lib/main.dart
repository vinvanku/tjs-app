import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'utils/constants.dart';

/// Top-level background message handler for Firebase Messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

/// Local notifications plugin instance (global for access from handlers).
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android notification channel for high-priority job alerts.
const AndroidNotificationChannel jobAlertsChannel = AndroidNotificationChannel(
  'job_alerts_channel',
  'Job Alerts',
  description: 'Notifications for new government job postings in Telangana',
  importance: Importance.high,
  playSound: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase (don't block if it fails)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Set up background message handler
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('FCM background handler setup failed: $e');
  }

  // Initialize Supabase (don't block if it fails)
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  // Initialize local notifications (don't block if it fails)
  try {
    await _initializeLocalNotifications();
  } catch (e) {
    debugPrint('Local notifications init failed: $e');
  }

  // Create the notification channel on Android
  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(jobAlertsChannel);
  } catch (e) {
    debugPrint('Notification channel creation failed: $e');
  }

  // Request notification permissions (iOS & Android 13+)
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  } catch (e) {
    debugPrint('Permission request failed: $e');
  }

  // Listen for foreground messages
  try {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  } catch (e) {
    debugPrint('Foreground message listener failed: $e');
  }

  // CRITICAL: Disable runtime font fetching — use system fonts as fallback
  // Without this, GoogleFonts tries to download Poppins at runtime and fails in release mode
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const TSJobsApp());
}

/// Initialize Flutter Local Notifications plugin.
Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap — navigate to the relevant job
      debugPrint('Notification tapped: ${response.payload}');
    },
  );
}

/// Show a local notification when a push message arrives in the foreground.
void _handleForegroundMessage(RemoteMessage message) {
  final RemoteNotification? notification = message.notification;
  final AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          jobAlertsChannel.id,
          jobAlertsChannel.name,
          channelDescription: jobAlertsChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['job_id'],
    );
  }
}
