import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/doctor_list_page.dart';
import 'pages/doctor_detail_page.dart';
import 'pages/booking_page.dart';
import 'pages/my_appointments_page.dart';
import 'pages/profile_page.dart';
import 'pages/doctor_availability_page.dart';
import 'pages/doctor_appointments_page.dart';
import 'pages/auth_guard.dart';

import 'pages/admin_appointments_page.dart';
import 'pages/admin_doctors_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'core/theme/app_theme.dart';

import 'pages/welcome_page.dart';

import 'pages/payment_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cxsjonvgbfemevgzbxcs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4c2pvbnZnYmZlbWV2Z3pieGNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1MDA3ODgsImV4cCI6MjEwODA3Njc4OH0.RyInlzpOdUq3HOXwSAn-nny1yE08gRmidfC0Z94z-Qc', // <-- your real key
  );

  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_YOUR_KEY';
    await Stripe.instance.applySettings();
  }

  runApp(const CareSlotApp());
}

/// Holds the current user's role so routing can react to it.
class RoleNotifier extends ChangeNotifier {
  String? _role;

  String? get role => _role;

  Future<void> load() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      _role = null;
      notifyListeners();
      return;
    }
    try {
      final row = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      _role = row['role'] as String?;
      debugPrint('RoleNotifier loaded role: $_role');   // <-- add this line
    } catch (e) {
      debugPrint('RoleNotifier load failed: $e');       // <-- and this
      _role = 'patient';
    }
    notifyListeners();
  }

  void clear() {
    _role = null;
    notifyListeners();
  }
}

class CareSlotApp extends StatefulWidget {
  const CareSlotApp({super.key});

  @override
  State<CareSlotApp> createState() => _CareSlotAppState();
}

class _CareSlotAppState extends State<CareSlotApp> {
  late final SupabaseClient _supabase;
  late final AuthGuard _authGuard;
  late final RoleNotifier _roleNotifier;
  late final GoRouter _router;
  final _rootNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _authGuard = AuthGuard(_supabase);
    _roleNotifier = RoleNotifier();

    // Load role once at startup and on every auth change
    _roleNotifier.load();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session == null) {
        _roleNotifier.clear();
      } else {
        _roleNotifier.load();
      }
    });

    _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/welcome',
      refreshListenable: Listenable.merge([_authGuard, _roleNotifier]),
     redirect: (context, state) {
        final isLoggedIn = _supabase.auth.currentUser != null;
        final role = _roleNotifier.role;
        final loc = state.matchedLocation;
        final isAuthPage = loc == '/login' || loc == '/signup' || loc == '/welcome';

        // 1. If not logged in, force them to the welcome/login page
        if (!isLoggedIn) {
          return isAuthPage ? null : '/welcome';
        }

        // 2. If logged in, but they are on an auth page, send them to their dashboard
        if (isAuthPage) {
          if (role == null) return null; // Wait for role to load from database
          if (role == 'doctor') return '/doctor/schedule';
          if (role == 'admin') return '/admin/dashboard';
          return '/doctors';
        }

        // 3. Route Guards: Prevent users from accessing other roles' pages
        final doctorOnly = loc == '/doctor/schedule' ||
            loc == '/doctor/appointments' ||
            loc == '/doctor/profile';
        final adminOnly = loc.startsWith('/admin/');

        if (doctorOnly && role != 'doctor') {
          return role == 'admin' ? '/admin/dashboard' : '/doctors';
        }
        
        if (adminOnly && role != 'admin') {
          return role == 'doctor' ? '/doctor/schedule' : '/doctors';
        }

        return null; // Allow navigation
      },
        // ---------- Admin shell ----------


      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
GoRoute(
  path: '/welcome',
  builder: (context, state) => const WelcomePage(),
),
        // ---------- Patient shell ----------
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ScaffoldWithNavBar(
            navigationShell: navigationShell,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.medical_services_outlined),
                selectedIcon: Icon(Icons.medical_services),
                label: 'Doctors',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: 'Appointments',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/doctors',
                builder: (_, __) => const DoctorListPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/patient/appointments',
                builder: (_, __) => const MyAppointmentsPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ]),
          ],
        ),

        // ---------- Doctor shell ----------
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ScaffoldWithNavBar(
            navigationShell: navigationShell,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Appointments',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/doctor/schedule',
                builder: (_, __) => const DoctorAvailabilityPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/doctor/appointments',
                builder: (_, __) => const DoctorAppointmentsPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/doctor/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ]),
          ],
        ),

        // ---------- Admin shell ----------
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => ScaffoldWithNavBar(
            navigationShell: navigationShell,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Appointments',
              ),
              NavigationDestination(
                icon: Icon(Icons.medical_services_outlined),
                selectedIcon: Icon(Icons.medical_services),
                label: 'Doctors',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (_, __) => const AdminDashboardPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/admin/appointments',
                builder: (_, __) => const AdminAppointmentsPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/admin/doctors',
                builder: (_, __) => const AdminDoctorsPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/admin/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ]),
          ],
        ),
        // ---------- Full-screen pages ----------
       GoRoute(
          path: '/doctor/:id',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) =>
              DoctorDetailPage(doctorId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/book/:doctorId',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) =>
              BookingPage(doctorId: state.pathParameters['doctorId']!),
        ),
        GoRoute(
          path: '/pay/:appointmentId/:amount',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => PaymentPage(
            appointmentId: int.parse(state.pathParameters['appointmentId']!),
            amount: double.parse(state.pathParameters['amount']!),
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CareSlot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
        routerConfig: _router,
           );
  }
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: destinations,
      ),
    );
  }
}