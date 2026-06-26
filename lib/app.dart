import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils/constants.dart';

// Placeholder page imports — replace with actual screen files
// import 'screens/home_screen.dart';
// import 'screens/login_screen.dart';
// import 'screens/profile_setup_screen.dart';
// import 'screens/job_detail_screen.dart';
// import 'screens/saved_jobs_screen.dart';
// import 'screens/search_screen.dart';
// import 'screens/calendar_screen.dart';
// import 'screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  String _language = 'en'; // 'en' or 'te'

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String get language => _language;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      _isLoading = false;
      notifyListeners();
    });

    // Check current session
    _user = Supabase.instance.client.auth.currentUser;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signInWithOtp(String phone) async {
    await Supabase.instance.client.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOtp(String phone, String token) async {
    await Supabase.instance.client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _user = null;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOBS PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class JobsProvider extends ChangeNotifier {
  List<dynamic> _jobs = [];
  List<dynamic> _featuredJobs = [];
  List<dynamic> _savedJobs = [];
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = 'All';
  String _selectedDistrict = 'All';

  List<dynamic> get jobs => _jobs;
  List<dynamic> get featuredJobs => _featuredJobs;
  List<dynamic> get savedJobs => _savedJobs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;
  String get selectedDistrict => _selectedDistrict;

  final _supabase = Supabase.instance.client;

  Future<void> fetchJobs({String? category, String? district}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var query = _supabase.from('jobs').select().eq('is_active', true);

      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }
      if (district != null && district != 'All') {
        query = query.contains('districts', [district]);
      }

      final response = await query.order('posted_date', ascending: false);
      _jobs = response as List<dynamic>;

      _featuredJobs =
          _jobs.where((job) => job['is_featured'] == true).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSavedJobs(String userId) async {
    try {
      final response = await _supabase
          .from('saved_jobs')
          .select('*, jobs(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _savedJobs = response as List<dynamic>;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> saveJob(String userId, String jobId) async {
    try {
      await _supabase.from('saved_jobs').insert({
        'user_id': userId,
        'job_id': jobId,
        'status': 'saved',
      });
      await fetchSavedJobs(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> unsaveJob(String savedJobId, String userId) async {
    try {
      await _supabase.from('saved_jobs').delete().eq('id', savedJobId);
      await fetchSavedJobs(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void setCategory(String category) {
    _selectedCategory = category;
    fetchJobs(category: category, district: _selectedDistrict);
  }

  void setDistrict(String district) {
    _selectedDistrict = district;
    fetchJobs(category: _selectedCategory, district: district);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTER CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────

final GoRouter _router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = context.read<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final isLoading = authProvider.isLoading;

    if (isLoading) return null;

    final isLoginRoute = state.matchedLocation == '/login';

    if (!isAuthenticated && !isLoginRoute) {
      return '/login';
    }

    if (isAuthenticated && isLoginRoute) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const _PlaceholderScreen(title: 'Home'),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const _PlaceholderScreen(title: 'Login'),
    ),
    GoRoute(
      path: '/profile-setup',
      name: 'profile-setup',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Profile Setup'),
    ),
    GoRoute(
      path: '/job/:id',
      name: 'job-detail',
      builder: (context, state) {
        final jobId = state.pathParameters['id']!;
        return _PlaceholderScreen(title: 'Job Detail: $jobId');
      },
    ),
    GoRoute(
      path: '/saved',
      name: 'saved',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Saved Jobs'),
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const _PlaceholderScreen(title: 'Search'),
    ),
    GoRoute(
      path: '/calendar',
      name: 'calendar',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Calendar'),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const _PlaceholderScreen(title: 'Profile'),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// APP WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class TSJobsApp extends StatelessWidget {
  const TSJobsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JobsProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp.router(
            title: 'TS Jobs - తెలంగాణ ఉద్యోగాలు',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(context),
            darkTheme: _buildDarkTheme(context),
            themeMode: ThemeMode.light,
            routerConfig: _router,
            locale: Locale(authProvider.language),
            supportedLocales: const [
              Locale('en', ''), // English
              Locale('te', ''), // Telugu
            ],
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        primary: AppConstants.primaryColor,
        secondary: AppConstants.secondaryColor,
        tertiary: AppConstants.accentColor,
        surface: Colors.white,
        background: const Color(0xFFF8F9FA),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.primaryColor,
          side: const BorderSide(color: AppConstants.primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
        selectedColor: AppConstants.primaryColor,
        labelStyle: GoogleFonts.poppins(fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConstants.primaryColor,
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
    );
  }

  ThemeData _buildDarkTheme(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        primary: AppConstants.primaryColor,
        secondary: AppConstants.secondaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER SCREEN (replace with actual implementations)
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title Screen\n(To be implemented)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
