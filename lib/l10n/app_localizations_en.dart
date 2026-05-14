// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languagePickerTitle => 'App language';

  @override
  String get languagePickerSubtitle =>
      'Choose how buttons and journey screens are labeled.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get journeyListTitle => 'Active Journeys';

  @override
  String get journeyListSignInPrompt =>
      'Sign in to see journeys you have in progress. Your place is saved when you leave the map.';

  @override
  String get journeyListNoActive => 'No active journeys';

  @override
  String get journeyListNoActiveSubtitle =>
      'When you start a journey and step away, it will appear here so you can continue.';

  @override
  String journeyListCurrentStop(int currentRegion) {
    return 'Current stop: $currentRegion';
  }

  @override
  String get journeyPurchaseTitle => 'Journey';

  @override
  String get journeyPurchaseNotFound => 'Journey not found.';

  @override
  String get journeyPurchaseAbout => 'About';

  @override
  String get journeyPurchaseReadMore => 'read more';

  @override
  String get journeyPurchaseReadLess => 'read less';

  @override
  String get journeyPurchaseStartPoint => 'Start point';

  @override
  String get journeyPurchaseStopsAlongWay => 'Stops along the way';

  @override
  String get journeyPurchaseEndPoint => 'End point';

  @override
  String get journeyPurchaseGoodToKnow => 'Good to know';

  @override
  String get journeyPurchaseGoodToKnow1 =>
      'Best time to explore is after Fajr or after Asr';

  @override
  String get journeyPurchaseGoodToKnow2 =>
      'Avoid exploring during midday due to the heat';

  @override
  String get journeyPurchaseGoodToKnow3 =>
      'You can enjoy the journey by walking, cycling, or using a golf cart';

  @override
  String get journeyPurchaseSignInToPurchase => 'Sign in to purchase';

  @override
  String get journeyPurchaseLoading => 'Loading…';

  @override
  String get journeyPurchaseGiveFeedback => 'Give feedback';

  @override
  String get journeyPurchaseUnlockJourney => 'Unlock Journey';

  @override
  String get journeyPurchaseContinueYourJourney => 'Continue your journey';

  @override
  String get journeyPurchaseStartYourJourney => 'Start your journey';

  @override
  String get googleMapPageTitle => 'Google Map';

  @override
  String get googleMapPagePlaceholder => 'Google Map will be here';

  @override
  String get mapCouldNotOpenGoogleMaps => 'Could not open Google Maps.';

  @override
  String get mapCouldNotDetermineJourney =>
      'Could not determine this journey. Try again from the journey list.';

  @override
  String get mapFinishJourneyFeedback => 'Finish Journey & Leave Feedback';

  @override
  String get mapOpenGoogleMaps => 'Open in Google Maps';

  @override
  String get mapLoadingPlace => 'Loading place…';

  @override
  String get mapChallengeComingSoon => 'Challenge coming soon.';

  @override
  String get mapStartChallenge => 'Start Challenge';

  @override
  String get mapLandmarkDescriptionPlaceholder =>
      'Add a description for this landmark in Firestore (field: description).';

  @override
  String get mapImageFailedToLoad => 'Image failed to load';

  @override
  String get mapRegionNotReached => 'You haven\'t reached this stage yet';

  @override
  String get mapStageDone => 'This stage is done';

  @override
  String get mapJourneyCompleted => 'Journey completed!';

  @override
  String regionNumber(int region) {
    return 'Region $region';
  }

  @override
  String get recommendationListTitle => 'Recommended places';

  @override
  String get recommendationListEmptyTitle => 'No recommendations yet';

  @override
  String get recommendationListEmptySubtitle =>
      'Explore more landmarks to unlock nearby places.';

  @override
  String get recommendationNoDescription => 'No description yet.';

  @override
  String get recommendationChipAveragePrice => 'Average price';

  @override
  String get recommendationChipWalkTime => 'Walk time';

  @override
  String get recommendationChipDistanceFromLast => 'Distance from last stop';

  @override
  String get recommendationChipRating => 'Rating';

  @override
  String get recommendationPriceRanges => 'Price ranges';

  @override
  String get recommendationOpenInGoogleMaps => 'Open in Google Maps';

  @override
  String recommendationQuickDistanceLine(String detail) {
    return 'Distance · $detail';
  }

  @override
  String recommendationQuickWalkLine(String detail) {
    return 'Walk · $detail';
  }

  @override
  String get recommendationQuickRatingGoogleSuffix => ' Google';

  @override
  String get recommendationQuickDirections => 'Directions';

  @override
  String get recommendationQuickView => 'View';

  @override
  String get recommendationUrlNoLink =>
      'No location link is available for this place.';

  @override
  String get recommendationUrlInvalidLink => 'The location link is not valid.';

  @override
  String get recommendationUrlCouldNotOpen => 'Could not open maps / browser.';

  @override
  String get challengeFeedbackCorrect => 'Correct!';

  @override
  String get challengeFeedbackTryAgain => 'Not quite — try again.';

  @override
  String get challengeFeedbackAutoSolved => 'Auto-solved.';

  @override
  String get challengeResultPuzzleSolvedTitle => 'Puzzle solved for you';

  @override
  String get challengeResultCorrectTitle => 'Correct answer!';

  @override
  String get challengeResultCorrectAnswerHeading => 'Correct answer';

  @override
  String get challengeResultJourneyCompletedHeading =>
      'Your journey is completed';

  @override
  String get challengeResultNextDestinationHeading => 'Next destination';

  @override
  String get challengeResultJourneyCompletedBody =>
      'You have completed every landmark on this journey.';

  @override
  String get challengeResultNotAvailable => 'Not available';

  @override
  String get challengeResultDistanceNextTitle => 'Distance for next landmark:';

  @override
  String get challengeResultWalkTimeTitle => 'Average walking time';

  @override
  String get challengeButtonFinish => 'Finish';

  @override
  String get challengeButtonNext => 'Next';

  @override
  String get challengeButtonNextStage => 'Next Stage';

  @override
  String challengeStageProgress(int current, int total) {
    return 'Stage $current of $total';
  }

  @override
  String get challengeShowHint => 'Show Hint';

  @override
  String get challengeCheckYourAnswer => 'Check Your Answer';

  @override
  String get challengeHintsHeading => 'Hints';

  @override
  String get challengeUnknownTitle => 'Challenge';

  @override
  String challengeUnknownBody(String type) {
    return 'This challenge type could not be resolved ($type). Check Firestore `quiz` / `type` fields.';
  }

  @override
  String get challengeTypeMultipleChoiceTitle => 'Multiple choice';

  @override
  String get challengeTypeChooseCorrect => 'Choose the correct answer';

  @override
  String get challengeTypeFillBlankTitle => 'Fill in the blank';

  @override
  String get challengeTypeFillBlankPrompt => 'Fill the blank:';

  @override
  String get challengeFillBlankNoOptions => 'No options in this challenge.';

  @override
  String get challengeFillBlankNoChoices => 'No choices in this challenge.';

  @override
  String get challengeCheckAnswer => 'Check answer';

  @override
  String challengeHintNumber(int n) {
    return 'Hint $n';
  }

  @override
  String get challengeTypeMatchingTitle => 'Matching';

  @override
  String get challengeMatchHint => 'Match';

  @override
  String get challengeCheckMatches => 'Check matches';

  @override
  String get challengeMatchingDataMissing =>
      'Matching data missing in this challenge.';

  @override
  String get challengeMatchThePairs => 'Match the pairs';

  @override
  String get challengeGroupA => 'Group A';

  @override
  String get challengeGroupB => 'Group B';

  @override
  String get challengeSelectedLabel => 'Selected:';

  @override
  String get challengeTypeReorderTitle => 'Reorder';

  @override
  String get challengeCheckOrder => 'Check order';

  @override
  String get challengeTypeEliminationTitle => 'Elimination';

  @override
  String get challengeCheck => 'Check';

  @override
  String get challengeReset => 'Reset';

  @override
  String get challengeTypeAssembleTitle => 'Assemble';

  @override
  String get challengeCheckAssembly => 'Check assembly';

  @override
  String get challengeYourAnswer => 'Your answer';

  @override
  String get challengeWordBank => 'Word bank';

  @override
  String get challengeOrderTheEvents => 'Order the events';

  @override
  String get challengeMatchingNoPairsInData => 'No matching pairs in data.';

  @override
  String get challengeEliminationTapHint => 'Tap an item to remove it from the list.';

  @override
  String get journeyPurchasePayWithMoyasar => 'Pay with Moyasar';
}
