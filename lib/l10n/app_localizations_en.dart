// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get journeyPurchasePurchaseJourney => 'Purchase journey';

  @override
  String get journeyPurchaseViewHistory => 'View in journey history';

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
  String get challengeEliminationTapHint =>
      'Tap an item to remove it from the list.';

  @override
  String get journeyPurchaseHowToPlayInfo => 'How to play';

  @override
  String get howToPlayAppBarTitle => 'How to play';

  @override
  String get howToPlayTitle => 'Before You Begin';

  @override
  String get howToPlaySubtitle =>
      'Your journey is an interactive exploration. Walk, discover, solve, and unlock each landmark step by step.';

  @override
  String get howToPlayStep1Title => 'Start from the Map';

  @override
  String get howToPlayStep1Body =>
      'Your journey begins on the map. The current landmark will be highlighted, and locked landmarks will open as you progress.';

  @override
  String get howToPlayStep2Title => 'Go to the Landmark';

  @override
  String get howToPlayStep2Body =>
      'Use the map guidance to reach the selected landmark. When you arrive, the app will detect your location and unlock the landmark experience.';

  @override
  String get howToPlayStep3Title => 'Explore the Story';

  @override
  String get howToPlayStep3Body =>
      'Read or listen to the landmark story carefully. The content will help you understand the place and prepare for the next step.';

  @override
  String get howToPlayStep4Title => 'Save Your Memory';

  @override
  String get howToPlayStep4Body =>
      'At each landmark you visit, add a photo to save your personal memory before you continue.';

  @override
  String get howToPlayStep5Title => 'Solve the Challenge';

  @override
  String get howToPlayStep5Body =>
      'After exploring the landmark, complete a short challenge. The challenge also gives you a clue that guides you toward the next landmark.';

  @override
  String get howToPlayStep6Title => 'Complete the Journey';

  @override
  String get howToPlayStep6Body =>
      'Each completed landmark colors part of your journey map. When you finish all landmarks, your uploaded memories can be collected into a digital album.';

  @override
  String get howToPlayRecommendationsTitle => 'Discover nearby recommendations';

  @override
  String get howToPlayRecommendationsBody =>
      'As you progress through the journey, curated local spots may appear on the map. Tap a card for a quick preview, use View or Directions for more, or open the full list anytime from the tip icon in the corner.';

  @override
  String get howToPlayInactivityTitle => '72-hour activity window';

  @override
  String get howToPlayInactivityBody =>
      'Your in-progress journey stays available while you explore. If you do not open the map or advance for 72 hours, the journey ends automatically. You can start again from the journey page when you are ready.';

  @override
  String get howToPlayTipFooter =>
      'Tip: Stay near the landmark while completing its experience so your progress is saved correctly.';

  @override
  String get journeyTerminatedInactivity =>
      'This journey ended after 72 hours of inactivity. You can start again when you are ready.';

  @override
  String get howToPlayStartJourney => 'Start Journey';

  @override
  String get howToPlayBackToJourney => 'Back to Journey';

  @override
  String get howToPlaySaveHintFailed =>
      'We could not save your preference just now, but you can still continue. You may see these tips again later.';

  @override
  String get memoryUploadTitle => 'Capture This Moment';

  @override
  String get memoryUploadNote =>
      'Add a photo at this landmark to continue. Use your camera or choose one from your gallery.';

  @override
  String get memoryUploadPhotoRequired =>
      'Please add a photo for this landmark before continuing.';

  @override
  String get memoryUploadSignInRequired =>
      'Sign in to save your landmark photo.';

  @override
  String get memoryUploadTakeOrUpload => 'Take Photo or Upload';

  @override
  String get memoryUploadGalleryOrCamera => 'Gallery or Camera';

  @override
  String get memoryUploadAddMemory => 'Add Memory';

  @override
  String get memoryUploadSkipForNow => 'Skip for now';

  @override
  String get memoryUploadSkipHint =>
      'You can skip this step and continue to the challenge.';

  @override
  String get memoryUploadContinue => 'Continue';

  @override
  String get memoryUploadTakePhoto => 'Take Photo';

  @override
  String get memoryUploadFromGallery => 'Upload from Gallery';

  @override
  String get memoryUploadVideoFromGallery => 'Video from Gallery';

  @override
  String get memoryUploadCancel => 'Cancel';

  @override
  String get memoryUploadNext => 'Next';

  @override
  String get memoryUploadRetake => 'Retake';

  @override
  String get memoryUploadUploadAgain => 'Upload Again';

  @override
  String get memoryUploadSaveFailed =>
      'Couldn\'t save the memory. You can try again or continue.';

  @override
  String get memoryUploadPickFailed => 'Could not open camera or gallery.';

  @override
  String get memoryUploadVideoSelected => 'Video selected';

  @override
  String get journeyHistoryMemoriesEmpty =>
      'No memories saved for this journey yet.';

  @override
  String get journeyPurchasePayWithMoyasar => 'Pay with Moyasar';

  @override
  String get journeySummaryTitle => 'Journey summary';

  @override
  String get journeyDetailPhotosTitle => 'Photos from this journey';

  @override
  String get journeyDetailFeedbackTitle => 'Your feedback';

  @override
  String get journeyDetailNoFeedback =>
      'No feedback submitted for this journey.';

  @override
  String get journeyDetailFeedbackCommentLabel => 'Your comment';

  @override
  String get journeyDetailFeedbackNoComment => 'No written comment.';

  @override
  String get journeyDetailFeedbackAdminReply => 'Response from MaSeerah';

  @override
  String get journeyDetailFeedbackOverall => 'Overall experience';

  @override
  String get journeyDetailFeedbackContent => 'Content';

  @override
  String get journeyDetailFeedbackRecommendations => 'Recommendations';

  @override
  String get journeyDetailFeedbackChallenges => 'Challenges';

  @override
  String get journeyDetailFeedbackPhotos => 'Photos you shared with feedback';

  @override
  String get journeyDetailEmpty =>
      'No photos or feedback for this journey yet.';

  @override
  String get profileTitle => 'Profile';

  @override
  String profileHello(String name) {
    return 'Hello, $name!';
  }

  @override
  String profileJoined(String date) {
    return 'Joined $date';
  }

  @override
  String get profileMyJourneys => 'My Journeys';

  @override
  String get profileMyFeedbacks => 'My Feedbacks';

  @override
  String get profileMyPhotos => 'My Photos';

  @override
  String get profileShowAll => 'Show all';

  @override
  String get profileNoJourneysYet => 'No journeys yet';

  @override
  String get profileNoFeedbackYet => 'No feedback yet';

  @override
  String get profileNoPhotosYet => 'No photos yet';

  @override
  String get profileStatJourneys => 'JOURNEYS';

  @override
  String get profileStatPhotos => 'PHOTOS';

  @override
  String get profileJoinedUnknown => 'Unknown';

  @override
  String get profileUserFallback => 'User';

  @override
  String get profileFeedbackGeneral => 'General';

  @override
  String get profileJourneyFallback => 'Journey';

  @override
  String profileJourneyNumber(String number) {
    return 'Journey $number';
  }

  @override
  String get profileRelativeToday => 'Today';

  @override
  String get profileRelativeYesterday => 'Yesterday';

  @override
  String profileRelativeDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileFaqs => 'FAQs';

  @override
  String get profileContactUs => 'Contact us';

  @override
  String get profileLogout => 'Log out';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get editProfilePhotosGallery => 'Photos & gallery';

  @override
  String get editProfileTakePhoto => 'Take a photo';

  @override
  String get editProfileDateFuture => 'Date of birth cannot be in the future.';

  @override
  String get editProfileSaved => 'Profile saved';

  @override
  String get editProfileSaveFailed =>
      'Could not save profile. Please try again.';

  @override
  String get editProfileRetry => 'Retry';

  @override
  String get editProfilePick => 'Pick';

  @override
  String get editProfileClear => 'Clear';

  @override
  String get feedbackTakePhoto => 'Take Photo';

  @override
  String get feedbackChooseGallery => 'Choose from Gallery';

  @override
  String get feedbackCancel => 'Cancel';

  @override
  String get feedbackThankYou => 'Thank you for your feedback!';

  @override
  String get faqsTitle => 'FAQs';

  @override
  String get faqsTryAgain => 'Try again';

  @override
  String get couldNotOpenEmail => 'Could not open email app.';

  @override
  String get verifyCodeResent => 'A new code has been sent to your email.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNoInternet =>
      'No internet connection. Please check your network and try again.';

  @override
  String get errorInvalidEmail => 'Please enter a valid email address.';

  @override
  String get errorUserDisabled => 'This account has been disabled.';

  @override
  String get errorUserNotFound => 'No account found with this email.';

  @override
  String get errorWrongPassword => 'Incorrect password.';

  @override
  String get errorEmailInUse => 'This email is already registered.';

  @override
  String get errorWeakPassword =>
      'Password is too weak. Please use at least 6 characters.';

  @override
  String get errorInvalidCredential => 'Invalid email or password.';

  @override
  String get errorInvalidVerificationCode => 'Invalid verification code.';

  @override
  String get errorInvalidVerificationId =>
      'Verification link expired. Please try again.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get errorOperationNotAllowed => 'This sign-in method is not enabled.';

  @override
  String get errorRequiresRecentLogin => 'Please sign in again to continue.';

  @override
  String get landingSearchHint => 'Search journeys…';

  @override
  String get landingSearchExplore => 'Explore your next journey';

  @override
  String get landingCardDarbTitle => 'Darb Al-Sunnah';

  @override
  String get landingCardUhudTitle => 'Uhud Battle';

  @override
  String get landingCardValleyTitle => 'The Valley Adventure';

  @override
  String get landingCardDuration3h => '3 Hours';

  @override
  String get landingCardDuration2h => '2 Hours';

  @override
  String get landingCardDuration1_5h => '1.5 Hours';

  @override
  String get landingCardStops8 => '8 Stops';

  @override
  String get landingCardStops5 => '5 Stops';

  @override
  String get landingCardStops3 => '3 Stops';

  @override
  String get navHome => 'Home';

  @override
  String get navActiveJourneys => 'Active Journeys';

  @override
  String get navProfile => 'Profile';

  @override
  String get mediaShare => 'Share';

  @override
  String get mediaSaveToDevice => 'Save to device';

  @override
  String get mediaSavedToGallery => 'Photo saved to your gallery';

  @override
  String get mediaSaveFailed => 'Could not save photo. Please try again.';

  @override
  String get mediaShareFailed => 'Could not share photo. Please try again.';

  @override
  String get mediaPhotoPreview => 'Photo preview';

  @override
  String get mediaMoreActions => 'More actions';

  @override
  String get mediaPreview => 'Preview';
}
