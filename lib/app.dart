import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/jobs_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/saved_jobs_screen.dart';
import 'screens/search_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ROUTER CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────

final GoRouter _router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = context.read<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final isLoading = authProvider.isLoading;

    // Don't redirect while auth state is still being determined
    // This covers BOTH the 'initial' and 'loading' states
    final isSplashRoute = state.matchedLocation == '/';
    if (isSplashRoute) return null; // Always allow splash screen

    final isLoginRoute = state.matchedLocation == '/login';
    final isOnboardingRoute = state.matchedLocation == '/onboarding';

    // If still loading, don't redirect
    if (isLoading) return null;

    // If not authenticated and not on login/onboarding/home, redirect to login
    final isHomeRoute = state.matchedLocation == '/home';
    if (!isAuthenticated && !isLoginRoute && !isOnboardingRoute && !isHomeRoute) {
      return '/login';
    }

    // If authenticated and on login page, go to home
    if (isAuthenticated && isLoginRoute) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      name: 'profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/job/:id',
      name: 'job-detail',
      builder: (context, state) {
        final jobId = state.pathParameters['id']!;
        return JobDetailScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: '/saved',
      name: 'saved',
      builder: (context, state) => const SavedJobsScreen(),
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/calendar',
      name: 'calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
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
      child: MaterialApp.router(
        title: 'TS Jobs',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE91E63),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE91E63),
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData.dark().textTheme,
          ),
        ),
        themeMode: ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }
}
