import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'pages/auth_guard.dart';
import 'pages/doctor_list_page.dart';
import 'pages/doctor_detail_page.dart';
import 'pages/booking_page.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cxsjonvgbfemevgzbxcs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4c2pvbnZnYmZlbWV2Z3pieGNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1MDA3ODgsImV4cCI6MjEwODA3Njc4OH0.RyInlzpOdUq3HOXwSAn-nny1yE08gRmidfC0Z94z-Qc',
  );

  runApp(const CareSlotApp());
}

class CareSlotApp extends StatelessWidget {
  const CareSlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final authGuard = AuthGuard(supabase);

    final router = GoRouter(
      initialLocation: '/login',
      refreshListenable: authGuard,
      redirect: (context, state) {
        final isLoggedIn = supabase.auth.currentUser != null;
        final isAuthPage =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup';

        if (!isLoggedIn && !isAuthPage) return '/login';
        if (isLoggedIn && isAuthPage) return '/home';
        return null;
      },
   routes: [
  GoRoute(
    path: '/login',
    builder: (context, state) => const LoginPage(),
  ),
  GoRoute(
    path: '/signup',
    builder: (context, state) => const SignupPage(),
  ),
  GoRoute(
    path: '/home',
    builder: (context, state) => const DoctorListPage(),
  ),
  GoRoute(
    path: '/doctor/:id',
    builder: (context, state) =>
        DoctorDetailPage(doctorId: state.pathParameters['id']!),
  ),
  GoRoute(
  path: '/book/:doctorId',
  builder: (context, state) =>
      BookingPage(doctorId: state.pathParameters['doctorId']!),
),
],
    );

    return MaterialApp.router(
      title: 'CareSlot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}