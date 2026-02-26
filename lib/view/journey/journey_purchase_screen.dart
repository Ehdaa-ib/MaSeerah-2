import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:moyasar/moyasar.dart' as moyasar;

import '../../core/error_messages.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/firebase/order_data_source.dart';
import '../../data/firebase/payment_data_source.dart';
import '../../data/repoImp/journey_repository_firebase.dart';
import '../../data/repoImp/order_repository_firebase.dart';
import '../../data/repoImp/payment_repository_firebase.dart';
import '../../model/app_user.dart';
import '../../model/journey.dart';
import '../../model/order.dart';
import '../../model/payment.dart';
import '../../service/access_service.dart';
import '../../service/order_service.dart';
import '../../service/payment_service.dart';
import '../auth/login_screen.dart';

/// Journey purchase flow. User must be signed in to purchase; otherwise shows "Sign in to purchase".
class JourneyPurchaseScreen extends StatefulWidget {
  final AppUser? user;
  final String journeyId;

  const JourneyPurchaseScreen({
    super.key,
    this.user,
    this.journeyId = 'journey1',
  });

  @override
  State<JourneyPurchaseScreen> createState() => _JourneyPurchaseScreenState();
}

class _JourneyPurchaseScreenState extends State<JourneyPurchaseScreen> {
  late final OrderService _orderService;
  late final PaymentService _paymentService;
  late final AccessService _accessService;

  Journey? _journey;
  Order? _order;
  AppUser? _user;
  bool _loading = true;
  String? _error;
  String? _success;

  JourneyRepositoryFirebase get journeyRepo =>
      JourneyRepositoryFirebase(JourneyDataSource());

  @override
  void initState() {
    super.initState();
    final journeyRepo = JourneyRepositoryFirebase(JourneyDataSource());
    final orderRepo = OrderRepositoryFirebase(OrderDataSource());
    final paymentRepo = PaymentRepositoryFirebase(PaymentDataSource());
    _orderService = OrderService(journeyRepo: journeyRepo, orderRepo: orderRepo);
    _paymentService = PaymentService(orderRepo: orderRepo, paymentRepo: paymentRepo);
    _accessService = AccessService(journeyRepo: journeyRepo, orderRepo: orderRepo);
    _user = widget.user;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      _user ??= await _getCurrentUser();
      var journey = await journeyRepo.getById(widget.journeyId);
      if (journey == null && _user != null) {
        await _seedJourney();
        journey = await journeyRepo.getById(widget.journeyId);
      }
      Order? order;
      if (_user != null) {
        order = await _orderService.getUserOrderForJourney(
          userId: _user!.userId,
          journeyId: widget.journeyId,
        );
      }
      if (mounted) {
        setState(() {
          _journey = journey;
          _order = order;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = toUserFriendlyMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<AppUser?> _getCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['userId'] = doc.id;
    return AppUser.fromMap(data);
  }

  Future<void> _seedJourney() async {
    await FirebaseFirestore.instance.collection('journeys').doc(widget.journeyId).set({
      'name': 'MaSeerah Journey',
      'price': 99.99,
    });
  }

  void _openSignIn() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()))
        .then((_) => _load());
  }

  Future<void> _purchaseAndPay() async {
    if (_user == null) {
      _openSignIn();
      return;
    }
    setState(() {
      _error = null;
      _success = null;
    });
    try {
      Order order;
      if (_order == null || _order!.status == OrderStatus.cancelled) {
        order = await _orderService.createOrder(
          userId: _user!.userId,
          journeyId: widget.journeyId,
        );
      } else {
        order = _order!;
      }
      final payment = await _paymentService.processPayment(
        orderId: order.orderId!,
        paymentMethod: PaymentMethod.card,
      );
      if (!mounted) return;
      _openPaymentScreen(payment);
    } catch (e) {
      if (mounted) setState(() => _error = toUserFriendlyMessage(e));
    }
  }

  void _openPaymentScreen(Payment payment) {
    final amountHalalas = (payment.amount * 100).round();
    final config = moyasar.PaymentConfig(
      publishableApiKey: _paymentService.publishableKey,
      amount: amountHalalas,
      currency: payment.currency,
      description: 'Order ${payment.orderId}',
      metadata: {'orderId': payment.orderId},
      creditCard: moyasar.CreditCardConfig(saveCard: false, manual: false),
      applePay: moyasar.ApplePayConfig(
        merchantId: 'merchant.com.maseerah',
        label: 'MaSeerah',
        saveCard: false,
        manual: false,
      ),
    );

    void onPaymentResult(result) async {
      if (!mounted) return;
      if (result is moyasar.PaymentResponse) {
        final gatewayId = result.id;
        if (result.status == moyasar.PaymentStatus.paid) {
          try {
            await _paymentService.handlePaymentSuccess(
              paymentId: payment.paymentId!,
              gatewayTransactionId: gatewayId,
            );
            if (!mounted) return;
            Navigator.of(context).pop();
            await _load();
            if (mounted) setState(() => _success = 'Payment successful!');
          } catch (e) {
            if (mounted) setState(() => _error = toUserFriendlyMessage(e));
          }
        } else if (result.status == moyasar.PaymentStatus.failed) {
          try {
            await _paymentService.handlePaymentFailed(paymentId: payment.paymentId!);
          } catch (_) {}
          if (!mounted) return;
          Navigator.of(context).pop();
          setState(() => _error = 'Payment failed. Please try again.');
        }
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Pay with Moyasar')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _journey?.name ?? 'Journey',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                moyasar.CreditCard(config: config, onPaymentResult: onPaymentResult),
                const SizedBox(height: 16),
                const Text('or', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                moyasar.ApplePay(config: config, onPaymentResult: onPaymentResult),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startJourney() async {
    if (_user == null) {
      _openSignIn();
      return;
    }
    setState(() {
      _error = null;
      _success = null;
    });
    try {
      await _accessService.startJourney(
        userId: _user!.userId,
        journeyId: widget.journeyId,
      );
      if (mounted) setState(() => _success = 'Journey started! Enjoy your experience.');
    } catch (e) {
      if (mounted) setState(() => _error = toUserFriendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journey')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_journey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journey')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Journey not found.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final journey = _journey!;
    final isPaid = _order?.status == OrderStatus.paid;
    final canPay = _order != null && _order!.status == OrderStatus.pendingPayment;
    final showPurchase = _order == null ||
        _order!.status == OrderStatus.cancelled ||
        _order!.status == OrderStatus.pendingPayment;
    final needsLogin = _user == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Journey')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${journey.price.toStringAsFixed(2)} SAR',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (needsLogin)
              FilledButton.icon(
                onPressed: _openSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in to purchase'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else if (showPurchase && !canPay)
              FilledButton.icon(
                onPressed: _purchaseAndPay,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Purchase Journey'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else if (canPay)
              FilledButton.icon(
                onPressed: _purchaseAndPay,
                icon: const Icon(Icons.payment),
                label: const Text('Pay Now'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            if (isPaid)
              FilledButton.icon(
                onPressed: _startJourney,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Journey'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
              ),
            if (_success != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_success!, style: const TextStyle(color: Colors.green))),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
