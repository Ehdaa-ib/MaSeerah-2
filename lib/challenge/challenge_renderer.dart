import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import '../core/app_colors.dart';
import '../core/map_button_styles.dart';
import '../core/map_design_tokens.dart';
import '../core/map_text_styles.dart';
import '../model/challenge_model.dart';
import '../model/challenge_stage_model.dart';
import '../model/challenge_type.dart';
import 'challenge_styles.dart';
import 'challenge_validation.dart';
import 'widgets/arrange_sentence_alternative_challenge.dart';
import 'widgets/arrange_sentence_multiple_choice_challenge.dart';
import 'widgets/fill_blank_multiple_choice_challenge.dart';
import 'widgets/fill_blank_with_choices_challenge.dart';
import 'widgets/match_columns_challenge.dart';
import 'widgets/multiple_choice_challenge.dart';
import 'widgets/order_events_challenge.dart';
import 'widgets/styled_order_events_challenge.dart';
import 'widgets/unknown_challenge_widget.dart';

bool _usableLegAmount(double? v) => v != null && v.isFinite;

String _formatLegAmount(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Renders a parsed [ChallengeModel] (direct or multi-stage).
///
/// TODO: Wire into landmark region flow after content sheet.
/// TODO: Stage progress bar + animations between stages.
/// TODO: Aggregate scoring and write completion to Firestore.
class ChallengeRenderer extends StatefulWidget {
  const ChallengeRenderer({
    super.key,
    required this.challenge,
    this.currentRegionOrder,
    this.resolveNextDestination,
    this.onResultNext,
    this.nextLandmarkDocumentId,
    this.onChallengeResolved,
  });

  final ChallengeModel challenge;

  /// Current region order/index (1-based) for building result info.
  final int? currentRegionOrder;

  /// Provides next-destination info from Firestore-loaded landmark data (no hardcoding).
  final Future<ChallengeNextDestination?> Function()? resolveNextDestination;

  /// Called when user presses "Next" on the result page (parent advances map/highlights next region).
  final VoidCallback? onResultNext;

  /// From parent landmark document (e.g. `nextLandmarkId`), not from `quiz`.
  final String? nextLandmarkDocumentId;

  /// Invoked when a stage reports success (e.g. fill-blank correct answer).
  final void Function({required bool success, String? nextLandmarkDocumentId})?
  onChallengeResolved;

  @override
  State<ChallengeRenderer> createState() => _ChallengeRendererState();
}

class _ChallengeRendererState extends State<ChallengeRenderer> {
  late int _stageIndex;
  int _wrongAttempts = 0;
  int _shownHintIndex = -1; // -1 none, 0 hint1, 1 hint2
  Object? _selectedAnswer;
  bool _busy = false;
  String? _feedback;
  bool _lastCorrect = false;

  _ResultKind _resultKind = _ResultKind.none;
  ChallengeNextDestination? _nextDestination;
  String? _correctAnswerDisplay;
  bool _resultAutoSolved = false;

  @override
  void initState() {
    super.initState();
    _stageIndex = 0;
    if (kDebugMode) {
      debugPrint(
        '[Challenge] init landmark=${widget.challenge.landmarkDocumentId ?? 'unknown'} '
        'stages=${widget.challenge.stageCount}',
      );
    }
  }

  ChallengeStageModel get _stage => widget.challenge.stages[_stageIndex];

  bool get _isLastStage => _stageIndex >= widget.challenge.stageCount - 1;

  bool get _hasHints => _stage.hints.isNotEmpty;

  /// Hint button unlock logic:
  /// - wrongAttempts == 3 unlocks hint #1 if available
  /// - wrongAttempts == 4 unlocks hint #2 if available
  /// After consuming a hint, the button is disabled again until the next unlock point.
  bool get _hintEnabled {
    if (!_hasHints) return false;
    final hints = _stage.hints;
    if (_wrongAttempts == 3) return _shownHintIndex < 0;
    if (_wrongAttempts == 4) return hints.length >= 2 && _shownHintIndex < 1;
    return false;
  }

  void _resetForStage() {
    _wrongAttempts = 0;
    _shownHintIndex = -1;
    _selectedAnswer = null;
    _busy = false;
    _feedback = null;
    _lastCorrect = false;
  }

  Future<void> _advanceStage() async {
    final total = widget.challenge.stageCount;
    if (_stageIndex >= total - 1) return;
    setState(() {
      _stageIndex += 1;
      _resetForStage();
      _resultKind = _ResultKind.none;
      _nextDestination = null;
      _correctAnswerDisplay = null;
      _resultAutoSolved = false;
    });
    if (kDebugMode) {
      debugPrint(
        '[Challenge] Next Stage -> stageIndex=$_stageIndex total=$total',
      );
    }
  }

  String _buildCorrectAnswerDisplay(ChallengeStageModel s) {
    switch (s.type) {
      case ChallengeType.matchColumns:
      case ChallengeType.matching:
        if (s.matchingPairs.isEmpty) return '—';
        return s.matchingPairs.map((p) => '${p.left} → ${p.right}').join('\n');
      case ChallengeType.orderEvents:
      case ChallengeType.orderEventsStyled:
      case ChallengeType.reorder:
      case ChallengeType.arrangeSentenceAlternative:
      case ChallengeType.assemble:
        final order = s.correctOrder;
        if (order.isEmpty) return '—';
        // Sentence builder: show full sentence when it looks like words.
        if (s.type == ChallengeType.arrangeSentenceAlternative) {
          return order.join(' ');
        }
        return order.map((e) => '• $e').join('\n');
      case ChallengeType.fillBlankWithChoices:
      case ChallengeType.fillBlankWithMultipleChoice:
      case ChallengeType.fillBlank:
      case ChallengeType.multipleChoice:
      case ChallengeType.arrangeSentenceWithMultipleChoice:
        final a = s.answer;
        if (a == null) return '—';
        if (a is List) return a.map((e) => e.toString()).join(', ');
        return a.toString();
      case ChallengeType.elimination:
      case ChallengeType.unknown:
        return '—';
    }
  }

  Future<void> _showResult({
    required bool autoSolved,
    required bool isFinalStage,
  }) async {
    if (!mounted) return;
    final stage = _stage;
    final correctDisplay = _buildCorrectAnswerDisplay(stage);
    ChallengeNextDestination? next;
    if (isFinalStage) {
      try {
        next = await widget.resolveNextDestination?.call();
      } catch (_) {
        next = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _resultKind = isFinalStage
          ? _ResultKind.finalResult
          : _ResultKind.stageResult;
      _resultAutoSolved = autoSolved;
      _correctAnswerDisplay = correctDisplay;
      _nextDestination = next;
    });
    if (kDebugMode) {
      final w = next?.walkingTimeFromPreviousMinutes;
      final walkDisplayed = (w != null && w.isFinite)
          ? '${_formatLegAmount(w)} min'
          : 'Not available';
      debugPrint(
        '[ChallengeResult] shown kind=${isFinalStage ? 'final' : 'stage'} stageCount=${widget.challenge.stageCount} '
        'currentStageIndex=$_stageIndex isFinalStage=$isFinalStage autoSolved=$autoSolved '
        'nextName=${next?.name ?? 'null'} dist=${next?.distanceFromPreviousMeters?.toString() ?? 'null'} '
        'parsedWalkingMinutes=$w displayedWalkingTime="$walkDisplayed" correct="$correctDisplay"',
      );
    }
  }

  bool _validateCurrentAnswer() {
    final s = _stage;
    switch (s.type) {
      case ChallengeType.multipleChoice:
      case ChallengeType.fillBlankWithChoices:
      case ChallengeType.fillBlankWithMultipleChoice:
      case ChallengeType.fillBlank:
      case ChallengeType.arrangeSentenceWithMultipleChoice:
        final candidate = (_selectedAnswer is String)
            ? (_selectedAnswer as String)
            : '';
        return ChallengeValidation.validateStringAnswer(
          candidate: candidate,
          expected: s.answer,
        );
      case ChallengeType.matchColumns:
      case ChallengeType.matching:
        final m = _selectedAnswer;
        if (m is Map<String, String>) {
          return ChallengeValidation.validateMatchingAnswer(
            userMatches: m,
            expectedPairs: s.matchingPairs,
          );
        }
        return false;
      case ChallengeType.orderEvents:
      case ChallengeType.orderEventsStyled:
      case ChallengeType.reorder:
      case ChallengeType.assemble:
      case ChallengeType.arrangeSentenceAlternative:
        final list = _selectedAnswer;
        if (list is List<String>) {
          if (s.correctOrder.isNotEmpty) {
            return ChallengeValidation.validateListOrderAnswer(
              userOrder: list,
              expectedOrder: s.correctOrder,
            );
          }
          // Fallback: join sentence and compare to `answer` if provided.
          final joined = list.join(' ').trim();
          return ChallengeValidation.validateStringAnswer(
            candidate: joined,
            expected: s.answer,
          );
        }
        return false;
      case ChallengeType.elimination:
      case ChallengeType.unknown:
        return false;
    }
  }

  Future<void> _onCheckAnswer() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });

    final ok = _validateCurrentAnswer();
    if (kDebugMode) {
      debugPrint(
        '[Challenge] type=${_stage.type.name} stage=$_stageIndex '
        'selected=$_selectedAnswer ok=$ok wrongAttempts=$_wrongAttempts '
        'hintEnabled=$_hintEnabled shownHintIndex=$_shownHintIndex',
      );
    }

    if (ok) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _lastCorrect = true;
        _feedback = l10n.challengeFeedbackCorrect;
      });
      // Brief feedback then advance.
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      setState(() => _busy = false);
      await _showResult(autoSolved: false, isFinalStage: _isLastStage);
      return;
    }

    // Wrong.
    final nextAttempts = _wrongAttempts + 1;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _lastCorrect = false;
      _wrongAttempts = nextAttempts;
      _feedback = l10n.challengeFeedbackTryAgain;
      _busy = false;
    });

    // Auto-solve at 5 wrong attempts.
    if (nextAttempts >= 5 && mounted) {
      if (kDebugMode) {
        debugPrint('[Challenge] autoSolve triggered stage=$_stageIndex');
      }
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _feedback = l10n.challengeFeedbackAutoSolved;
        _lastCorrect = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      await _showResult(autoSolved: true, isFinalStage: _isLastStage);
    }
  }

  void _onShowHint() {
    if (!_hintEnabled || _busy) return;
    final hints = _stage.hints;
    if (hints.isEmpty) return;

    // Consume hint based on the current unlock point.
    final next = (_wrongAttempts == 4 && hints.length >= 2) ? 1 : 0;
    setState(() => _shownHintIndex = next);
    if (kDebugMode) {
      debugPrint('[Challenge] showHint idx=$next stage=$_stageIndex');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resultKind != _ResultKind.none) {
      final l10n = AppLocalizations.of(context)!;
      final next = _nextDestination;
      final isFinal = _resultKind == _ResultKind.finalResult;
      final isLast = isFinal && (next?.isLastRegion == true);
      final title = _resultAutoSolved
          ? l10n.challengeResultPuzzleSolvedTitle
          : l10n.challengeResultCorrectTitle;
      final primaryLabel = isFinal
          ? (isLast ? l10n.challengeButtonFinish : l10n.challengeButtonNext)
          : l10n.challengeButtonNextStage;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.orange,
                  size: MapDesignTokens.iconHero * 0.75,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MapTextStyles.popupTitle,
            ),
            const SizedBox(height: 14),
            _ResultCard(
              title: l10n.challengeResultCorrectAnswerHeading,
              child: Text(
                _correctAnswerDisplay ?? '—',
                style: ChallengeStyles.bodyStyle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isFinal) ...[
              const SizedBox(height: 12),
              _ResultCard(
                title: isLast
                    ? l10n.challengeResultJourneyCompletedHeading
                    : l10n.challengeResultNextDestinationHeading,
                child: Text(
                  isLast
                      ? l10n.challengeResultJourneyCompletedBody
                      : (next?.name ?? l10n.challengeResultNotAvailable),
                  style: ChallengeStyles.bodyStyle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = <Widget>[];
                  if (!isLast) {
                    final dist = next?.distanceFromPreviousMeters;
                    final walk = next?.walkingTimeFromPreviousMinutes;
                    cards.add(
                      _MetricCard(
                        icon: Icons.route_rounded,
                        title: l10n.challengeResultDistanceNextTitle,
                        amount: dist,
                        unitLabel: 'm',
                      ),
                    );
                    cards.add(
                      _MetricCard(
                        icon: Icons.directions_walk_rounded,
                        title: l10n.challengeResultWalkTimeTitle,
                        amount: walk,
                        unitLabel: 'min',
                      ),
                    );
                  }
                  final twoCol = constraints.maxWidth >= 360;
                  if (cards.isEmpty) return const SizedBox.shrink();
                  if (twoCol && cards.length >= 2) {
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        cards[i],
                        if (i != cards.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 14),
            SafeArea(
              top: false,
              child: FilledButton(
                onPressed: () {
                  if (kDebugMode) {
                    debugPrint(
                      '[ChallengeResult] button pressed kind=${_resultKind.name} stageIndex=$_stageIndex '
                      'stageCount=${widget.challenge.stageCount} isFinalStage=$_isLastStage nextName=${next?.name ?? 'null'}',
                    );
                  }
                  if (!isFinal) {
                    _advanceStage();
                    return;
                  }
                  widget.onResultNext?.call();
                  widget.onChallengeResolved?.call(
                    success: true,
                    nextLandmarkDocumentId: widget.nextLandmarkDocumentId,
                  );
                },
                style: MapButtonStyles.primaryFilled(),
                child: Text(primaryLabel),
              ),
            ),
          ],
        ),
      );
    }

    final c = widget.challenge;
    final total = c.stageCount;
    final l10n = AppLocalizations.of(context)!;

    final hints = _stage.hints;
    final hintIdx = _shownHintIndex;
    final shownHint = (hintIdx >= 0 && hintIdx < hints.length)
        ? hints[hintIdx]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.challengeStageProgress(_stageIndex + 1, total),
              style: ChallengeStyles.bodyStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: ChallengeStyles.mutedBrown,
              ),
            ),
          ),
        // The challenge body must receive a bounded height (especially ordering challenges
        // that use ReorderableListView internally). Without this, Flutter can throw
        // "RenderBox was not laid out" and the overlay appears blank/laggy.
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey<String>(
                '${_stage.index}_${_stage.stageKey ?? 'direct'}',
              ),
              child: _buildForType(_stage),
            ),
          ),
        ),
        if (shownHint != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(MapDesignTokens.spaceMd),
            decoration: BoxDecoration(
              color: MapDesignTokens.popupBackground,
              borderRadius: BorderRadius.circular(MapDesignTokens.radiusChip),
              border: Border.all(color: MapDesignTokens.borderSubtle(0.12)),
            ),
            child: Text(
              shownHint,
              style: ChallengeStyles.bodyStyle.copyWith(
                color: ChallengeStyles.mutedBrown,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        if (_feedback != null) ...[
          const SizedBox(height: 10),
          Text(
            _feedback!,
            style: ChallengeStyles.bodyStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: _lastCorrect
                  ? MapDesignTokens.successColor
                  : AppColors.brown,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SafeArea(
          top: false,
          // Beige backing removes any stray visual separator/line in the button gutter.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
            child: ColoredBox(
              color: MapDesignTokens.popupBackground,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    if (_hasHints) ...[
                      Expanded(
                        child: _hintEnabled
                            ? FilledButton(
                                onPressed: _onShowHint,
                                style:
                                    MapButtonStyles.challengeFooterHintEnabled(),
                                child: Text(
                                  l10n.challengeShowHint,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : OutlinedButton(
                                onPressed: null,
                                style:
                                    MapButtonStyles.challengeFooterHintDisabled(),
                                child: Text(
                                  l10n.challengeShowHint,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                      ColoredBox(
                        color: MapDesignTokens.popupBackground,
                        child: SizedBox(
                          width: MapDesignTokens.spaceMd,
                          height: 1,
                        ),
                      ),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _onCheckAnswer,
                        style: MapButtonStyles.challengeFooterCheck(
                          enabled: !_busy,
                        ),
                        child: Text(
                          l10n.challengeCheckYourAnswer,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForType(ChallengeStageModel stage) {
    if (kDebugMode) {
      debugPrint(
        '[Challenge] render type=${stage.type.name} stageIndex=$_stageIndex '
        'parts=${stage.parts.length} options=${stage.options.length} pairs=${stage.matchingPairs.length} '
        'hints=${stage.hints.length}',
      );
    }
    switch (stage.type) {
      case ChallengeType.multipleChoice:
        return MultipleChoiceChallenge(
          stage: stage,
          selected: _selectedAnswer as String?,
          onChanged: (v) => setState(() => _selectedAnswer = v),
        );
      case ChallengeType.fillBlankWithChoices:
      case ChallengeType.fillBlank:
        return FillBlankWithChoicesChallenge(
          stage: stage,
          selected: _selectedAnswer as String?,
          onChanged: (v) => setState(() => _selectedAnswer = v),
        );
      case ChallengeType.fillBlankWithMultipleChoice:
        return FillBlankMultipleChoiceChallenge(
          stage: stage,
          selected: _selectedAnswer as String?,
          onChanged: (v) => setState(() => _selectedAnswer = v),
        );
      case ChallengeType.matchColumns:
      case ChallengeType.matching:
        return MatchColumnsChallenge(
          stage: stage,
          selectedMatches: (_selectedAnswer is Map<String, String>)
              ? Map<String, String>.from(_selectedAnswer as Map<String, String>)
              : const {},
          onChanged: (m) => setState(() => _selectedAnswer = m),
        );
      case ChallengeType.orderEvents:
      case ChallengeType.reorder:
        return OrderEventsChallenge(
          stage: stage,
          order: (_selectedAnswer is List<String>)
              ? List<String>.from(_selectedAnswer as List<String>)
              : null,
          onChanged: (o) => setState(() => _selectedAnswer = o),
        );
      case ChallengeType.orderEventsStyled:
        return StyledOrderEventsChallenge(
          stage: stage,
          order: (_selectedAnswer is List<String>)
              ? List<String>.from(_selectedAnswer as List<String>)
              : null,
          onChanged: (o) => setState(() => _selectedAnswer = o),
        );
      case ChallengeType.arrangeSentenceAlternative:
      case ChallengeType.assemble:
        return ArrangeSentenceAlternativeChallenge(
          stage: stage,
          selectedTokens: (_selectedAnswer is List<String>)
              ? List<String>.from(_selectedAnswer as List<String>)
              : const [],
          onChanged: (o) => setState(() => _selectedAnswer = o),
        );
      case ChallengeType.arrangeSentenceWithMultipleChoice:
        return ArrangeSentenceMultipleChoiceChallenge(
          stage: stage,
          selected: _selectedAnswer as String?,
          onChanged: (v) => setState(() => _selectedAnswer = v),
        );
      case ChallengeType.elimination:
      case ChallengeType.unknown:
        return UnknownChallengeWidget(stage: stage);
    }
  }
}

class ChallengeNextDestination {
  ChallengeNextDestination({
    required this.name,
    this.distanceFromPreviousMeters,
    this.walkingTimeFromPreviousMinutes,
    this.isLastRegion = false,
  });

  final String name;
  final double? distanceFromPreviousMeters;
  final double? walkingTimeFromPreviousMinutes;

  /// True when the user just finished the **final** map region’s challenge (no further regions).
  /// False when finishing e.g. region 8: next destination may still be region 9 with route metrics.
  final bool isLastRegion;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MapDesignTokens.cardOnBeige(0.62),
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
        border: Border.all(color: MapDesignTokens.borderSubtle(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: ChallengeStyles.bodyStyle.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brown.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

enum _ResultKind { none, stageResult, finalResult }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.amount,
    required this.unitLabel,
  });

  final IconData icon;
  final String title;

  /// From Firestore `distanceFromPreviousMeters` / `walkingTimeFromPreviousMinutes` (often double).
  final double? amount;

  /// Shown beside the number, e.g. `m` or `min`.
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final base = ChallengeStyles.bodyStyle;
    final Widget valueRow;
    if (!_usableLegAmount(amount)) {
      valueRow = Text(
        AppLocalizations.of(context)!.challengeResultNotAvailable,
        style: base.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.brown.withValues(alpha: 0.65),
        ),
      );
    } else {
      final n = _formatLegAmount(amount!);
      valueRow = Text.rich(
        TextSpan(
          style: base.copyWith(color: AppColors.brown),
          children: [
            TextSpan(
              text: n,
              style: base.copyWith(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            TextSpan(
              text: ' $unitLabel',
              style: base.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.brown.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MapDesignTokens.cardOnBeige(0.62),
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
        border: Border.all(color: MapDesignTokens.borderSubtle(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: MapDesignTokens.iconSmall, color: AppColors.brown),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: base.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brown.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 6),
                valueRow,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Optional outer card wrapper for embedding in sheets / routes.
class ChallengeScaffoldCard extends StatelessWidget {
  const ChallengeScaffoldCard({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.beige,
      elevation: 2,
      shape: ChallengeStyles.cardShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(title!, style: ChallengeStyles.titleStyle),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
