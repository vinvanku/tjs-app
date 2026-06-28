/// Centralized UI string translations for English and Telugu.
/// Usage: AppStrings.get('key', languageCode)
class AppStrings {
  AppStrings._();

  /// Get a translated string by key and language code ('en' or 'te').
  static String get(String key, String languageCode) {
    final lang = languageCode == 'te' ? 'te' : 'en';
    return _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    // App
    'app_title': {
      'en': 'Telangana Jobs',
      'te': 'తెలంగాణ జాబ్స్',
    },
    'ts_jobs': {
      'en': 'TS Jobs',
      'te': 'TS జాబ్స్',
    },

    // Login Screen
    'login': {
      'en': 'Login',
      'te': 'లాగిన్',
    },
    'login_title': {
      'en': 'Login to TS Jobs',
      'te': 'TS జాబ్స్ లాగిన్',
    },
    'enter_mobile': {
      'en': 'Enter your mobile number to continue',
      'te': 'కొనసాగించడానికి మొబైల్ నంబర్ ఎంటర్ చేయండి',
    },
    'mobile_number': {
      'en': 'Mobile Number',
      'te': 'మొబైల్ నంబర్',
    },
    'send_otp': {
      'en': 'Send OTP',
      'te': 'OTP పంపండి',
    },
    'browse_as_guest': {
      'en': 'Browse as Guest',
      'te': 'గెస్ట్\u200cగా బ్రౌజ్ చేయండి',
    },
    'view_jobs_without_signin': {
      'en': 'View jobs without signing in',
      'te': 'సైన్ ఇన్ లేకుండా ఉద్యోగాలు చూడండి',
    },
    'enter_otp': {
      'en': 'Enter OTP',
      'te': 'OTP ఎంటర్ చేయండి',
    },
    'verify_continue': {
      'en': 'Verify & Continue',
      'te': 'వెరిఫై & కొనసాగించు',
    },
    'resend': {
      'en': 'Resend',
      'te': 'మళ్ళీ పంపండి',
    },
    'didnt_receive_otp': {
      'en': "Didn't receive OTP? ",
      'te': 'OTP రాలేదా? ',
    },
    'change_phone': {
      'en': 'Change Phone Number',
      'te': 'ఫోన్ నంబర్ మార్చండి',
    },
    'terms_text': {
      'en': 'By continuing, you agree to our\nTerms of Service & Privacy Policy',
      'te': 'కొనసాగించడం ద్వారా, మీరు మా\nసేవా నిబంధనలు & గోప్యతా విధానానికి అంగీకరిస్తారు',
    },

    // Categories
    'cat_all': {
      'en': 'All',
      'te': 'అన్ని',
    },
    'cat_police': {
      'en': 'Police',
      'te': 'పోలీసు',
    },
    'cat_teaching': {
      'en': 'Teaching',
      'te': 'టీచింగ్',
    },
    'cat_health': {
      'en': 'Health',
      'te': 'ఆరోగ్యం',
    },
    'cat_engineering': {
      'en': 'Engineering',
      'te': 'ఇంజినీరింగ్',
    },
    'cat_railway': {
      'en': 'Railway',
      'te': 'రైల్వే',
    },
    'cat_banking': {
      'en': 'Banking',
      'te': 'బ్యాంకింగ్',
    },
    'cat_revenue': {
      'en': 'Revenue',
      'te': 'రెవెన్యూ',
    },
    'cat_general_govt': {
      'en': 'General Govt',
      'te': 'జనరల్ గవర్నమెంట్',
    },
    'cat_general': {
      'en': 'General',
      'te': 'జనరల్',
    },
    'cat_defense': {
      'en': 'Defense',
      'te': 'రక్షణ',
    },
    'cat_research': {
      'en': 'Research',
      'te': 'పరిశోధన',
    },
    'cat_agriculture': {
      'en': 'Agriculture',
      'te': 'వ్యవసాయం',
    },
    'cat_forest': {
      'en': 'Forest',
      'te': 'అటవీ',
    },
    'cat_judicial': {
      'en': 'Judicial',
      'te': 'న్యాయ',
    },
    'cat_postal': {
      'en': 'Postal',
      'te': 'పోస్టల్',
    },
    'cat_insurance': {
      'en': 'Insurance',
      'te': 'బీమా',
    },
    'cat_staff_selection': {
      'en': 'Staff Selection',
      'te': 'స్టాఫ్ సెలెక్షన్',
    },
    'cat_education': {
      'en': 'Education',
      'te': 'విద్య',
    },

    // Home Screen
    'latest_jobs': {
      'en': 'Latest Jobs',
      'te': 'తాజా ఉద్యోగాలు',
    },
    'featured_jobs': {
      'en': '🔥 Featured Jobs',
      'te': '🔥 ఫీచర్డ్ జాబ్స్',
    },
    'jobs_count': {
      'en': 'jobs',
      'te': 'ఉద్యోగాలు',
    },

    // Job Detail
    'apply_now': {
      'en': 'Apply Now →',
      'te': 'దరఖాస్తు చేయండి →',
    },
    'view_notification': {
      'en': 'View Notification',
      'te': 'నోటిఫికేషన్ చూడండి',
    },
    'last_date': {
      'en': 'Last Date',
      'te': 'చివరి తేదీ',
    },
    'vacancies': {
      'en': 'Vacancies',
      'te': 'ఖాళీలు',
    },
    'qualification': {
      'en': 'Qualification',
      'te': 'అర్హత',
    },
    'important_dates': {
      'en': 'Important Dates',
      'te': 'ముఖ్యమైన తేదీలు',
    },
    'vacancy_details': {
      'en': 'Vacancy Details',
      'te': 'ఖాళీల వివరాలు',
    },
    'total_vacancies': {
      'en': 'Total Vacancies',
      'te': 'మొత్తం ఖాళీలు',
    },
    'eligibility': {
      'en': 'Eligibility',
      'te': 'అర్హత',
    },
    'age_limit': {
      'en': 'Age Limit',
      'te': 'వయస్సు పరిమితి',
    },
    'location': {
      'en': 'Location',
      'te': 'ప్రదేశం',
    },
    'application_fee': {
      'en': 'Application Fee',
      'te': 'దరఖాస్తు ఫీజు',
    },
    'selection_process': {
      'en': 'Selection Process',
      'te': 'ఎంపిక ప్రక్రియ',
    },
    'description': {
      'en': 'Description',
      'te': 'వివరణ',
    },
    'application_start': {
      'en': 'Application Start',
      'te': 'దరఖాస్తు ప్రారంభం',
    },
    'last_date_apply': {
      'en': 'Last Date to Apply',
      'te': 'దరఖాస్తు చివరి తేదీ',
    },
    'exam_date': {
      'en': 'Exam Date',
      'te': 'పరీక్ష తేదీ',
    },
    'result_date': {
      'en': 'Result Date',
      'te': 'ఫలితం తేదీ',
    },
    'days_left': {
      'en': 'days left',
      'te': 'రోజులు మిగిలి ఉన్నాయి',
    },
    'closed': {
      'en': 'Closed',
      'te': 'ముగిసింది',
    },

    // Search
    'search_jobs': {
      'en': 'Search Jobs',
      'te': 'ఉద్యోగాలు వెతకండి',
    },
    'search_hint': {
      'en': 'Search jobs, posts, organizations...',
      'te': 'ఉద్యోగాలు, పోస్టులు, సంస్థలు వెతకండి...',
    },
    'no_jobs_found': {
      'en': 'No jobs found',
      'te': 'ఉద్యోగాలు కనుగొనబడలేదు',
    },
    'popular_searches': {
      'en': 'Popular Searches',
      'te': 'ప్రముఖ శోధనలు',
    },

    // Saved
    'saved': {
      'en': 'Saved',
      'te': 'సేవ్ చేసినవి',
    },

    // Bottom Navigation
    'nav_home': {
      'en': 'Home',
      'te': 'హోమ్',
    },
    'nav_search': {
      'en': 'Search',
      'te': 'వెతకండి',
    },
    'nav_saved': {
      'en': 'Saved',
      'te': 'సేవ్',
    },
    'nav_calendar': {
      'en': 'Calendar',
      'te': 'క్యాలెండర్',
    },
    'nav_profile': {
      'en': 'Profile',
      'te': 'ప్రొఫైల్',
    },

    // Profile Screen
    'profile': {
      'en': 'Profile',
      'te': 'ప్రొఫైల్',
    },
    'edit': {
      'en': 'Edit',
      'te': 'మార్చు',
    },
    'notification_preferences': {
      'en': 'Notification Preferences',
      'te': 'నోటిఫికేషన్ ప్రాధాన్యతలు',
    },
    'new_job_alerts': {
      'en': 'New Job Alerts',
      'te': 'కొత్త ఉద్యోగ హెచ్చరికలు',
    },
    'last_date_reminders': {
      'en': 'Last Date Reminders',
      'te': 'చివరి తేదీ రిమైండర్లు',
    },
    'result_alerts': {
      'en': 'Result Alerts',
      'te': 'ఫలితం హెచ్చరికలు',
    },
    'language': {
      'en': 'Language / భాష',
      'te': 'భాష / Language',
    },
    'logout': {
      'en': 'Logout',
      'te': 'లాగ్\u200cఅవుట్',
    },
    'share_app': {
      'en': 'Share App',
      'te': 'యాప్ షేర్ చేయండి',
    },
    'rate_app': {
      'en': 'Rate App',
      'te': 'యాప్ రేట్ చేయండి',
    },
    'about': {
      'en': 'About',
      'te': 'గురించి',
    },
  };
}
