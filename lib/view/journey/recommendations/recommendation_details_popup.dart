import 'package:flutter/material.dart';

import '../../../model/recommendation_place.dart';
import 'recommendation_details_modal.dart';

/// Backward-compatible name; opens [RecommendationDetailsModal].
class RecommendationDetailsPopup extends StatelessWidget {
  const RecommendationDetailsPopup({super.key, required this.place});

  final RecommendationPlace place;

  @override
  Widget build(BuildContext context) =>
      RecommendationDetailsModal(place: place);
}
