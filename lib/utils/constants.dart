import 'package:flutter/material.dart';

/// Central constants for the Telangana Jobs App.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ─────────────────────────────────────────────────────────────────────────
  // SUPABASE CONFIGURATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Supabase project URL.
  static const String supabaseUrl = 'https://bkjkcdsvezviuytdwlzg.supabase.co';

  /// Supabase anonymous key.
  static const String supabaseAnonKey = '[REDACTED_JWT]';

  // ─────────────────────────────────────────────────────────────────────────
  // COLOR SCHEME
  // ─────────────────────────────────────────────────────────────────────────

  /// Primary brand color (Magenta/Pink — inspired by Telangana state logo).
  static const Color primaryColor = Color(0xFFD81B60);

  /// Secondary color (Deep Purple).
  static const Color secondaryColor = Color(0xFF7B1FA2);

  /// Accent color (Amber/Gold).
  static const Color accentColor = Color(0xFFF9A825);

  /// Success green for "safe" urgency.
  static const Color successColor = Color(0xFF2E7D32);

  /// Warning orange for moderate urgency.
  static const Color warningColor = Color(0xFFEF6C00);

  /// Error red for critical urgency.
  static const Color errorColor = Color(0xFFC62828);

  /// Background grey.
  static const Color backgroundColor = Color(0xFFF8F9FA);

  /// Card surface color.
  static const Color surfaceColor = Color(0xFFFFFFFF);

  /// Text primary.
  static const Color textPrimary = Color(0xFF212121);

  /// Text secondary.
  static const Color textSecondary = Color(0xFF757575);

  // ─────────────────────────────────────────────────────────────────────────
  // JOB CATEGORIES
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> categories = [
    'All',
    'Group-I',
    'Group-II',
    'Group-III',
    'Group-IV',
    'Police',
    'Teaching',
    'Engineering',
    'Medical & Health',
    'Banking',
    'Railway',
    'SSC',
    'Defence',
    'Agriculture',
    'Forest',
    'Judiciary',
    'Revenue',
    'Municipal',
    'Panchayat Raj',
    'Welfare',
    'Contract / Outsourcing',
    'Central Govt',
    'PSU',
    'Other',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // QUALIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> qualifications = [
    '10th Pass (SSC)',
    'Intermediate (12th)',
    'ITI',
    'Diploma',
    'Graduation (Any Degree)',
    'B.Tech / B.E.',
    'B.Sc',
    'B.Com',
    'B.A.',
    'BBA / BBM',
    'BCA',
    'B.Ed',
    'B.Pharmacy',
    'MBBS',
    'BDS',
    'BAMS / BHMS',
    'B.Sc Nursing',
    'LLB / Law',
    'Post Graduation (PG)',
    'M.Tech / M.E.',
    'M.Sc',
    'M.Com',
    'M.A.',
    'MBA',
    'MCA',
    'M.Ed',
    'M.Pharmacy',
    'MD / MS',
    'Ph.D',
    'CA / ICWA',
    'Other',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // TELANGANA DISTRICTS (All 33 districts)
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> districts = [
    'Adilabad',
    'Bhadradri Kothagudem',
    'Hanumakonda',
    'Hyderabad',
    'Jagtial',
    'Jangaon',
    'Jayashankar Bhupalpally',
    'Jogulamba Gadwal',
    'Kamareddy',
    'Karimnagar',
    'Khammam',
    'Kumuram Bheem Asifabad',
    'Mahabubabad',
    'Mahbubnagar',
    'Mancherial',
    'Medak',
    'Medchal-Malkajgiri',
    'Mulugu',
    'Nagarkurnool',
    'Nalgonda',
    'Narayanpet',
    'Nirmal',
    'Nizamabad',
    'Peddapalli',
    'Rajanna Sircilla',
    'Rangareddy',
    'Sangareddy',
    'Siddipet',
    'Suryapet',
    'Vikarabad',
    'Wanaparthy',
    'Warangal',
    'Yadadri Bhuvanagiri',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // APP METADATA
  // ─────────────────────────────────────────────────────────────────────────

  static const String appName = 'TS Jobs';
  static const String appNameTelugu = 'తెలంగాణ ఉద్యోగాలు';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your gateway to Telangana government jobs';
  static const String appTaglineTelugu = 'తెలంగాణ ప్రభుత్వ ఉద్యోగాల గేట్‌వే';

  // ─────────────────────────────────────────────────────────────────────────
  // JOB SOURCES
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> jobSources = [
    'TSPSC',
    'TSLPRB',
    'TSTET',
    'DSC',
    'TSSPDCL',
    'TSNPDCL',
    'TSGENCO',
    'TSRTC',
    'HMWSSB',
    'GHMC',
    'TSSWREIS',
    'TSTWREIS',
    'Recruitment.guru',
    'Manabadi',
    'Official Gazette',
    'Other',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // API & PAGINATION
  // ─────────────────────────────────────────────────────────────────────────

  static const int pageSize = 20;
  static const int maxCacheAge = 30; // minutes
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration cacheExpiry = Duration(minutes: 30);

  // ─────────────────────────────────────────────────────────────────────────
  // STORAGE KEYS
  // ─────────────────────────────────────────────────────────────────────────

  static const String keyLanguage = 'app_language';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyLastSync = 'last_sync_time';
  static const String keyFcmToken = 'fcm_token';
  static const String keyThemeMode = 'theme_mode';

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATION TOPICS
  // ─────────────────────────────────────────────────────────────────────────

  static const String topicAllJobs = 'all_jobs';
  static const String topicUrgent = 'urgent_deadlines';
  static String topicCategory(String category) =>
      'category_${category.toLowerCase().replaceAll(' ', '_')}';
  static String topicDistrict(String district) =>
      'district_${district.toLowerCase().replaceAll(' ', '_')}';
}
