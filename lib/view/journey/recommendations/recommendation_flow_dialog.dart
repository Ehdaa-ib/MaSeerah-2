import 'package:flutter/material.dart';

import '../../../model/recommendation_place.dart';
import '../widgets/map_overlay_sheet_size.dart';
import 'recommendation_details_modal.dart';
import 'recommendation_list_popup.dart';

/// Single dialog: list ↔ details with back; same outer size as other map sheets.
class RecommendationFlowDialog extends StatefulWidget {
  const RecommendationFlowDialog({super.key, required this.places});

  final List<RecommendationPlace> places;

  @override
  State<RecommendationFlowDialog> createState() =>
      _RecommendationFlowDialogState();
}

class _RecommendationFlowDialogState extends State<RecommendationFlowDialog> {
  RecommendationPlace? _detail;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: MapOverlaySheetSize.dialogInset(context),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: MapOverlaySheetSize.constraints(context),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _detail == null
              ? SizedBox.expand(
                  key: const ValueKey('list'),
                  child: RecommendationListPopup(
                    places: widget.places,
                    onPickPlace: (p) => setState(() => _detail = p),
                  ),
                )
              : RecommendationDetailsModal(
                  key: ValueKey('detail_${_detail!.id}'),
                  place: _detail!,
                  onBack: () => setState(() => _detail = null),
                  wrapInDialog: false,
                ),
        ),
      ),
    );
  }
}
