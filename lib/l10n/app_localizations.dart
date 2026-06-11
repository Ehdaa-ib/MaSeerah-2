import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @journeyListTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Journeys'**
  String get journeyListTitle;

  /// No description provided for @journeyListSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see journeys you have in progress. Your place is saved when you leave the map.'**
  String get journeyListSignInPrompt;

  /// No description provided for @journeyListNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active journeys'**
  String get journeyListNoActive;

  /// No description provided for @journeyListNoActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you start a journey and step away, it will appear here so you can continue.'**
  String get journeyListNoActiveSubtitle;

  /// No description provided for @journeyListCurrentStop.
  ///
  /// In en, this message translates to:
  /// **'Current stop: {currentRegion}'**
  String journeyListCurrentStop(int currentRegion);

  /// No description provided for @journeyPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get journeyPurchaseTitle;

  /// No description provided for @journeyPurchaseNotFound.
  ///
  /// In en, this message translates to:
  /// **'Journey not found.'**
  String get journeyPurchaseNotFound;

  /// No description provided for @journeyPurchaseAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get journeyPurchaseAbout;

  /// No description provided for @journeyPurchaseReadMore.
  ///
  /// In en, this message translates to:
  /// **'read more'**
  String get journeyPurchaseReadMore;

  /// No description provided for @journeyPurchaseReadLess.
  ///
  /// In en, this message translates to:
  /// **'read less'**
  String get journeyPurchaseReadLess;

  /// No description provided for @journeyPurchaseStartPoint.
  ///
  /// In en, this message translates to:
  /// **'Start point'**
  String get journeyPurchaseStartPoint;

  /// No description provided for @journeyPurchaseStopsAlongWay.
  ///
  /// In en, this message translates to:
  /// **'Stops along the way'**
  String get journeyPurchaseStopsAlongWay;

  /// No description provided for @journeyPurchaseEndPoint.
  ///
  /// In en, this message translates to:
  /// **'End point'**
  String get journeyPurchaseEndPoint;

  /// No description provided for @journeyPurchaseGoodToKnow.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get journeyPurchaseGoodToKnow;

  /// No description provided for @journeyPurchaseGoodToKnow1.
  ///
  /// In en, this message translates to:
  /// **'Best time to explore is after Fajr or after Asr'**
  String get journeyPurchaseGoodToKnow1;

  /// No description provided for @journeyPurchaseGoodToKnow2.
  ///
  /// In en, this message translates to:
  /// **'Avoid exploring during midday due to the heat'**
  String get journeyPurchaseGoodToKnow2;

  /// No description provided for @journeyPurchaseGoodToKnow3.
  ///
  /// In en, this message translates to:
  /// **'You can enjoy the journey by walking, cycling, or using a golf cart'**
  String get journeyPurchaseGoodToKnow3;

  /// No description provided for @journeyPurchaseSignInToPurchase.
  ///
  /// In en, this message translates to:
  /// **'Sign in to purchase'**
  String get journeyPurchaseSignInToPurchase;

  /// No description provided for @journeyPurchaseLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get journeyPurchaseLoading;

  /// No description provided for @journeyPurchaseGiveFeedback.
  ///
  /// In en, this message translates to:
  /// **'Give feedback'**
  String get journeyPurchaseGiveFeedback;

  /// No description provided for @journeyPurchaseUnlockJourney.
  ///
  /// In en, this message translates to:
  /// **'Unlock Journey'**
  String get journeyPurchaseUnlockJourney;

  /// No description provided for @journeyPurchasePurchaseJourney.
  ///
  /// In en, this message translates to:
  /// **'Purchase journey'**
  String get journeyPurchasePurchaseJourney;

  /// No description provided for @journeyPurchaseViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View in journey history'**
  String get journeyPurchaseViewHistory;

  /// No description provided for @journeyPurchaseContinueYourJourney.
  ///
  /// In en, this message translates to:
  /// **'Continue your journey'**
  String get journeyPurchaseContinueYourJourney;

  /// No description provided for @journeyPurchaseStartYourJourney.
  ///
  /// In en, this message translates to:
  /// **'Start your journey'**
  String get journeyPurchaseStartYourJourney;

  /// No description provided for @comingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoonTitle;

  /// No description provided for @comingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'This journey is not available yet. We are preparing new stories and landmarks for you — check back soon.'**
  String get comingSoonBody;

  /// No description provided for @comingSoonBack.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get comingSoonBack;

  /// No description provided for @comingSoonBadge.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoonBadge;

  /// No description provided for @googleMapPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Map'**
  String get googleMapPageTitle;

  /// No description provided for @googleMapPagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Google Map will be here'**
  String get googleMapPagePlaceholder;

  /// No description provided for @mapCouldNotOpenGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open Google Maps.'**
  String get mapCouldNotOpenGoogleMaps;

  /// No description provided for @mapCouldNotDetermineJourney.
  ///
  /// In en, this message translates to:
  /// **'Could not determine this journey. Try again from the journey list.'**
  String get mapCouldNotDetermineJourney;

  /// No description provided for @mapFinishJourneyFeedback.
  ///
  /// In en, this message translates to:
  /// **'Finish Journey & Leave Feedback'**
  String get mapFinishJourneyFeedback;

  /// No description provided for @mapOpenGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get mapOpenGoogleMaps;

  /// No description provided for @mapLoadingPlace.
  ///
  /// In en, this message translates to:
  /// **'Loading place…'**
  String get mapLoadingPlace;

  /// No description provided for @mapChallengeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Challenge coming soon.'**
  String get mapChallengeComingSoon;

  /// No description provided for @mapStartChallenge.
  ///
  /// In en, this message translates to:
  /// **'Start Challenge'**
  String get mapStartChallenge;

  /// No description provided for @mapLandmarkDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a description for this landmark in Firestore (field: description).'**
  String get mapLandmarkDescriptionPlaceholder;

  /// No description provided for @mapImageFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get mapImageFailedToLoad;

  /// No description provided for @mapRegionNotReached.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t reached this stage yet'**
  String get mapRegionNotReached;

  /// No description provided for @mapStageDone.
  ///
  /// In en, this message translates to:
  /// **'This stage is done'**
  String get mapStageDone;

  /// No description provided for @mapJourneyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Journey completed!'**
  String get mapJourneyCompleted;

  /// No description provided for @regionNumber.
  ///
  /// In en, this message translates to:
  /// **'Region {region}'**
  String regionNumber(int region);

  /// No description provided for @recommendationListTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended places'**
  String get recommendationListTitle;

  /// No description provided for @recommendationListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recommendations yet'**
  String get recommendationListEmptyTitle;

  /// No description provided for @recommendationListEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore more landmarks to unlock nearby places.'**
  String get recommendationListEmptySubtitle;

  /// No description provided for @recommendationNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description yet.'**
  String get recommendationNoDescription;

  /// No description provided for @recommendationChipAveragePrice.
  ///
  /// In en, this message translates to:
  /// **'Average price'**
  String get recommendationChipAveragePrice;

  /// No description provided for @recommendationChipWalkTime.
  ///
  /// In en, this message translates to:
  /// **'Walk time'**
  String get recommendationChipWalkTime;

  /// No description provided for @recommendationChipDistanceFromLast.
  ///
  /// In en, this message translates to:
  /// **'Distance from last stop'**
  String get recommendationChipDistanceFromLast;

  /// No description provided for @recommendationChipRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get recommendationChipRating;

  /// No description provided for @recommendationPriceRanges.
  ///
  /// In en, this message translates to:
  /// **'Price ranges'**
  String get recommendationPriceRanges;

  /// No description provided for @recommendationOpenInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get recommendationOpenInGoogleMaps;

  /// No description provided for @recommendationQuickDistanceLine.
  ///
  /// In en, this message translates to:
  /// **'Distance · {detail}'**
  String recommendationQuickDistanceLine(String detail);

  /// No description provided for @recommendationQuickWalkLine.
  ///
  /// In en, this message translates to:
  /// **'Walk · {detail}'**
  String recommendationQuickWalkLine(String detail);

  /// No description provided for @recommendationQuickRatingGoogleSuffix.
  ///
  /// In en, this message translates to:
  /// **' Google'**
  String get recommendationQuickRatingGoogleSuffix;

  /// No description provided for @recommendationQuickDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get recommendationQuickDirections;

  /// No description provided for @recommendationQuickView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get recommendationQuickView;

  /// No description provided for @recommendationUrlNoLink.
  ///
  /// In en, this message translates to:
  /// **'No location link is available for this place.'**
  String get recommendationUrlNoLink;

  /// No description provided for @recommendationUrlInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'The location link is not valid.'**
  String get recommendationUrlInvalidLink;

  /// No description provided for @recommendationUrlCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps / browser.'**
  String get recommendationUrlCouldNotOpen;

  /// No description provided for @challengeFeedbackCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get challengeFeedbackCorrect;

  /// No description provided for @challengeFeedbackTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Not quite — try again.'**
  String get challengeFeedbackTryAgain;

  /// No description provided for @challengeFeedbackAutoSolved.
  ///
  /// In en, this message translates to:
  /// **'Auto-solved.'**
  String get challengeFeedbackAutoSolved;

  /// No description provided for @challengeResultPuzzleSolvedTitle.
  ///
  /// In en, this message translates to:
  /// **'Puzzle solved for you'**
  String get challengeResultPuzzleSolvedTitle;

  /// No description provided for @challengeResultCorrectTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct answer!'**
  String get challengeResultCorrectTitle;

  /// No description provided for @challengeResultCorrectAnswerHeading.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get challengeResultCorrectAnswerHeading;

  /// No description provided for @challengeResultJourneyCompletedHeading.
  ///
  /// In en, this message translates to:
  /// **'Your journey is completed'**
  String get challengeResultJourneyCompletedHeading;

  /// No description provided for @challengeResultNextDestinationHeading.
  ///
  /// In en, this message translates to:
  /// **'Next destination'**
  String get challengeResultNextDestinationHeading;

  /// No description provided for @challengeResultJourneyCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'You have completed every landmark on this journey.'**
  String get challengeResultJourneyCompletedBody;

  /// No description provided for @challengeResultNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get challengeResultNotAvailable;

  /// No description provided for @challengeResultDistanceNextTitle.
  ///
  /// In en, this message translates to:
  /// **'Distance for next landmark:'**
  String get challengeResultDistanceNextTitle;

  /// No description provided for @challengeResultWalkTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Average walking time'**
  String get challengeResultWalkTimeTitle;

  /// No description provided for @challengeButtonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get challengeButtonFinish;

  /// No description provided for @challengeButtonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get challengeButtonNext;

  /// No description provided for @challengeButtonNextStage.
  ///
  /// In en, this message translates to:
  /// **'Next Stage'**
  String get challengeButtonNextStage;

  /// No description provided for @challengeStageProgress.
  ///
  /// In en, this message translates to:
  /// **'Stage {current} of {total}'**
  String challengeStageProgress(int current, int total);

  /// No description provided for @challengeShowHint.
  ///
  /// In en, this message translates to:
  /// **'Show Hint'**
  String get challengeShowHint;

  /// No description provided for @challengeCheckYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check Your Answer'**
  String get challengeCheckYourAnswer;

  /// No description provided for @challengeHintsHeading.
  ///
  /// In en, this message translates to:
  /// **'Hints'**
  String get challengeHintsHeading;

  /// No description provided for @challengeUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get challengeUnknownTitle;

  /// No description provided for @challengeUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'This challenge type could not be resolved ({type}). Check Firestore `quiz` / `type` fields.'**
  String challengeUnknownBody(String type);

  /// No description provided for @challengeTypeMultipleChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get challengeTypeMultipleChoiceTitle;

  /// No description provided for @challengeTypeChooseCorrect.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct answer'**
  String get challengeTypeChooseCorrect;

  /// No description provided for @challengeTypeFillBlankTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in the blank'**
  String get challengeTypeFillBlankTitle;

  /// No description provided for @challengeTypeFillBlankPrompt.
  ///
  /// In en, this message translates to:
  /// **'Fill the blank:'**
  String get challengeTypeFillBlankPrompt;

  /// No description provided for @challengeFillBlankNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options in this challenge.'**
  String get challengeFillBlankNoOptions;

  /// No description provided for @challengeFillBlankNoChoices.
  ///
  /// In en, this message translates to:
  /// **'No choices in this challenge.'**
  String get challengeFillBlankNoChoices;

  /// No description provided for @challengeCheckAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get challengeCheckAnswer;

  /// No description provided for @challengeHintNumber.
  ///
  /// In en, this message translates to:
  /// **'Hint {n}'**
  String challengeHintNumber(int n);

  /// No description provided for @challengeTypeMatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get challengeTypeMatchingTitle;

  /// No description provided for @challengeMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get challengeMatchHint;

  /// No description provided for @challengeCheckMatches.
  ///
  /// In en, this message translates to:
  /// **'Check matches'**
  String get challengeCheckMatches;

  /// No description provided for @challengeMatchingDataMissing.
  ///
  /// In en, this message translates to:
  /// **'Matching data missing in this challenge.'**
  String get challengeMatchingDataMissing;

  /// No description provided for @challengeMatchThePairs.
  ///
  /// In en, this message translates to:
  /// **'Match the pairs'**
  String get challengeMatchThePairs;

  /// No description provided for @challengeGroupA.
  ///
  /// In en, this message translates to:
  /// **'Group A'**
  String get challengeGroupA;

  /// No description provided for @challengeGroupB.
  ///
  /// In en, this message translates to:
  /// **'Group B'**
  String get challengeGroupB;

  /// No description provided for @challengeSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected:'**
  String get challengeSelectedLabel;

  /// No description provided for @challengeTypeReorderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get challengeTypeReorderTitle;

  /// No description provided for @challengeCheckOrder.
  ///
  /// In en, this message translates to:
  /// **'Check order'**
  String get challengeCheckOrder;

  /// No description provided for @challengeTypeEliminationTitle.
  ///
  /// In en, this message translates to:
  /// **'Elimination'**
  String get challengeTypeEliminationTitle;

  /// No description provided for @challengeCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get challengeCheck;

  /// No description provided for @challengeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get challengeReset;

  /// No description provided for @challengeTypeAssembleTitle.
  ///
  /// In en, this message translates to:
  /// **'Assemble'**
  String get challengeTypeAssembleTitle;

  /// No description provided for @challengeCheckAssembly.
  ///
  /// In en, this message translates to:
  /// **'Check assembly'**
  String get challengeCheckAssembly;

  /// No description provided for @challengeYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get challengeYourAnswer;

  /// No description provided for @challengeWordBank.
  ///
  /// In en, this message translates to:
  /// **'Word bank'**
  String get challengeWordBank;

  /// No description provided for @challengeOrderTheEvents.
  ///
  /// In en, this message translates to:
  /// **'Order the events'**
  String get challengeOrderTheEvents;

  /// No description provided for @challengeMatchingNoPairsInData.
  ///
  /// In en, this message translates to:
  /// **'No matching pairs in data.'**
  String get challengeMatchingNoPairsInData;

  /// No description provided for @challengeEliminationTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an item to remove it from the list.'**
  String get challengeEliminationTapHint;

  /// No description provided for @journeyPurchaseHowToPlayInfo.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get journeyPurchaseHowToPlayInfo;

  /// No description provided for @howToPlayAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlayAppBarTitle;

  /// No description provided for @howToPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Before You Begin'**
  String get howToPlayTitle;

  /// No description provided for @howToPlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your journey is an interactive exploration. Walk, discover, solve, and unlock each landmark step by step.'**
  String get howToPlaySubtitle;

  /// No description provided for @howToPlayStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Start from the Map'**
  String get howToPlayStep1Title;

  /// No description provided for @howToPlayStep1Body.
  ///
  /// In en, this message translates to:
  /// **'Your journey begins on the map. The current landmark will be highlighted, and locked landmarks will open as you progress.'**
  String get howToPlayStep1Body;

  /// No description provided for @howToPlayStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Go to the Landmark'**
  String get howToPlayStep2Title;

  /// No description provided for @howToPlayStep2Body.
  ///
  /// In en, this message translates to:
  /// **'Use the map guidance to reach the selected landmark. When you arrive, the app will detect your location and unlock the landmark experience.'**
  String get howToPlayStep2Body;

  /// No description provided for @howToPlayStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Explore the Story'**
  String get howToPlayStep3Title;

  /// No description provided for @howToPlayStep3Body.
  ///
  /// In en, this message translates to:
  /// **'Read or listen to the landmark story carefully. The content will help you understand the place and prepare for the next step.'**
  String get howToPlayStep3Body;

  /// No description provided for @howToPlayStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Save Your Memory'**
  String get howToPlayStep4Title;

  /// No description provided for @howToPlayStep4Body.
  ///
  /// In en, this message translates to:
  /// **'At each landmark you visit, add a photo to save your personal memory before you continue.'**
  String get howToPlayStep4Body;

  /// No description provided for @howToPlayStep5Title.
  ///
  /// In en, this message translates to:
  /// **'Solve the Challenge'**
  String get howToPlayStep5Title;

  /// No description provided for @howToPlayStep5Body.
  ///
  /// In en, this message translates to:
  /// **'After exploring the landmark, complete a short challenge. The challenge also gives you a clue that guides you toward the next landmark.'**
  String get howToPlayStep5Body;

  /// No description provided for @howToPlayStep6Title.
  ///
  /// In en, this message translates to:
  /// **'Complete the Journey'**
  String get howToPlayStep6Title;

  /// No description provided for @howToPlayStep6Body.
  ///
  /// In en, this message translates to:
  /// **'Each completed landmark colors part of your journey map. When you finish all landmarks, your uploaded memories can be collected into a digital album.'**
  String get howToPlayStep6Body;

  /// No description provided for @howToPlayRecommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover nearby recommendations'**
  String get howToPlayRecommendationsTitle;

  /// No description provided for @howToPlayRecommendationsBody.
  ///
  /// In en, this message translates to:
  /// **'As you progress through the journey, curated local spots may appear on the map. Tap a card for a quick preview, use View or Directions for more, or open the full list anytime from the tip icon in the corner.'**
  String get howToPlayRecommendationsBody;

  /// No description provided for @howToPlayInactivityTitle.
  ///
  /// In en, this message translates to:
  /// **'72-hour activity window'**
  String get howToPlayInactivityTitle;

  /// No description provided for @howToPlayInactivityBody.
  ///
  /// In en, this message translates to:
  /// **'Your in-progress journey stays available while you explore. If you do not open the map or advance for 72 hours, the journey ends automatically. You can start again from the journey page when you are ready.'**
  String get howToPlayInactivityBody;

  /// No description provided for @howToPlayTipFooter.
  ///
  /// In en, this message translates to:
  /// **'Tip: Stay near the landmark while completing its experience so your progress is saved correctly.'**
  String get howToPlayTipFooter;

  /// No description provided for @journeyTerminatedInactivity.
  ///
  /// In en, this message translates to:
  /// **'This journey ended after 72 hours of inactivity. You can start again when you are ready.'**
  String get journeyTerminatedInactivity;

  /// No description provided for @howToPlayStartJourney.
  ///
  /// In en, this message translates to:
  /// **'Start Journey'**
  String get howToPlayStartJourney;

  /// No description provided for @howToPlayBackToJourney.
  ///
  /// In en, this message translates to:
  /// **'Back to Journey'**
  String get howToPlayBackToJourney;

  /// No description provided for @howToPlaySaveHintFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not save your preference just now, but you can still continue. You may see these tips again later.'**
  String get howToPlaySaveHintFailed;

  /// No description provided for @memoryUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture This Moment'**
  String get memoryUploadTitle;

  /// No description provided for @memoryUploadNote.
  ///
  /// In en, this message translates to:
  /// **'Add a photo at this landmark to save your memory, or skip to continue. Use your camera or choose one from your gallery.'**
  String get memoryUploadNote;

  /// No description provided for @memoryUploadPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Please add a photo for this landmark before continuing.'**
  String get memoryUploadPhotoRequired;

  /// No description provided for @memoryUploadSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your landmark photo.'**
  String get memoryUploadSignInRequired;

  /// No description provided for @memoryUploadTakeOrUpload.
  ///
  /// In en, this message translates to:
  /// **'Take Photo or Upload'**
  String get memoryUploadTakeOrUpload;

  /// No description provided for @memoryUploadGalleryOrCamera.
  ///
  /// In en, this message translates to:
  /// **'Gallery or Camera'**
  String get memoryUploadGalleryOrCamera;

  /// No description provided for @memoryUploadAddMemory.
  ///
  /// In en, this message translates to:
  /// **'Add Memory'**
  String get memoryUploadAddMemory;

  /// No description provided for @memoryUploadSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get memoryUploadSkipForNow;

  /// No description provided for @memoryUploadSkipHint.
  ///
  /// In en, this message translates to:
  /// **'You can skip this step and continue to the challenge.'**
  String get memoryUploadSkipHint;

  /// No description provided for @memoryUploadContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get memoryUploadContinue;

  /// No description provided for @memoryUploadTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get memoryUploadTakePhoto;

  /// No description provided for @memoryUploadFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Upload from Gallery'**
  String get memoryUploadFromGallery;

  /// No description provided for @memoryUploadVideoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Video from Gallery'**
  String get memoryUploadVideoFromGallery;

  /// No description provided for @memoryUploadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get memoryUploadCancel;

  /// No description provided for @memoryUploadNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get memoryUploadNext;

  /// No description provided for @memoryUploadRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get memoryUploadRetake;

  /// No description provided for @memoryUploadUploadAgain.
  ///
  /// In en, this message translates to:
  /// **'Upload Again'**
  String get memoryUploadUploadAgain;

  /// No description provided for @memoryUploadSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the memory. You can try again or continue.'**
  String get memoryUploadSaveFailed;

  /// No description provided for @memoryUploadPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open camera or gallery.'**
  String get memoryUploadPickFailed;

  /// No description provided for @memoryUploadVideoSelected.
  ///
  /// In en, this message translates to:
  /// **'Video selected'**
  String get memoryUploadVideoSelected;

  /// No description provided for @journeyHistoryMemoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No memories saved for this journey yet.'**
  String get journeyHistoryMemoriesEmpty;

  /// No description provided for @journeyPurchasePayWithMoyasar.
  ///
  /// In en, this message translates to:
  /// **'Pay with Moyasar'**
  String get journeyPurchasePayWithMoyasar;

  /// No description provided for @journeySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Journey summary'**
  String get journeySummaryTitle;

  /// No description provided for @journeyDetailPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos from this journey'**
  String get journeyDetailPhotosTitle;

  /// No description provided for @journeyDetailFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Your feedback'**
  String get journeyDetailFeedbackTitle;

  /// No description provided for @journeyDetailNoFeedback.
  ///
  /// In en, this message translates to:
  /// **'No feedback submitted for this journey.'**
  String get journeyDetailNoFeedback;

  /// No description provided for @journeyDetailFeedbackCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Your comment'**
  String get journeyDetailFeedbackCommentLabel;

  /// No description provided for @journeyDetailFeedbackNoComment.
  ///
  /// In en, this message translates to:
  /// **'No written comment.'**
  String get journeyDetailFeedbackNoComment;

  /// No description provided for @journeyDetailFeedbackAdminReply.
  ///
  /// In en, this message translates to:
  /// **'Response from MaSeerah'**
  String get journeyDetailFeedbackAdminReply;

  /// No description provided for @journeyDetailFeedbackOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall experience'**
  String get journeyDetailFeedbackOverall;

  /// No description provided for @journeyDetailFeedbackContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get journeyDetailFeedbackContent;

  /// No description provided for @journeyDetailFeedbackRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get journeyDetailFeedbackRecommendations;

  /// No description provided for @journeyDetailFeedbackChallenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get journeyDetailFeedbackChallenges;

  /// No description provided for @journeyDetailFeedbackPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos you shared with feedback'**
  String get journeyDetailFeedbackPhotos;

  /// No description provided for @journeyDetailEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos or feedback for this journey yet.'**
  String get journeyDetailEmpty;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileHello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String profileHello(String name);

  /// No description provided for @profileJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String profileJoined(String date);

  /// No description provided for @profileMyJourneys.
  ///
  /// In en, this message translates to:
  /// **'My Journeys'**
  String get profileMyJourneys;

  /// No description provided for @profileMyFeedbacks.
  ///
  /// In en, this message translates to:
  /// **'My Feedbacks'**
  String get profileMyFeedbacks;

  /// No description provided for @profileMyPhotos.
  ///
  /// In en, this message translates to:
  /// **'My Photos'**
  String get profileMyPhotos;

  /// No description provided for @profileShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get profileShowAll;

  /// No description provided for @profileNoJourneysYet.
  ///
  /// In en, this message translates to:
  /// **'No journeys yet'**
  String get profileNoJourneysYet;

  /// No description provided for @profileNoFeedbackYet.
  ///
  /// In en, this message translates to:
  /// **'No feedback yet'**
  String get profileNoFeedbackYet;

  /// No description provided for @profileNoPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get profileNoPhotosYet;

  /// No description provided for @profileStatJourneys.
  ///
  /// In en, this message translates to:
  /// **'JOURNEYS'**
  String get profileStatJourneys;

  /// No description provided for @profileStatPhotos.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS'**
  String get profileStatPhotos;

  /// No description provided for @profileJoinedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get profileJoinedUnknown;

  /// No description provided for @profileUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileUserFallback;

  /// No description provided for @profileFeedbackGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get profileFeedbackGeneral;

  /// No description provided for @profileJourneyFallback.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get profileJourneyFallback;

  /// No description provided for @profileJourneyNumber.
  ///
  /// In en, this message translates to:
  /// **'Journey {number}'**
  String profileJourneyNumber(String number);

  /// No description provided for @profileRelativeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get profileRelativeToday;

  /// No description provided for @profileRelativeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get profileRelativeYesterday;

  /// No description provided for @profileRelativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String profileRelativeDaysAgo(int days);

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditProfile;

  /// No description provided for @profileFaqs.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get profileFaqs;

  /// No description provided for @profileContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get profileContactUs;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @editProfilePhotosGallery.
  ///
  /// In en, this message translates to:
  /// **'Photos & gallery'**
  String get editProfilePhotosGallery;

  /// No description provided for @editProfileTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get editProfileTakePhoto;

  /// No description provided for @editProfileDateFuture.
  ///
  /// In en, this message translates to:
  /// **'Date of birth cannot be in the future.'**
  String get editProfileDateFuture;

  /// No description provided for @editProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get editProfileSaved;

  /// No description provided for @editProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile. Please try again.'**
  String get editProfileSaveFailed;

  /// No description provided for @editProfileRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get editProfileRetry;

  /// No description provided for @editProfilePick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get editProfilePick;

  /// No description provided for @editProfileClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get editProfileClear;

  /// No description provided for @feedbackTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get feedbackTakePhoto;

  /// No description provided for @feedbackChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get feedbackChooseGallery;

  /// No description provided for @feedbackCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get feedbackCancel;

  /// No description provided for @feedbackThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get feedbackThankYou;

  /// No description provided for @faqsTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get faqsTitle;

  /// No description provided for @faqsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get faqsTryAgain;

  /// No description provided for @couldNotOpenEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not open email app.'**
  String get couldNotOpenEmail;

  /// No description provided for @verifyCodeResent.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent to your email.'**
  String get verifyCodeResent;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get errorNoInternet;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errorInvalidEmail;

  /// No description provided for @errorUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errorUserDisabled;

  /// No description provided for @errorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get errorUserNotFound;

  /// No description provided for @errorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get errorWrongPassword;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get errorEmailInUse;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please use at least 6 characters.'**
  String get errorWeakPassword;

  /// No description provided for @errorInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get errorInvalidCredential;

  /// No description provided for @errorInvalidVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code.'**
  String get errorInvalidVerificationCode;

  /// No description provided for @errorInvalidVerificationId.
  ///
  /// In en, this message translates to:
  /// **'Verification link expired. Please try again.'**
  String get errorInvalidVerificationId;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get errorTooManyRequests;

  /// No description provided for @errorOperationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not enabled.'**
  String get errorOperationNotAllowed;

  /// No description provided for @errorRequiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get errorRequiresRecentLogin;

  /// No description provided for @landingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search journeys…'**
  String get landingSearchHint;

  /// No description provided for @landingSearchExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore your next journey'**
  String get landingSearchExplore;

  /// No description provided for @landingCardDarbTitle.
  ///
  /// In en, this message translates to:
  /// **'Darb Al-Sunnah'**
  String get landingCardDarbTitle;

  /// No description provided for @landingCardUhudTitle.
  ///
  /// In en, this message translates to:
  /// **'Uhud Battle'**
  String get landingCardUhudTitle;

  /// No description provided for @landingCardValleyTitle.
  ///
  /// In en, this message translates to:
  /// **'The Valley Adventure'**
  String get landingCardValleyTitle;

  /// No description provided for @landingCardDuration3h.
  ///
  /// In en, this message translates to:
  /// **'3 Hours'**
  String get landingCardDuration3h;

  /// No description provided for @landingCardDuration2h.
  ///
  /// In en, this message translates to:
  /// **'2 Hours'**
  String get landingCardDuration2h;

  /// No description provided for @landingCardDuration1_5h.
  ///
  /// In en, this message translates to:
  /// **'1.5 Hours'**
  String get landingCardDuration1_5h;

  /// No description provided for @landingCardStops8.
  ///
  /// In en, this message translates to:
  /// **'8 Stops'**
  String get landingCardStops8;

  /// No description provided for @landingCardStops5.
  ///
  /// In en, this message translates to:
  /// **'5 Stops'**
  String get landingCardStops5;

  /// No description provided for @landingCardStops3.
  ///
  /// In en, this message translates to:
  /// **'3 Stops'**
  String get landingCardStops3;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navActiveJourneys.
  ///
  /// In en, this message translates to:
  /// **'Active Journeys'**
  String get navActiveJourneys;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @mediaShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get mediaShare;

  /// No description provided for @mediaSaveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get mediaSaveToDevice;

  /// No description provided for @mediaSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo saved to your gallery'**
  String get mediaSavedToGallery;

  /// No description provided for @mediaSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save photo. Please try again.'**
  String get mediaSaveFailed;

  /// No description provided for @mediaShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share photo. Please try again.'**
  String get mediaShareFailed;

  /// No description provided for @mediaPhotoPreview.
  ///
  /// In en, this message translates to:
  /// **'Photo preview'**
  String get mediaPhotoPreview;

  /// No description provided for @mediaMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get mediaMoreActions;

  /// No description provided for @mediaPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get mediaPreview;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
