import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:careslot/core/theme/app_theme.dart';
import 'package:careslot/core/widgets/app_logo.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Soft background decoration (standard for modern UI)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.05), // Very soft teal
                ),
              ),
            ),
            
            // 2. Main Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  
                  // Large Logo
                  const Center(
                    child: AppLogo(height: 100),
                  ),
                  const SizedBox(height: 40),
                  
                  // Headline
                  Text(
                    'Your health, on your schedule.',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    'Find top-rated doctors, book appointments instantly, and manage your healthcare in one simple place.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const Spacer(flex: 3),
                  
                  // Primary Button (Get Started)
                  FilledButton(
                    onPressed: () => context.push('/signup'),
                    child: const Text('Create an Account'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Secondary Link (Already have an account?)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account?",
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text('Log In'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Terms of Service
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}