import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languagePickerTitle;

  /// No description provided for @languagePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how buttons and journey screens are labeled.'**
  String get languagePickerSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

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
  String get challengeMatchingNoPairsInData;

  /// No description provided for @challengeEliminationTapHint.
  String get challengeEliminationTapHint;

  /// No description provided for @journeyPurchasePayWithMoyasar.
  ///
  /// In en, this message translates to:
  /// **'Pay with Moyasar'**
  String get journeyPurchasePayWithMoyasar;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
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
