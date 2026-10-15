import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';

import 'screens/splash.dart';
import 'screens/role_selection.dart';
import 'screens/auth.dart';
import 'screens/admin_login.dart';
import 'screens/home.dart';
import 'screens/search.dart';
import 'screens/report.dart';
import 'screens/matches.dart';
import 'screens/claim.dart';
import 'screens/profile.dart';
import 'screens/notifications.dart';
import 'screens/admin.dart';
import 'screens/item_details.dart';
import 'screens/chat.dart';
import 'screens/messages.dart';
import 'screens/my_reports.dart';
import 'screens/campus_map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('CAMPUSFIND: Starting Firebase');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('CAMPUSFIND: Firebase initialized');
  } catch (error, stackTrace) {
    debugPrint('CAMPUSFIND: Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }

  debugPrint('CAMPUSFIND: Starting API initialization');

  try {
    await ApiService.init();
    debugPrint('CAMPUSFIND: API initialized');
  } catch (error, stackTrace) {
    debugPrint('CAMPUSFIND: API initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }

  debugPrint('CAMPUSFIND: Launching app');

  runApp(const CampusFindApp());
}

class CampusFindApp extends StatefulWidget {
  const CampusFindApp({super.key});

  @override
  State<CampusFindApp> createState() => _CampusFindAppState();
}

class _CampusFindAppState extends State<CampusFindApp> {
  late final GoRouter _router;

  Future<String?> _getUserRole() async {
    try {
      final hasToken = await ApiService.hasToken();

      if (!hasToken) {
        return null;
      }

      final me = await ApiService.me();
      return me['role']?.toString().toLowerCase();
    } catch (error) {
      debugPrint('CAMPUSFIND: Could not retrieve user role: $error');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();

    _router = GoRouter(
      initialLocation: '/role',
      redirect: (context, state) async {
        final location = state.matchedLocation;

        // Public routes
        if (location == '/splash' ||
            location == '/role' ||
            location == '/login' ||
            location == '/register' ||
            location == '/admin-login') {
          return null;
        }

        // Authentication check
        final role = await _getUserRole();

        if (role == null) {
          return '/role';
        }

        // Admin access
        if (role == 'admin') {
          if (location == '/admin') {
            return null;
          }

          return '/admin';
        }

        // Normal user access
        if (location == '/admin') {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/role',
          builder: (_, __) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/admin-login',
          builder: (_, __) => const AdminLoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const SearchScreen(),
        ),
        GoRoute(
          path: '/item-details',
          builder: (_, state) => ItemDetailsScreen(
            item: Map<String, dynamic>.from(
              state.extra as Map,
            ),
            found: state.uri.queryParameters['found'] == 'true',
          ),
        ),
        GoRoute(
          path: '/report',
          builder: (_, state) => ReportScreen(
            type: state.uri.queryParameters['type'],
          ),
        ),
        GoRoute(
          path: '/matches',
          builder: (_, __) => const MatchesScreen(),
        ),
        GoRoute(
          path: '/claim',
          builder: (_, state) => ClaimScreen(
            data: Map<String, dynamic>.from(
              state.extra as Map,
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/my-reports',
          builder: (_, __) => const MyReportsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const AdminScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (_, state) => ChatScreen(
            data: Map<String, dynamic>.from(
              state.extra as Map,
            ),
          ),
        ),
        GoRoute(
          path: '/messages',
          builder: (_, __) => const MessagesScreen(),
        ),
        GoRoute(
          path: '/campus-map',
          builder: (_, state) {
            Map<String, dynamic>? selectedItem;

            if (state.extra is Map) {
              selectedItem = Map<String, dynamic>.from(
                state.extra as Map,
              );
            }

            return CampusMapScreen(
              selectedItem: selectedItem,
            );
          },
        ),
      ],
      errorBuilder: (context, state) {
        debugPrint(
          'CAMPUSFIND: Router error: ${state.error}',
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF2F7F8),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 52,
                      color: Color(0xFF176B73),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to open this screen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF193C46),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.error?.toString() ??
                          'An unexpected navigation error occurred.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF526A73),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        _router.go('/role');
                      },
                      child: const Text('Back to start'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CampusFind',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }
}
