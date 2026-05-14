// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get languagePickerTitle => 'لغة التطبيق';

  @override
  String get languagePickerSubtitle => 'اختر لغة الأزرار وشاشات الرحلة.';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get journeyListTitle => 'الرحلات النشطة';

  @override
  String get journeyListSignInPrompt =>
      'سجّل الدخول لعرض الرحلات التي بدأتها. يُحفظ تقدمك عند مغادرة الخريطة.';

  @override
  String get journeyListNoActive => 'لا توجد رحلات نشطة';

  @override
  String get journeyListNoActiveSubtitle =>
      'عند بدء رحلة ومغادرتها، ستظهر هنا لتتمكن من المتابعة.';

  @override
  String journeyListCurrentStop(int currentRegion) {
    return 'التوقف الحالي: $currentRegion';
  }

  @override
  String get journeyPurchaseTitle => 'رحلة';

  @override
  String get journeyPurchaseNotFound => 'لم يتم العثور على الرحلة.';

  @override
  String get journeyPurchaseAbout => 'نبذة';

  @override
  String get journeyPurchaseReadMore => 'عرض المزيد';

  @override
  String get journeyPurchaseReadLess => 'عرض أقل';

  @override
  String get journeyPurchaseStartPoint => 'نقطة البداية';

  @override
  String get journeyPurchaseStopsAlongWay => 'محطات في الطريق';

  @override
  String get journeyPurchaseEndPoint => 'نقطة النهاية';

  @override
  String get journeyPurchaseGoodToKnow => 'معلومات مفيدة';

  @override
  String get journeyPurchaseGoodToKnow1 =>
      'أفضل وقت للاستكشاف بعد الفجر أو بعد العصر';

  @override
  String get journeyPurchaseGoodToKnow2 =>
      'تجنّب الاستكشاف في منتصف النهار بسبب الحرارة';

  @override
  String get journeyPurchaseGoodToKnow3 =>
      'يمكنك الاستمتاع بالرجلة سيرًا أو بالدراجة أو عربة الجولف';

  @override
  String get journeyPurchaseSignInToPurchase => 'سجّل الدخول للشراء';

  @override
  String get journeyPurchaseLoading => 'جاري التحميل…';

  @override
  String get journeyPurchaseGiveFeedback => 'إرسال ملاحظات';

  @override
  String get journeyPurchaseUnlockJourney => 'فتح الرحلة';

  @override
  String get journeyPurchaseContinueYourJourney => 'متابعة رحلتك';

  @override
  String get journeyPurchaseStartYourJourney => 'ابدأ رحلتك';

  @override
  String get googleMapPageTitle => 'خريطة Google';

  @override
  String get googleMapPagePlaceholder => 'ستظهر خريطة Google هنا';

  @override
  String get mapCouldNotOpenGoogleMaps => 'تعذّر فتح خرائط Google.';

  @override
  String get mapCouldNotDetermineJourney =>
      'تعذّر تحديد هذه الرحلة. أعد المحاولة من قائمة الرحلات.';

  @override
  String get mapFinishJourneyFeedback => 'إنهاء الرحلة وترك ملاحظات';

  @override
  String get mapOpenGoogleMaps => 'فتح في خرائط Google';

  @override
  String get mapLoadingPlace => 'جاري تحميل المكان…';

  @override
  String get mapChallengeComingSoon => 'التحدي قريبًا.';

  @override
  String get mapStartChallenge => 'بدء التحدي';

  @override
  String get mapLandmarkDescriptionPlaceholder =>
      'أضف وصفًا لهذا المعلم في Firestore (الحقل: description).';

  @override
  String get mapImageFailedToLoad => 'فشل تحميل الصورة';

  @override
  String get mapRegionNotReached => 'لم تصل إلى هذه المرحلة بعد';

  @override
  String get mapStageDone => 'هذه المرحلة مكتملة';

  @override
  String get mapJourneyCompleted => 'اكتملت الرحلة!';

  @override
  String regionNumber(int region) {
    return 'المنطقة $region';
  }

  @override
  String get recommendationListTitle => 'أماكن مقترحة';

  @override
  String get recommendationListEmptyTitle => 'لا توجد توصيات بعد';

  @override
  String get recommendationListEmptySubtitle =>
      'استكشف المزيد من المعالم لفتح أماكن قريبة.';

  @override
  String get recommendationNoDescription => 'لا يوجد وصف بعد.';

  @override
  String get recommendationChipAveragePrice => 'متوسط السعر';

  @override
  String get recommendationChipWalkTime => 'مدة المشي';

  @override
  String get recommendationChipDistanceFromLast => 'المسافة من آخر محطة';

  @override
  String get recommendationChipRating => 'التقييم';

  @override
  String get recommendationPriceRanges => 'نطاقات الأسعار';

  @override
  String get recommendationOpenInGoogleMaps => 'فتح في خرائط Google';

  @override
  String recommendationQuickDistanceLine(String detail) {
    return 'المسافة · $detail';
  }

  @override
  String recommendationQuickWalkLine(String detail) {
    return 'المشي · $detail';
  }

  @override
  String get recommendationQuickRatingGoogleSuffix => ' Google';

  @override
  String get recommendationQuickDirections => 'الاتجاهات';

  @override
  String get recommendationQuickView => 'عرض';

  @override
  String get recommendationUrlNoLink => 'لا يوجد رابط موقع لهذا المكان.';

  @override
  String get recommendationUrlInvalidLink => 'رابط الموقع غير صالح.';

  @override
  String get recommendationUrlCouldNotOpen => 'تعذّر فتح الخرائط أو المتصفح.';

  @override
  String get challengeFeedbackCorrect => 'صحيح!';

  @override
  String get challengeFeedbackTryAgain => 'ليس تمامًا — حاول مرة أخرى.';

  @override
  String get challengeFeedbackAutoSolved => 'تم الحل تلقائيًا.';

  @override
  String get challengeResultPuzzleSolvedTitle => 'تم حل اللغز نيابة عنك';

  @override
  String get challengeResultCorrectTitle => 'إجابة صحيحة!';

  @override
  String get challengeResultCorrectAnswerHeading => 'الإجابة الصحيحة';

  @override
  String get challengeResultJourneyCompletedHeading => 'اكتملت رحلتك';

  @override
  String get challengeResultNextDestinationHeading => 'الوجهة التالية';

  @override
  String get challengeResultJourneyCompletedBody =>
      'أكملت جميع معالم هذه الرحلة.';

  @override
  String get challengeResultNotAvailable => 'غير متوفر';

  @override
  String get challengeResultDistanceNextTitle => 'المسافة للمعلم التالي:';

  @override
  String get challengeResultWalkTimeTitle => 'متوسط وقت المشي';

  @override
  String get challengeButtonFinish => 'إنهاء';

  @override
  String get challengeButtonNext => 'التالي';

  @override
  String get challengeButtonNextStage => 'المرحلة التالية';

  @override
  String challengeStageProgress(int current, int total) {
    return 'المرحلة $current من $total';
  }

  @override
  String get challengeShowHint => 'إظهار تلميح';

  @override
  String get challengeCheckYourAnswer => 'تحقق من إجابتك';

  @override
  String get challengeHintsHeading => 'تلميحات';

  @override
  String get challengeUnknownTitle => 'تحدي';

  @override
  String challengeUnknownBody(String type) {
    return 'تعذّر تحديد نوع هذا التحدي ($type). راجع حقول `quiz` / `type` في Firestore.';
  }

  @override
  String get challengeTypeMultipleChoiceTitle => 'اختيار من متعدد';

  @override
  String get challengeTypeChooseCorrect => 'اختر الإجابة الصحيحة';

  @override
  String get challengeTypeFillBlankTitle => 'املأ الفراغ';

  @override
  String get challengeTypeFillBlankPrompt => 'املأ الفراغ:';

  @override
  String get challengeFillBlankNoOptions => 'لا توجد خيارات في هذا التحدي.';

  @override
  String get challengeFillBlankNoChoices => 'لا توجد اختيارات في هذا التحدي.';

  @override
  String get challengeCheckAnswer => 'تحقق من الإجابة';

  @override
  String challengeHintNumber(int n) {
    return 'تلميح $n';
  }

  @override
  String get challengeTypeMatchingTitle => 'مطابقة';

  @override
  String get challengeMatchHint => 'طابق';

  @override
  String get challengeCheckMatches => 'تحقق من المطابقات';

  @override
  String get challengeMatchingDataMissing =>
      'بيانات المطابقة ناقصة في هذا التحدي.';

  @override
  String get challengeMatchThePairs => 'طابق الأزواج';

  @override
  String get challengeGroupA => 'المجموعة أ';

  @override
  String get challengeGroupB => 'المجموعة ب';

  @override
  String get challengeSelectedLabel => 'المحدد:';

  @override
  String get challengeTypeReorderTitle => 'إعادة ترتيب';

  @override
  String get challengeCheckOrder => 'تحقق من الترتيب';

  @override
  String get challengeTypeEliminationTitle => 'إقصاء';

  @override
  String get challengeCheck => 'تحقق';

  @override
  String get challengeReset => 'إعادة ضبط';

  @override
  String get challengeTypeAssembleTitle => 'تجميع';

  @override
  String get challengeCheckAssembly => 'تحقق من التجميع';

  @override
  String get challengeYourAnswer => 'إجابتك';

  @override
  String get challengeWordBank => 'بنك الكلمات';

  @override
  String get challengeOrderTheEvents => 'رتّب الأحداث';

  @override
  String get challengeMatchingNoPairsInData => 'لا توجد أزواج مطابقة في البيانات.';

  @override
  String get challengeEliminationTapHint => 'اضغط عنصرًا لإزالته من القائمة.';

  @override
  String get journeyPurchasePayWithMoyasar => 'الدفع عبر Moyasar';
}
