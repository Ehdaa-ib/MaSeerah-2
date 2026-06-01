import 'dart:async';

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
import '../../l10n/app_localizations.dart';
import '../../data/firebase/journey_completion_data_source.dart';
import '../../data/firebase/journey_instance_data_source.dart';
import '../../data/firebase/journey_progress_data_source.dart';
import '../../data/firebase/journey_repurchase_gate_data_source.dart';
import '../../service/journey_inactivity_service.dart';
import '../../service/journey_purchase_flow_service.dart';
import '../../service/journey_user_status_service.dart';
import 'journey_history_memories_screen.dart';
import '../../util/wait_for_auth.dart';
import '../feedback/feedback_screen.dart';
import '../auth/login_screen.dart';
import 'journey_how_to_play_page.dart';
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
  final _flowService = JourneyPurchaseFlowService();

  Journey? _journey;
  Order? _order;
  AppUser? _user;
  String? _uid;
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

  JourneyUserStatus _journeyStatus = JourneyUserStatus.notStarted;
  JourneyPurchaseUiState? _uiState;

  /// True until order/progress/completion reads finish (signed-in users only).
  bool _isAccessLoading = false;

  bool _startingJourney = false;
  bool _isPurchasing = false;

  JourneyRepositoryFirebase get journeyRepo =>
      JourneyRepositoryFirebase(JourneyDataSource());

  Journey _resolveInitialJourney() {
    return widget.initialJourney ??
        JourneyDataSource.findInCatalogCache(widget.journeyId) ??
        Journey(
          journeyId: widget.journeyId,
          name: widget.journeyId,
          price: 0,
        );
  }

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
    _journey = _resolveInitialJourney();
    _isAccessLoading = _uid != null && _uid!.trim().isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureJourneyDetailsLoaded());
      unawaited(_loadUserAccess());
    });
  }

  /// Catalog cache first, then Firestore — stubs from the home card omit description/price.
  Future<void> _ensureJourneyDetailsLoaded() async {
    if (JourneyDataSource.findInCatalogCache(widget.journeyId) == null) {
      try {
        await journeyRepo.getAll();
        if (!mounted) return;
        final cached = JourneyDataSource.findInCatalogCache(widget.journeyId);
        if (cached != null) {
          setState(() => _journey = cached);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[JourneyDetails] catalog preload failed: $e');
      }
    }
    await _refreshJourneyDetails();
  }

  static const Duration _accessLoadTimeout = Duration(seconds: 8);

  Future<T?> _withTimeout<T>(Future<T> future, T fallback) async {
    try {
      return await future.timeout(_accessLoadTimeout);
    } catch (e) {
      if (kDebugMode) debugPrint('[JourneyDetails] access read timeout/fail: $e');
      return fallback;
    }
  }

  void _applyPaidEntitlementOptimistic({Order? paidOrder}) {
    final paidStatus = JourneyPurchaseFlowService.statusFromSnapshot(
      progress: null,
      requiresRepurchase: false,
      journeyCompleted: false,
      awaitingFeedback: false,
    );
    final price = _journey?.price ?? 0;
    final ui = _flowService.resolveFromStatus(
      journeyPrice: price,
      hasPaidOrder: true,
      status: paidStatus,
    );
    setState(() {
      _hasPaidAccess = true;
      _requiresRepurchaseAfterFeedback = false;
      _journeyCompleted = false;
      _awaitingFeedback = false;
      _savedProgress = null;
      if (paidOrder != null) _order = paidOrder;
      _isAccessLoading = false;
      _uiState = ui;
      _journeyStatus = ui.status.status;
    });
  }

  Future<void> _loadUserAccess({bool silent = false}) async {
    if (kDebugMode) debugPrint('[JourneyDetails] access load journeyId=${widget.journeyId}');
    _uid = FirebaseAuth.instance.currentUser?.uid;
    final uid = _uid?.trim();
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _savedProgress = null;
          _uiState = null;
          _isAccessLoading = false;
        });
      }
      return;
    }

    if (mounted && !silent) setState(() => _isAccessLoading = true);

    final progressDs = JourneyProgressDataSource();
    final completionDs = JourneyCompletionDataSource();
    final repurchaseDs = JourneyRepurchaseGateDataSource();

    ActiveJourneyProgress? progress;
    Order? order;
    var hasPaidAccess = _hasPaidAccess;
    var journeyCompleted = false;
    var awaitingFeedback = false;
    var requiresRepurchase = false;

    try {
      final results = await Future.wait<Object?>([
        _withTimeout<ActiveJourneyProgress?>(
          JourneyInactivityService(progressDs: progressDs)
              .resolveActiveProgress(userId: uid, journeyId: widget.journeyId),
          null,
        ),
        _withTimeout<Order?>(
          _orderService.getUserOrderForJourney(
            userId: uid,
            journeyId: widget.journeyId,
          ),
          null,
        ),
        _withTimeout<bool>(
          _orderService.userHasPaidForJourney(
            userId: uid,
            journeyId: widget.journeyId,
          ),
          hasPaidAccess,
        ),
        _withTimeout<bool>(
          completionDs.isCompleted(userId: uid, journeyId: widget.journeyId),
          false,
        ),
        _withTimeout<bool>(
          repurchaseDs.requiresNewPurchase(userId: uid, journeyId: widget.journeyId),
          false,
        ),
      ]);
      progress = results[0] as ActiveJourneyProgress?;
      order = results[1] as Order?;
      hasPaidAccess = results[2] as bool? ?? hasPaidAccess;
      journeyCompleted = results[3] as bool? ?? false;
      requiresRepurchase = results[4] as bool? ?? false;

      if (order?.status == OrderStatus.paid) {
        hasPaidAccess = true;
      }

      if (journeyCompleted) {
        awaitingFeedback = await _withTimeout<bool>(
          completionDs.isAwaitingFeedback(
            userId: uid,
            journeyId: widget.journeyId,
          ),
          false,
        ) ?? false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[JourneyDetails] access load failed: $e');
    }

    if ((journeyCompleted && !awaitingFeedback) || requiresRepurchase) {
      progress = null;
    }

    final price = _journey?.price ?? 0;
    final status = JourneyPurchaseFlowService.statusFromSnapshot(
      progress: progress,
      requiresRepurchase: requiresRepurchase,
      journeyCompleted: journeyCompleted,
      awaitingFeedback: awaitingFeedback,
    );
    final ui = _flowService.resolveFromStatus(
      journeyPrice: price,
      hasPaidOrder: hasPaidAccess,
      status: status,
    );

    if (!mounted) return;
    setState(() {
      _savedProgress = ui.progress ?? progress;
      _order = order;
      _hasPaidAccess = hasPaidAccess;
      _journeyCompleted = journeyCompleted;
      _awaitingFeedback = awaitingFeedback;
      _requiresRepurchaseAfterFeedback = requiresRepurchase;
      _isAccessLoading = false;
      _uiState = ui;
      _journeyStatus = ui.status.status;
    });
  }

  Future<void> _refreshJourneyDetails() async {
    try {
      final fresh = await journeyRepo.getById(widget.journeyId);
      if (!mounted || fresh == null) return;
      setState(() => _journey = fresh);
    } catch (e) {
      if (kDebugMode) debugPrint('[JourneyDetails] journey refresh failed: $e');
    }
  }

  Future<void> _load() async {
    await Future.wait([
      _loadUserAccess(),
      _ensureJourneyDetailsLoaded(),
    ]);
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
        .then((signedIn) async {
      if (signedIn == true && mounted) {
        await waitForAuth();
        if (mounted) _load();
      }
    });
  }

  String _resolveLandmarksJourneyId() {
    final fromCatalog = _journey?.landmarksJourneyId?.trim();
    if (fromCatalog != null && fromCatalog.isNotEmpty) return fromCatalog;
    final lm = widget.journeyId.replaceAll('_', '');
    if (lm.isNotEmpty) return lm;
    return 'journey1';
  }

  JourneyPurchasePrimaryAction get _primaryAction {
    if (_uiState != null) return _uiState!.action;
    if (_isAccessLoading) return JourneyPurchasePrimaryAction.loading;
    return JourneyPurchasePrimaryAction.purchase;
  }

  String _primaryButtonLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_primaryAction) {
      case JourneyPurchasePrimaryAction.continueJourney:
        return l10n.journeyPurchaseContinueYourJourney;
      case JourneyPurchasePrimaryAction.start:
        return l10n.journeyPurchaseStartYourJourney;
      case JourneyPurchasePrimaryAction.purchase:
        return l10n.journeyPurchasePurchaseJourney;
      case JourneyPurchasePrimaryAction.viewHistory:
        return l10n.journeyPurchaseViewHistory;
      case JourneyPurchasePrimaryAction.giveFeedback:
        return l10n.journeyPurchaseGiveFeedback;
      case JourneyPurchasePrimaryAction.signIn:
        return l10n.journeyPurchaseSignInToPurchase;
      case JourneyPurchasePrimaryAction.loading:
        return '';
    }
  }

  void _openJourneyHistory() {
    final title = _journey?.name ?? widget.journeyId;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JourneyHistoryMemoriesScreen(
          journeyId: widget.journeyId,
          journeyName: title,
          completedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _openMapWithProgress(
    ActiveJourneyProgress progress, {
    bool clearRecommendationTracking = false,
  }) async {
    await waitForAuth();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => JourneyMapScreen(
          journeyTitle: _journey?.name ?? progress.journeyTitle,
          landmarksJourneyId: progress.landmarksJourneyId,
          catalogJourneyId: widget.journeyId,
          initialRegion: progress.currentRegion,
          initialQubaChallengeCompleted: progress.qubaChallengeCompleted,
          initialLastRegionChallengeCompleted: progress.lastRegionChallengeCompleted,
          clearRecommendationTracking: clearRecommendationTracking,
          initialUserJourneyId: progress.userJourneyId,
        ),
      ),
    );
  }

  Future<void> _beginNewJourneyRun(String uid) async {
    await _accessService.assertPaidForPlay(
      userId: uid,
      journeyId: widget.journeyId,
    );
    final progressDs = JourneyProgressDataSource();
    final landmarksId = _resolveLandmarksJourneyId();
    String? instanceId;
    try {
      instanceId = await JourneyInstanceDataSource().createInstance(
        userId: uid,
        catalogJourneyId: widget.journeyId,
        journeyTitle: _journey?.name ?? 'Journey',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StartJourney] createInstance failed (map will retry): $e');
      }
    }
    await progressDs.upsert(
      userId: uid,
      journeyId: widget.journeyId,
      journeyTitle: _journey?.name ?? 'Journey',
      landmarksJourneyId: landmarksId,
      catalogJourneyId: widget.journeyId,
      currentRegion: 1,
      qubaChallengeCompleted: false,
      lastRegionChallengeCompleted: false,
      hasSeenHowToPlay: true,
      userJourneyId: instanceId,
    );
    final saved = await progressDs.getUserJourneyProgress(
      userId: uid,
      journeyId: widget.journeyId,
    );
    if (saved == null) {
      throw Exception('Could not start journey. Please try again.');
    }
    if (kDebugMode) {
      debugPrint(
        '[StartJourney] opening map journeyId=${widget.journeyId} '
        'userJourneyId=${saved.userJourneyId}',
      );
    }
    if (!mounted) return;
    await _openMapWithProgress(saved, clearRecommendationTracking: true);
  }

  /// Pushes How to Play on top of this screen so the system back button returns here.
  void _pushHowToPlay({
    required bool needsProgressBootstrap,
    ActiveJourneyProgress? progress,
    bool clearRecommendationTracking = false,
  }) {
    final title = _journey?.name ?? AppLocalizations.of(context)!.journeyPurchaseTitle;
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JourneyHowToPlayPage(
          catalogJourneyId: widget.journeyId,
          journeyTitle: title,
          landmarksJourneyId: _resolveLandmarksJourneyId(),
          presentation: JourneyHowToPlayPresentation.mandatoryFirstTime,
          needsProgressBootstrap: needsProgressBootstrap,
          progressFirestoreDocId: progress?.firestoreDocId,
          initialRegion: progress?.currentRegion,
          initialQubaChallengeCompleted: progress?.qubaChallengeCompleted ?? false,
          initialLastRegionChallengeCompleted: progress?.lastRegionChallengeCompleted ?? false,
          clearRecommendationTracking: clearRecommendationTracking,
          hasSavedMapProgress: progress != null,
          onManualPrimary: null,
        ),
      ),
    )
        .then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _handleHowToPlayManualPrimary(BuildContext howToPlayContext) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    ActiveJourneyProgress? p;
    try {
      p = await JourneyInactivityService()
          .resolveActiveProgress(userId: uid, journeyId: widget.journeyId)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    await waitForAuth();
    if (!howToPlayContext.mounted) return;

    final title = _journey?.name ?? AppLocalizations.of(howToPlayContext)!.journeyPurchaseTitle;

    final prog = p;
    if (prog != null) {
      Navigator.of(howToPlayContext).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => JourneyMapScreen(
            journeyTitle: _journey?.name ?? prog.journeyTitle,
            landmarksJourneyId: prog.landmarksJourneyId,
            catalogJourneyId: widget.journeyId,
            initialRegion: prog.currentRegion,
            initialQubaChallengeCompleted: prog.qubaChallengeCompleted,
            initialLastRegionChallengeCompleted: prog.lastRegionChallengeCompleted,
            clearRecommendationTracking: false,
          ),
        ),
      );
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
      await JourneyProgressDataSource().upsert(
        userId: uid,
        journeyId: widget.journeyId,
        journeyTitle: title,
        landmarksJourneyId: widget.journeyId.replaceAll('_', ''),
        catalogJourneyId: widget.journeyId,
        currentRegion: 1,
        qubaChallengeCompleted: false,
        lastRegionChallengeCompleted: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toUserFriendlyMessage(e))),
        );
      }
      return;
    }

    if (!howToPlayContext.mounted) return;
    Navigator.of(howToPlayContext).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => JourneyMapScreen(
          journeyTitle: title,
          landmarksJourneyId: _resolveLandmarksJourneyId(),
          catalogJourneyId: widget.journeyId,
          clearRecommendationTracking: true,
        ),
      ),
    );
  }

  void _openHowToPlayManual() {
    final title = _journey?.name ?? AppLocalizations.of(context)!.journeyPurchaseTitle;
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JourneyHowToPlayPage(
          catalogJourneyId: widget.journeyId,
          journeyTitle: title,
          landmarksJourneyId: _resolveLandmarksJourneyId(),
          presentation: JourneyHowToPlayPresentation.manualFromPurchase,
          needsProgressBootstrap: false,
          progressFirestoreDocId: _savedProgress?.firestoreDocId,
          initialRegion: _savedProgress?.currentRegion,
          initialQubaChallengeCompleted: _savedProgress?.qubaChallengeCompleted ?? false,
          initialLastRegionChallengeCompleted: _savedProgress?.lastRegionChallengeCompleted ?? false,
          clearRecommendationTracking: false,
          hasSavedMapProgress: _savedProgress != null,
          onManualPrimary: _handleHowToPlayManualPrimary,
        ),
      ),
    )
        .then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _goToMapReplacingSelf({
    required ActiveJourneyProgress? progress,
    bool clearRecommendationTracking = false,
  }) async {
    if (progress == null) return;
    await _openMapWithProgress(progress, clearRecommendationTracking: clearRecommendationTracking);
  }

  Future<void> _purchaseAndPay() async {
    if (_isPurchasing) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) {
      _openSignIn();
      return;
    }
    setState(() {
      _error = null;
      _isPurchasing = true;
    });
    try {
      await waitForAuth();
      final price = _journey?.price;
      var order = await _orderService.getOrCreateCheckoutOrder(
        userId: uid,
        journeyId: widget.journeyId,
        knownPrice: price != null && price > 0 ? price : null,
      );

      Payment payment;
      try {
        payment = await _paymentService.processPayment(
          orderId: order.orderId!,
          paymentMethod: PaymentMethod.card,
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('not pending payment')) {
          order = await _orderService.getOrCreateCheckoutOrder(
            userId: uid,
            journeyId: widget.journeyId,
            knownPrice: price != null && price > 0 ? price : null,
            forceNew: true,
          );
          payment = await _paymentService.processPayment(
            orderId: order.orderId!,
            paymentMethod: PaymentMethod.card,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      setState(() => _order = order);
      _openPaymentScreen(payment);
    } catch (e) {
      if (mounted) {
        setState(() => _error = toUserFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
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
            Navigator.of(context).pop();
            if (!mounted) return;
            _applyPaidEntitlementOptimistic();
            unawaited(_loadUserAccess(silent: true));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.journeyPurchaseStartYourJourney),
              ),
            );
          } catch (e) {
            if (mounted) {
              setState(() {
                _error = toUserFriendlyMessage(e);
                _isAccessLoading = false;
              });
            }
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
              title: Text(
                AppLocalizations.of(context)!.journeyPurchasePayWithMoyasar,
                style: const TextStyle(color: AppColors.brown),
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
                  padding: EdgeInsetsDirectional.fromSTEB(
                    24,
                    MediaQuery.of(context).padding.top + kToolbarHeight + 24,
                    24,
                    24,
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
                      _journey?.name ?? AppLocalizations.of(context)!.journeyPurchaseTitle,
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

  Future<void> _onPrimaryAction() async {
    if (_startingJourney || _isPurchasing) return;
    final action = _primaryAction;

    if (action == JourneyPurchasePrimaryAction.signIn) {
      _openSignIn();
      return;
    }
    if (action == JourneyPurchasePrimaryAction.purchase) {
      await _purchaseAndPay();
      return;
    }
    if (action == JourneyPurchasePrimaryAction.viewHistory) {
      _openJourneyHistory();
      return;
    }
    if (action == JourneyPurchasePrimaryAction.giveFeedback) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => FeedbackScreen(journeyId: widget.journeyId),
        ),
      );
      if (mounted) await _loadUserAccess();
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) {
      _openSignIn();
      return;
    }

    setState(() {
      _error = null;
      _startingJourney = true;
    });

    try {
      if (action == JourneyPurchasePrimaryAction.continueJourney) {
        var progress = _savedProgress ?? _uiState?.progress;
        progress ??= await JourneyInactivityService()
            .resolveActiveProgress(userId: uid, journeyId: widget.journeyId)
            .timeout(const Duration(seconds: 3));
        if (progress == null) {
          throw Exception('No saved progress found. Start the journey again.');
        }
        await _openMapWithProgress(progress, clearRecommendationTracking: false);
        return;
      }

      if (action == JourneyPurchasePrimaryAction.start) {
        await _beginNewJourneyRun(uid);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[StartJourney] primary action failed: $e');
      if (mounted) setState(() => _error = toUserFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _startingJourney = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_journey == null) {
      return Scaffold(
        backgroundColor: AppColors.green,
        appBar: AppBar(
          backgroundColor: AppColors.brown,
          foregroundColor: Colors.white,
          title: Text(AppLocalizations.of(context)!.journeyPurchaseTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? AppLocalizations.of(context)!.journeyPurchaseNotFound,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.brown),
            ),
          ),
        ),
      );
    }
    final journey = _journey!;
    final action = _isAccessLoading
        ? JourneyPurchasePrimaryAction.loading
        : _primaryAction;
    final needsLogin = action == JourneyPurchasePrimaryAction.signIn;
    final isStatusLoading =
        (_isAccessLoading && _uiState == null) || _startingJourney;
    final showHowToPlayInfo = _uiState?.showHowToPlayInfo ?? false;
    const showJourneyFooter = true;

    if (kDebugMode) {
      debugPrint(
        '[JourneyDetails] action=${action.name} '
        'userId=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} '
        'journeyId=${widget.journeyId} '
        'hasPaidAccess=$_hasPaidAccess '
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
        actions: [
          if (showHowToPlayInfo)
            IconButton(
              tooltip: AppLocalizations.of(context)!.journeyPurchaseHowToPlayInfo,
              icon: Icon(Icons.info_outline, color: AppColors.brown.withValues(alpha: 0.92)),
              onPressed: _openHowToPlayManual,
            ),
        ],
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
                      Text(
                        AppLocalizations.of(context)!.journeyPurchaseAbout,
                        style: const TextStyle(
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
                          child: Text(
                            AppLocalizations.of(context)!.journeyPurchaseReadMore,
                            style: const TextStyle(
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
                          child: Text(
                            AppLocalizations.of(context)!.journeyPurchaseReadLess,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.brown,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildJourneyDetailCards(context, journey),
                      const SizedBox(height: 20),
                      _buildInfoCard(context, journey),
                      const SizedBox(height: 24),
                      _buildGoodToKnow(context, journey),
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
                  context: context,
                  journey: journey,
                  action: action,
                  needsLogin: needsLogin,
                  isStatusLoading: isStatusLoading,
                  label: _primaryButtonLabel(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJourneyDetailCards(BuildContext context, Journey j) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailCard(
          icon: Icons.navigation,
          label: l10n.journeyPurchaseStartPoint,
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
          label: l10n.journeyPurchaseStopsAlongWay,
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
          label: l10n.journeyPurchaseEndPoint,
          value: j.endPoint ?? '—',
          valueColorOrange: true,
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, Journey j) {
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

  Widget _buildGoodToKnow(BuildContext context, Journey j) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      l10n.journeyPurchaseGoodToKnow1,
      l10n.journeyPurchaseGoodToKnow2,
      l10n.journeyPurchaseGoodToKnow3,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.journeyPurchaseGoodToKnow,
          style: const TextStyle(
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
    required BuildContext context,
    required Journey journey,
    required JourneyPurchasePrimaryAction action,
    required bool needsLogin,
    required bool isStatusLoading,
    required String label,
  }) {
    if (needsLogin) {
      return _PaymentButton(
        price: journey.price,
        label: label,
        onTap: _openSignIn,
      );
    }
    if (isStatusLoading) {
      return const _PaymentButton(
        price: 0,
        label: '',
        onTap: null,
        isGreen: false,
        centered: true,
        showLoadingIndicator: true,
      );
    }

    final showPrice = action == JourneyPurchasePrimaryAction.purchase;
    final centered = !showPrice;

    return _PaymentButton(
      price: showPrice ? journey.price : 0,
      label: label,
      onTap: _isPurchasing ? null : _onPrimaryAction,
      isGreen: false,
      centered: centered,
      showLoadingIndicator: (_isAccessLoading && _uiState == null) ||
          _startingJourney ||
          _isPurchasing,
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
  final bool showLoadingIndicator;

  const _PaymentButton({
    required this.price,
    required this.label,
    required this.onTap,
    this.isGreen = false,
    this.centered = false,
    this.showLoadingIndicator = false,
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
            child: showLoadingIndicator
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.beige,
                      ),
                    ),
                  )
                : centered
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
