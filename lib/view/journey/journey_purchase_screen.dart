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
import '../../core/app_colors.dart';
import '../auth/login_screen.dart';

/// Journey description and purchase page. Collapsing header, About, Good to know, sticky payment button.
class JourneyPurchaseScreen extends StatefulWidget {
  final AppUser? user;
  final String journeyId;
  final Journey? initialJourney;

  const JourneyPurchaseScreen({
    super.key,
    this.user,
    this.journeyId = 'journey_1',
    this.initialJourney,
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
  bool _descriptionExpanded = false;

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
    if (widget.initialJourney != null) {
      _journey = widget.initialJourney;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    final hasInitial = widget.initialJourney != null;
    if (!hasInitial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      _user ??= await _getCurrentUser();
      Journey? journey = hasInitial ? _journey : await journeyRepo.getById(widget.journeyId);
      Order? order;
      if (_user != null) {
        order = await _orderService.getUserOrderForJourney(
          userId: _user!.userId,
          journeyId: widget.journeyId,
        );
      }
      if (mounted) {
        setState(() {
          _journey ??= journey;
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment successful!'), backgroundColor: Colors.green),
              );
            }
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
    });
    try {
      await _accessService.startJourney(
        userId: _user!.userId,
        journeyId: widget.journeyId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey started! Enjoy your experience.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = toUserFriendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.brown,
          foregroundColor: Colors.white,
          title: const Text('Journey'),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.brown)),
      );
    }
    if (_journey == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.brown,
          foregroundColor: Colors.white,
          title: const Text('Journey'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Journey not found.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.brown),
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

    final description = journey.description ?? '';
    const previewLength = 200;

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        title: const Text(
          'Darb Al-Sunnah',
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.brown,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.brown),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'images/darb-alsunnah-1.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.green,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _descriptionExpanded
                            ? description
                            : (description.length > previewLength
                                ? '${description.substring(0, previewLength)}...'
                                : description),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.brown,
                          height: 1.5,
                        ),
                      ),
                      if (description.length > previewLength && !_descriptionExpanded)
                        GestureDetector(
                          onTap: () => setState(() => _descriptionExpanded = true),
                          child: const Text(
                            'read more',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.brown,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                      else if (description.length > previewLength && _descriptionExpanded)
                        GestureDetector(
                          onTap: () => setState(() => _descriptionExpanded = false),
                          child: const Text(
                            'read less',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.brown,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildJourneyDetailCards(journey),
                      const SizedBox(height: 20),
                      _buildInfoCard(journey),
                      const SizedBox(height: 24),
                      _buildGoodToKnow(journey),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showPurchase || canPay || isPaid)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _buildBottomButton(
                  journey: journey,
                  needsLogin: needsLogin,
                  isPaid: isPaid,
                  canPay: canPay,
                  showPurchase: showPurchase,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJourneyDetailCards(Journey j) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailCard(
          icon: Icons.navigation,
          label: 'Start point',
          value: j.startPoint ?? '—',
          valueColorOrange: true,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
          child: CustomPaint(
            size: const Size(2, 24),
            painter: _DottedLinePainter(color: AppColors.brown),
          ),
        ),
        _DetailCard(
          icon: null,
          label: 'Stops along the way',
          value: null,
          isStops: true,
          valueColorOrange: false,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
          child: CustomPaint(
            size: const Size(2, 24),
            painter: _DottedLinePainter(color: AppColors.brown),
          ),
        ),
        _DetailCard(
          icon: Icons.flag,
          label: 'End point',
          value: j.endPoint ?? '—',
          valueColorOrange: true,
        ),
      ],
    );
  }

  Widget _buildInfoCard(Journey j) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(icon: Icons.directions_walk, text: j.distance ?? '5 km'),
          _InfoItem(icon: Icons.access_time, text: j.estimatedDuration ?? '2-3 hours'),
          _InfoItem(icon: Icons.language, text: j.languages ?? 'Arabic, English'),
        ],
      ),
    );
  }

  Widget _buildGoodToKnow(Journey j) {
    const items = [
      'Best time to explore is after Fajr or after Asr',
      'Avoid exploring during midday due to the heat',
      'You can enjoy the journey by walking, cycling, or using a golf cart',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Good to know',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Icon(Icons.error_outline, size: 22, color: AppColors.orange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.brown,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildBottomButton({
    required Journey journey,
    required bool needsLogin,
    required bool isPaid,
    required bool canPay,
    required bool showPurchase,
  }) {
    if (needsLogin) {
      return _PaymentButton(
        price: journey.price,
        label: 'Sign in to purchase',
        onTap: _openSignIn,
      );
    }
    if (isPaid) {
      return _PaymentButton(
        price: 0,
        label: 'Start Your Journey',
        onTap: _startJourney,
        isGreen: false,
        centered: true,
      );
    }
    return _PaymentButton(
      price: journey.price,
      label: 'Unlock Journey',
      onTap: _purchaseAndPay,
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? value;
  final bool isStops;
  final bool valueColorOrange;

  const _DetailCard({
    this.icon,
    required this.label,
    this.value,
    this.isStops = false,
    this.valueColorOrange = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 80,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, color: AppColors.orange, size: 24)
          else if (isStops)
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '8',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
          else
            const SizedBox(width: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.brown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    value!,
                    style: TextStyle(
                      fontSize: 15,
                      color: valueColorOrange ? AppColors.orange : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.orange, size: 22),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.brown,
          ),
        ),
      ],
    );
  }
}

class _PaymentButton extends StatelessWidget {
  final double price;
  final String label;
  final VoidCallback onTap;
  final bool isGreen;
  final bool centered;

  const _PaymentButton({
    required this.price,
    required this.label,
    required this.onTap,
    this.isGreen = false,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Material(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: isGreen ? AppColors.orange : AppColors.brown,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: centered
                ? Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.beige,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price > 0 ? '${price.toStringAsFixed(0)} SAR' : '',
                        style: TextStyle(
                          color: AppColors.beige,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.beige,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;

  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawCircle(Offset(size.width / 2, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
