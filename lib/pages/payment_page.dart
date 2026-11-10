import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentPage extends StatefulWidget {
  final int appointmentId;
  final double amount; // dollars
  const PaymentPage({
    super.key,
    required this.appointmentId,
    required this.amount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _supabase = Supabase.instance.client;
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      // 1. Call the Edge Function to create a PaymentIntent
      final res = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': (widget.amount * 100).round(), // convert to cents
          'appointment_id': widget.appointmentId.toString(),
        },
      );

      final data = res.data as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String;
      final paymentIntentId = data['payment_intent_id'] as String;

      if (kIsWeb) {
        // --- WEB TEST MODE ---
        // We skip the native Payment Sheet and simulate a 2-second delay
        // to mimic the user entering their card.
        await Future.delayed(const Duration(seconds: 2));
        debugPrint('Simulated Stripe payment with Client Secret: $clientSecret');
      } else {
        // --- MOBILE MODE (Android/iOS) ---
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'CareSlot',
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }

      // 2. Update the database on success
      await _supabase.from('appointments').update({
        'payment_status': 'paid',
        'status': 'confirmed', // <-- Add this line
        'stripe_payment_id': paymentIntentId,
      }).eq('id', widget.appointmentId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful!')),
      );
      context.go('/patient/appointments');
    } on StripeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment cancelled: ${e.error.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay for appointment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Amount due',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '\$${widget.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Web Test Mode active: Clicking "Pay" will simulate a successful card payment.',
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _paying ? null : _pay,
              child: _paying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(kIsWeb ? 'Simulate Payment' : 'Pay with card'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/patient/appointments'),
              child: const Text('Pay later'),
            ),
          ],
        ),
      ),
    );
  }
}