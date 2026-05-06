import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
import '../../data/firebase/journey_completion_data_source.dart';
import '../../data/firebase/journey_progress_data_source.dart';
import '../../data/firebase/journey_repurchase_gate_data_source.dart';
import '../../service/journey_user_status_service.dart';
import '../feedback/feedback_screen.dart';
import '../auth/login_screen.dart';
import 'journey_map_screen.dart';

/// Journey description and purchase page. Collapsing header, About, Good to know, sticky payment button.
class JourneyPurchaseScreen extends StatefulWidget {
  final AppUser? user;
  final String journeyId;
  final Journey? initialJourney;
  final ActiveJourneyProgress? initialSavedProgress;

  const JourneyPurchaseScreen({
    super.key,
    this.user,
    this.journeyId = 'journey_1',
    this.initialJourney,
    this.initialSavedProgress,
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
  String? _uid;
  bool _loading = true;
  String? _error;
  bool _descriptionExpanded = false;

  /// At least one paid order for this journey (supports a newer pending order while repaying).
  bool _hasPaidAccess = false;

  /// Firestore completion doc exists — user must pay again before the next playthrough.
  bool _journeyCompleted = false;

  /// Journey finished on the map, but feedback not submitted yet.
  bool _awaitingFeedback = false;

  /// Set after submitting feedback; cleared when a new payment succeeds.
  bool _requiresRepurchaseAfterFeedback = false;

  /// Saved map progress (in-progress journey); used for Continue + Active Journeys list.
  ActiveJourneyProgress? _savedProgress;

  JourneyUserStatus _journeyStatus = JourneyUserStatus.loading;

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
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _user = widget.user;
    _savedProgress = widget.initialSavedProgress;
    _journeyStatus = JourneyUserStatus.loading;
    if (widget.initialJourney != null) {
      _journey = widget.initialJourney;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    if (kDebugMode) debugPrint('[JourneyDetails] screen open journeyId=${widget.journeyId}');
    final hasInitial = widget.initialJourney != null;
    if (!hasInitial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Always load the journey first (public read) so the intro screen is usable even if
      // user-scoped reads fail due to auth state / rules.
      Journey? journey = hasInitial ? _journey : await journeyRepo.getById(widget.journeyId);

      _uid = FirebaseAuth.instance.currentUser?.uid;
      final uidNow = _uid;
      if (uidNow != null && uidNow.trim().isNotEmpty) {
        if (kDebugMode) debugPrint('[JourneyDetails] status fetch start userId=$uidNow journeyId=${widget.journeyId}');
        try {
          final s = await JourneyUserStatusService().getStatus(
            userId: uidNow,
            journeyId: widget.journeyId,
          );
          if (!mounted) return;
          setState(() {
            _journeyStatus = s.status;
            if (s.progress != null) _savedProgress = s.progress;
          });
          if (kDebugMode) {
            debugPrint(
              '[JourneyDetails] status fetch complete userId=$uidNow journeyId=${widget.journeyId} '
              'status=${s.status.name} progressDocId=${s.progress?.journeyId ?? 'none'}',
            );
          }
        } catch (e) {
          if (!mounted) return;
          setState(() => _journeyStatus = JourneyUserStatus.notStarted);
          if (kDebugMode) debugPrint('[JourneyDetails] status fetch failed: $e');
        }
      } else {
        if (mounted) setState(() => _journeyStatus = JourneyUserStatus.notStarted);
      }

      AppUser? user;
      try {
        user = await _getCurrentUser();
      } catch (_) {
        user = null;
      }
      _user = user ?? widget.user;
      Order? order;
      var hasPaidAccess = false;
      var journeyCompleted = false;
      var awaitingFeedback = false;
      var requiresRepurchase = false;
      final uid = _uid;
      if (uid != null && uid.trim().isNotEmpty) {
        // 1) Always check progress first (same source of truth as Active Journeys tab).
        // This must not be blocked by order/completion reads, which can fail independently.
        ActiveJourneyProgress? progress;
        try {
          progress = await JourneyProgressDataSource().getUserJourneyProgress(
            userId: uid,
            journeyId: widget.journeyId,
          );
          if (progress != null) {
            _savedProgress = progress;
            _journeyStatus = JourneyUserStatus.active;
          }
        } catch (_) {
          // Keep any optimistic progress already in state.
        }

        try {
          order = await _orderService.getUserOrderForJourney(
            userId: uid,
            journeyId: widget.journeyId,
          );
          hasPaidAccess = await _orderService.userHasPaidForJourney(
            userId: uid,
            journeyId: widget.journeyId,
          );
          journeyCompleted = await JourneyCompletionDataSource().isCompleted(
            userId: uid,
            journeyId: widget.journeyId,
          );
          if (journeyCompleted) {
            awaitingFeedback = await JourneyCompletionDataSource().isAwaitingFeedback(
              userId: uid,
              journeyId: widget.journeyId,
            );
          }
          requiresRepurchase = await JourneyRepurchaseGateDataSource().requiresNewPurchase(
            userId: uid,
            journeyId: widget.journeyId,
          );
          // If the journey is truly completed (not just awaiting feedback) or requires repurchase,
          // clear progress so "Continue" doesn't show for the next run.
          if ((journeyCompleted && !awaitingFeedback) || requiresRepurchase) {
            _savedProgress = null;
          }
        } catch (_) {
          // If any user-scoped reads fail (e.g. temporarily signed out), still show the journey intro.
          order = null;
          // IMPORTANT: do not overwrite prior known flags on transient failures.
          // Otherwise the button can incorrectly regress to "Unlock Journey" for already-paid journeys.
          hasPaidAccess = _hasPaidAccess;
          journeyCompleted = _journeyCompleted;
          awaitingFeedback = _awaitingFeedback;
          requiresRepurchase = _requiresRepurchaseAfterFeedback;
          // Preserve any optimistic progress passed from the map screen (and any existing _savedProgress).
        }

        if (kDebugMode) {
          debugPrint(
            '[JourneyDetails] userId=$uid journeyId=${widget.journeyId} '
            'progressDocId=${_savedProgress?.journeyId ?? 'none'} '
            'currentRegion=${_savedProgress?.currentRegion.toString() ?? 'n/a'} '
            'isCompleted=$journeyCompleted awaitingFeedback=$awaitingFeedback requiresRepurchase=$requiresRepurchase',
          );
        }
      } else {
        _savedProgress = null;
      }
      if (mounted) {
        setState(() {
          _journey ??= journey;
          _order = order;
          _hasPaidAccess = hasPaidAccess;
          _journeyCompleted = journeyCompleted;
          _awaitingFeedback = awaitingFeedback;
          _requiresRepurchaseAfterFeedback = requiresRepurchase;
          if (_journeyStatus == JourneyUserStatus.loading) {
            _journeyStatus = (_savedProgress != null)
                ? JourneyUserStatus.active
                : (journeyCompleted || requiresRepurchase)
                    ? JourneyUserStatus.completed
                    : JourneyUserStatus.notStarted;
          }
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
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => const LoginScreen(returnToCallerOnSuccess: true),
          ),
        )
        .then((signedIn) {
      if (signedIn == true && mounted) {
        _load();
      }
    });
  }

  Future<void> _purchaseAndPay() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) {
      _openSignIn();
      return;
    }
    final canResumePaidRun =
        _savedProgress != null || (_hasPaidAccess && !_journeyCompleted && !_requiresRepurchaseAfterFeedback);
    if (canResumePaidRun) {
      await _startJourney();
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      Order order;
      final o = _order;
      final mustCreateNewOrder = o == null ||
          o.status == OrderStatus.cancelled ||
          (o.status == OrderStatus.paid && _journeyCompleted) ||
          (o.status == OrderStatus.paid && _requiresRepurchaseAfterFeedback);
      if (mustCreateNewOrder) {
        order = await _orderService.createOrder(
          userId: uid,
          journeyId: widget.journeyId,
        );
      } else {
        order = o;
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
    final supported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!supported) {
      setState(() {
        _error =
            'Payments are only supported on Android/iOS right now. Please run the app on a mobile device/emulator to pay.';
      });
      return;
    }

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
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              try {
                await JourneyCompletionDataSource().clearCompletion(
                  userId: uid,
                  journeyId: widget.journeyId,
                );
              } catch (_) {
                // Allow navigation even if rules block delete; user may need rules update.
              }
              try {
                await JourneyRepurchaseGateDataSource().clearRepurchaseGate(
                  userId: uid,
                  journeyId: widget.journeyId,
                );
              } catch (_) {}
              try {
                await JourneyProgressDataSource().delete(
                  userId: uid,
                  journeyId: widget.journeyId,
                );
              } catch (_) {}
            }
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => JourneyMapScreen(
                  journeyTitle: _journey?.name ?? 'Journey',
                  landmarksJourneyId: widget.journeyId.replaceAll('_', ''),
                  catalogJourneyId: widget.journeyId,
                ),
              ),
            );
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
        builder: (context) => Theme(
          data: ThemeData(
            colorScheme: ColorScheme.light(
              primary: AppColors.brown,
              onPrimary: Colors.white,
              surface: AppColors.beige,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brown,
                foregroundColor: Colors.white,
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brown,
                foregroundColor: Colors.white,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              fillColor: AppColors.beige,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              labelStyle: const TextStyle(color: AppColors.brown),
              floatingLabelStyle: const TextStyle(color: AppColors.brown),
              hintStyle: TextStyle(color: AppColors.brown.withOpacity(0.6)),
            ),
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: AppColors.brown,
              displayColor: AppColors.brown,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: AppBar(
              title: const Text(
                'Pay with Moyasar',
                style: TextStyle(color: AppColors.brown),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppColors.brown),
            ),
            body: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'images/image3.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + 24,
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
                      style: const TextStyle(
                        color: AppColors.brown,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _journey?.name ?? 'Journey',
                      style: const TextStyle(
                        color: AppColors.brown,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    moyasar.CreditCard(config: config, onPaymentResult: onPaymentResult),
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startJourney() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) {
      _openSignIn();
      return;
    }
    setState(() {
      _error = null;
    });

    ActiveJourneyProgress? effectiveProg = _savedProgress;
    try {
      final prog = await JourneyProgressDataSource()
          .get(userId: uid, journeyId: widget.journeyId)
          .timeout(const Duration(seconds: 2));
      effectiveProg = prog ?? effectiveProg;
    } catch (_) {}

    // Resuming mid-journey: go to the map immediately (do not wait on access/order reads).
    if (effectiveProg != null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => JourneyMapScreen(
              journeyTitle: _journey?.name ?? effectiveProg?.journeyTitle ?? 'Journey',
              landmarksJourneyId: effectiveProg?.landmarksJourneyId ?? widget.journeyId.replaceAll('_', ''),
              catalogJourneyId: widget.journeyId,
              initialRegion: effectiveProg?.currentRegion,
              initialQubaChallengeCompleted: effectiveProg?.qubaChallengeCompleted ?? false,
              initialLastRegionChallengeCompleted: effectiveProg?.lastRegionChallengeCompleted ?? false,
            ),
          ),
        );
      }
      // Optional: reconcile access in background (does not block navigation).
      Future<void>(() async {
        try {
          await _accessService.startJourney(userId: uid, journeyId: widget.journeyId);
        } catch (_) {}
      });
      return;
    }

    try {
      await _accessService.startJourney(
        userId: uid,
        journeyId: widget.journeyId,
      );
      // First time starting: create an "active journey" record immediately so if the
      // user goes back to Home (or logs out) they still see "Continue your journey".
      try {
        await JourneyProgressDataSource().upsert(
          userId: uid,
          journeyId: widget.journeyId,
          journeyTitle: _journey?.name ?? 'Journey',
          landmarksJourneyId: widget.journeyId.replaceAll('_', ''),
          catalogJourneyId: widget.journeyId,
          currentRegion: 1,
          qubaChallengeCompleted: false,
          lastRegionChallengeCompleted: false,
        );
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => JourneyMapScreen(
              journeyTitle: _journey?.name ?? 'Journey',
              landmarksJourneyId: widget.journeyId.replaceAll('_', ''),
              catalogJourneyId: widget.journeyId,
            ),
          ),
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
        backgroundColor: AppColors.green,
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
        backgroundColor: AppColors.green,
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
    // If progress exists, we should always offer "Continue" (same behavior as Active Journeys).
    final hasSavedProgress = _savedProgress != null;
    final shouldGiveFeedback = _journeyCompleted && _awaitingFeedback && !_requiresRepurchaseAfterFeedback;
    final canResumePaidRun =
        hasSavedProgress || (_hasPaidAccess && !_journeyCompleted && !_requiresRepurchaseAfterFeedback);
    final canPay = _order != null &&
        _order!.status == OrderStatus.pendingPayment &&
        !canResumePaidRun;
    final showPurchase = _order == null ||
        _order!.status == OrderStatus.cancelled ||
        _order!.status == OrderStatus.pendingPayment;
    final needsLogin = FirebaseAuth.instance.currentUser == null;
    final isStatusLoading = !needsLogin && _journeyStatus == JourneyUserStatus.loading;
    final canStartJourney = !isStatusLoading &&
        (hasSavedProgress || (_hasPaidAccess && !_journeyCompleted && !_requiresRepurchaseAfterFeedback));
    final showJourneyFooter = needsLogin ||
        isStatusLoading ||
        showPurchase ||
        canPay ||
        canStartJourney ||
        shouldGiveFeedback ||
        (_user != null && journey.price > 0 && (_journeyCompleted || _requiresRepurchaseAfterFeedback));

    if (kDebugMode) {
      final buttonState = needsLogin
          ? 'needsLogin'
          : shouldGiveFeedback
              ? 'giveFeedback'
              : canStartJourney
                  ? 'continueOrStart'
                  : canPay
                      ? 'payPending'
                      : 'unlock';
      debugPrint(
        '[JourneyDetails] resolvedButtonState=$buttonState '
        'userId=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} '
        'journeyId=${widget.journeyId} '
        'hasSavedProgress=$hasSavedProgress hasPaidAccess=$_hasPaidAccess '
        'orderStatus=${_order?.status.name ?? 'none'} '
        'completed=$_journeyCompleted awaitingFeedback=$_awaitingFeedback repurchaseGate=$_requiresRepurchaseAfterFeedback',
      );
    }

    final description = journey.description ?? '';
    const previewLength = 200;

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        title: Text(
          journey.name,
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                            'images/darb-alsunnah.png',
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
          if (showJourneyFooter)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _buildBottomButton(
                  journey: journey,
                  needsLogin: needsLogin,
                  canStartJourney: canStartJourney,
                  canPay: canPay,
                  showPurchase: showPurchase,
                  shouldGiveFeedback: shouldGiveFeedback,
                  isStatusLoading: isStatusLoading,
                  startJourneyLabel:
                      (_savedProgress != null) ? 'Continue your journey' : 'Start your journey',
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
    required bool canStartJourney,
    required bool canPay,
    required bool showPurchase,
    required bool shouldGiveFeedback,
    required bool isStatusLoading,
    required String startJourneyLabel,
  }) {
    if (needsLogin) {
      return _PaymentButton(
        price: journey.price,
        label: 'Sign in to purchase',
        onTap: _openSignIn,
      );
    }
    if (isStatusLoading) {
      return _PaymentButton(
        price: 0,
        label: 'Loading…',
        onTap: null,
        isGreen: false,
        centered: true,
      );
    }
    if (shouldGiveFeedback) {
      return _PaymentButton(
        price: 0,
        label: 'Give feedback',
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => FeedbackScreen(journeyId: widget.journeyId),
            ),
          );
        },
        isGreen: false,
        centered: true,
      );
    }
    if (canPay) {
      return _PaymentButton(
        price: journey.price,
        label: 'Unlock Journey',
        onTap: _purchaseAndPay,
        isGreen: false,
        centered: false,
      );
    }
    if (canStartJourney) {
      return _PaymentButton(
        price: 0,
        label: startJourneyLabel,
        onTap: _startJourney,
        isGreen: false,
        centered: true,
      );
    }
    return _PaymentButton(
      price: journey.price,
      label: 'Unlock Journey',
      onTap: _purchaseAndPay,
      isGreen: false,
      centered: false,
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
                '7',
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
  final VoidCallback? onTap;
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
