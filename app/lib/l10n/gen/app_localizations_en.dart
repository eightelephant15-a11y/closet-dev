// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stylist';

  @override
  String get homeTitle => 'Home';

  @override
  String get homePlaceholder => 'Your stylist is getting ready.';

  @override
  String get loading => 'Loading';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get offlineBanner =>
      'You\'re offline. Changes will sync when you reconnect.';

  @override
  String get emptyState => 'Nothing here yet.';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get continueLabel => 'Continue';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get welcomeTitle1 => 'Your wardrobe, styled';

  @override
  String get welcomeBody1 =>
      'Snap the clothes you own and get outfit ideas that actually use them.';

  @override
  String get welcomeTitle2 => 'Outfits that feel like you';

  @override
  String get welcomeBody2 =>
      'Answer a few quick questions and your stylist learns your taste.';

  @override
  String get welcomeTitle3 => 'Dress with less thinking';

  @override
  String get welcomeBody3 =>
      'Get a fresh outfit suggestion whenever you need one, for work, dates and travel.';

  @override
  String welcomePageIndicator(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get tryItFirst => 'Try it first';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInTitle => 'Sign in to continue';

  @override
  String get signInBody =>
      'Sign in with Google to keep your wardrobe and preferences safe.';

  @override
  String get signInFailed => 'Sign-in didn\'t work. Please try again.';

  @override
  String get ageTitle => 'Quick check';

  @override
  String get ageBody =>
      'You must be 16 or older to use this app. We only record that you confirmed it, not your birth date.';

  @override
  String get ageConfirmButton => 'I am 16 or older';

  @override
  String get ageUnderButton => 'I am under 16';

  @override
  String get blockedTitle => 'Thanks for stopping by';

  @override
  String get blockedBody =>
      'This app is for people 16 and older. We haven\'t kept any of your information. Come back when you\'re 16!';

  @override
  String quizProgress(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get quizFinish => 'Finish';

  @override
  String get quizHintMulti => 'Pick as many as you like';

  @override
  String get quizHintNone => 'Pick any, or skip if none apply';

  @override
  String get quizQDepartment => 'Which clothes should we show you?';

  @override
  String get quizQFit => 'How do you like your clothes to fit?';

  @override
  String get quizQColors => 'Which colours do you love?';

  @override
  String get quizQNeverWear => 'Anything you would never wear?';

  @override
  String get quizQDressCode => 'How dressed up is your usual day?';

  @override
  String get quizQGoals => 'What do you want help with?';

  @override
  String get deptMenswear => 'Menswear';

  @override
  String get deptWomenswear => 'Womenswear';

  @override
  String get deptBoth => 'Both';

  @override
  String get deptEverything => 'Show everything';

  @override
  String get fitRelaxed => 'Relaxed';

  @override
  String get fitRegular => 'Regular';

  @override
  String get fitSlim => 'Slim';

  @override
  String get dressCode0 => 'Very casual';

  @override
  String get dressCode1 => 'Casual';

  @override
  String get dressCode2 => 'Smart casual';

  @override
  String get dressCode3 => 'Business';

  @override
  String get dressCode4 => 'Formal';

  @override
  String get goalWork => 'Work';

  @override
  String get goalDates => 'Dates';

  @override
  String get goalTravel => 'Travel';

  @override
  String get goalEveryday => 'Everyday';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorWhite => 'White';

  @override
  String get colorGrey => 'Grey';

  @override
  String get colorNavy => 'Navy';

  @override
  String get colorBeige => 'Beige';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorOlive => 'Olive';

  @override
  String get colorRed => 'Red';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorOrange => 'Orange';

  @override
  String get neverSleeveless => 'Sleeveless';

  @override
  String get neverShorts => 'Shorts';

  @override
  String get neverBrightColors => 'Bright colours';

  @override
  String get neverSuits => 'Suits';

  @override
  String get neverTies => 'Ties';

  @override
  String get neverHats => 'Hats';

  @override
  String get neverHeels => 'Heels';

  @override
  String get neverSkirts => 'Skirts';

  @override
  String get neverDresses => 'Dresses';

  @override
  String get neverCropTops => 'Crop tops';

  @override
  String optionSelected(String label) {
    return '$label, selected';
  }

  @override
  String optionNotSelected(String label) {
    return '$label, not selected';
  }

  @override
  String get startingUp => 'Getting things ready';

  @override
  String get quizNoneOfThese => 'Nothing, I\'ll wear anything';

  @override
  String get quizDressCodeHint => 'Pick the closest match';

  @override
  String get basicsTitle => 'A few basics';

  @override
  String get basicsBody =>
      'This helps tailor your outfits. Everything here is optional.';

  @override
  String get basicsNameLabel => 'Your name';

  @override
  String get basicsUnitsLabel => 'Units';

  @override
  String get unitsImperial => 'Imperial (in, lb, °F)';

  @override
  String get unitsMetric => 'Metric (cm, kg, °C)';

  @override
  String get basicsCityLabel => 'City';

  @override
  String get basicsCityHint => 'Start typing your city';

  @override
  String get basicsCityPrivacy =>
      'We only store the city you type, never your exact location.';

  @override
  String get cityNoMatches => 'No matches. You can keep what you typed.';

  @override
  String get permCameraTitle => 'Photograph your clothes';

  @override
  String get permCameraBody =>
      'We use the camera so you can add clothes you own. Your photos stay private to you.';

  @override
  String get permPhotosTitle => 'Pick photos from your library';

  @override
  String get permPhotosBody =>
      'Choose pictures of your clothes. We only read the ones you select.';

  @override
  String get permLocationTitle => 'Weather-aware outfits';

  @override
  String get permLocationBody =>
      'We use your approximate location to check the weather. We never store your exact position.';

  @override
  String get permNotificationsTitle => 'Your daily outfit';

  @override
  String get permNotificationsBody =>
      'Get one outfit idea each morning, at the time you choose.';

  @override
  String get permAllow => 'Allow';

  @override
  String get permNotNow => 'Not now';

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get permDeniedCamera =>
      'No problem. You can use the sample closet or add photos from your library instead.';

  @override
  String get permDeniedPhotos =>
      'No problem. You can use the sample closet for now.';

  @override
  String get permDeniedLocation =>
      'No problem. Type your city and we\'ll use that for the weather.';

  @override
  String get permDeniedNotifications =>
      'No problem. You\'ll see your daily outfit when you open the app.';

  @override
  String get permGranted => 'Allowed. Thanks!';

  @override
  String get firstItemsTitle => 'Add your first 10 items';

  @override
  String get firstItemsBody =>
      'A few pieces are enough to style your first outfit. You don\'t need your whole closet.';

  @override
  String firstItemsProgress(int count, int total) {
    return '$count of $total items';
  }

  @override
  String get unlockRuleTitle => 'To unlock your first outfit';

  @override
  String get unlockRuleOr => 'or';

  @override
  String ruleTops(int have) {
    return 'Tops: $have of 2';
  }

  @override
  String ruleBottoms(int have) {
    return 'Bottoms: $have of 2';
  }

  @override
  String ruleShoes(int have) {
    return 'Shoes: $have of 1';
  }

  @override
  String ruleDress(int have) {
    return 'A dress: $have of 1';
  }

  @override
  String get firstItemsUnlocked => 'Ready! Your first outfit is unlocked.';

  @override
  String get useSampleCloset => 'Use sample closet';

  @override
  String get addWithCamera => 'Add with camera';

  @override
  String get seeFirstOutfit => 'See my first outfit';

  @override
  String get firstItemsHint =>
      'Add items or use the sample closet to continue.';

  @override
  String get firstOutfitTitle => 'Your first outfit';

  @override
  String get firstOutfitAlternatives => 'Two more ideas';

  @override
  String whyFavouriteColor(String color) {
    return 'Built around $color, one of your favourite colours.';
  }

  @override
  String whyDressCode(String level) {
    return 'Fits your $level dress code.';
  }

  @override
  String whyGoal(String goal) {
    return 'A good pick for $goal.';
  }

  @override
  String get whyVersatile => 'A versatile pick from your closet.';

  @override
  String outfitLabel(int n) {
    return 'Outfit $n';
  }

  @override
  String get saveOutfit => 'Save outfit';

  @override
  String get outfitSaved => 'Outfit saved';

  @override
  String get saveSignInTitle => 'Sign in to save';

  @override
  String get saveSignInBody =>
      'Create your account to keep this outfit and your closet on every device. Nothing you\'ve done so far is lost.';

  @override
  String get saveSignInButton => 'Continue with Google';

  @override
  String get saveSignInLater => 'Maybe later';

  @override
  String get firstOutfitEmptyTitle => 'We need a bit more';

  @override
  String get firstOutfitEmptyBody =>
      'Add a few more items and we\'ll build your outfit.';

  @override
  String get backToItems => 'Back to items';

  @override
  String get optionalTitle => 'Two optional extras';

  @override
  String get optionalBody =>
      'Both can wait. You can find them on Home any time.';

  @override
  String get optionalPartnerTitle => 'Invite a partner';

  @override
  String get optionalPartnerBody => 'Style together. Coming soon.';

  @override
  String get optionalNotifTitle => 'Daily outfit time';

  @override
  String get optionalNotifBody => 'Pick when you\'d like your outfit idea.';

  @override
  String get optionalFinish => 'Finish setup';

  @override
  String optionalSetFor(String time) {
    return 'Set for $time';
  }

  @override
  String get partnerTitle => 'Invite a partner';

  @override
  String get partnerBody =>
      'Couples styling is coming soon. We\'ll let you know when you can invite someone.';

  @override
  String get gotIt => 'Got it';

  @override
  String get notifTitle => 'When should we send your outfit?';

  @override
  String get notifBody => 'We\'ll suggest one outfit a day at this time.';

  @override
  String get notifSave => 'Save time';

  @override
  String get notifChooseTime => 'Choose time';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeGreetingNoName => 'Welcome';

  @override
  String get homeFinishSetup => 'Finish setting up';

  @override
  String get homeSettings => 'Settings';

  @override
  String get consentPromptTitle => 'Help us improve';

  @override
  String get consentPromptBody =>
      'Share anonymous usage data, like which screens you use. We never include your photos. You can change this any time in Settings.';

  @override
  String get consentAllow => 'Allow analytics';

  @override
  String get consentDecline => 'No thanks';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsGuest => 'You\'re using a guest account';

  @override
  String get settingsGuestBody =>
      'Sign in to keep your wardrobe and preferences on every device.';

  @override
  String settingsSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsConsentCentre => 'Privacy choices';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsTerms => 'Terms of service';

  @override
  String get settingsDataSection => 'Your data';

  @override
  String get settingsExport => 'Export my data';

  @override
  String get settingsDelete => 'Delete my account';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'Your data stays safe in your account. You can sign back in any time.';

  @override
  String get consentCentreTitle => 'Privacy choices';

  @override
  String get consentAnalyticsTitle => 'Share anonymous usage analytics';

  @override
  String get consentAnalyticsBody =>
      'Helps us understand which parts of the app work well. Off until you turn it on.';

  @override
  String get consentNoAiTitle => 'Do not use my photos to train AI models';

  @override
  String get consentNoAiBody =>
      'On by default. Your photos are only used to style your outfits.';

  @override
  String get consentLocationTitle => 'How we use your location';

  @override
  String get consentLocationBody =>
      'If you allow it, we use your approximate location to check the weather. We never store your exact position, only the city you type.';

  @override
  String consentPolicyVersion(String version) {
    return 'Policy version $version';
  }

  @override
  String get exportTitle => 'Export my data';

  @override
  String get exportBody =>
      'We\'ll prepare a JSON file with everything we hold about you. It can take a moment.';

  @override
  String get exportRequest => 'Request export';

  @override
  String get exportPreparing => 'Preparing your export…';

  @override
  String get exportReady => 'Your export is ready.';

  @override
  String get exportShare => 'Download and share';

  @override
  String get exportFailed =>
      'We couldn\'t prepare your export. Please try again.';

  @override
  String get exportShared => 'Export saved';

  @override
  String get deleteTitle => 'Delete my account';

  @override
  String get deleteBody =>
      'This signs you out everywhere and schedules your account for deletion. All your data and images are removed within 30 days. Until then you can sign back in to cancel.';

  @override
  String get deleteTypePrompt => 'Type DELETE to confirm';

  @override
  String get deleteConfirmWord => 'DELETE';

  @override
  String get deleteButton => 'Delete my account';

  @override
  String get deleteDone =>
      'Your account is scheduled for deletion. It will be fully removed within 30 days.';

  @override
  String get restoreTitle => 'Your account is scheduled for deletion';

  @override
  String get restoreBody =>
      'Restore it now to keep your data, or sign out and let the deletion go ahead.';

  @override
  String get restoreButton => 'Restore my account';

  @override
  String get iosCameraUsage =>
      'Stylist uses the camera so you can photograph the clothes you own.';

  @override
  String get iosPhotoLibraryUsage =>
      'Stylist reads photos you choose so you can add clothes you already have pictures of.';

  @override
  String get iosLocationUsage =>
      'Stylist uses your approximate location to suggest weather-appropriate outfits. We never store your exact position.';

  @override
  String garmentName(String color, String type) {
    return '$color $type';
  }

  @override
  String get closetTitle => 'My closet';

  @override
  String closetCount(int count, int limit) {
    return '$count of $limit items';
  }

  @override
  String get closetAdd => 'Add item';

  @override
  String get closetAddMany => 'Add several';

  @override
  String get closetSearch => 'Search your closet';

  @override
  String get closetSearchClear => 'Clear search';

  @override
  String get closetSort => 'Sort';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortRecentlyEdited => 'Recently edited';

  @override
  String get sortFormalityLow => 'Most casual first';

  @override
  String get sortFormalityHigh => 'Most formal first';

  @override
  String get closetFilters => 'Filters';

  @override
  String closetFiltersActive(int count) {
    return 'Filters, $count active';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterColour => 'Colour';

  @override
  String get filterSeason => 'Season';

  @override
  String get filterFormality => 'Formality';

  @override
  String get filterAvailability => 'Availability';

  @override
  String get filterFavourites => 'Favourites only';

  @override
  String get filterArchived => 'Show archived items';

  @override
  String get filterArchivedOnly => 'Archived only';

  @override
  String get filterClear => 'Clear filters';

  @override
  String filterApply(int count) {
    return 'Show $count items';
  }

  @override
  String get closetEmptyTitle => 'Your closet is empty';

  @override
  String get closetEmptyBody =>
      'Add your first item: one quick photo and we fill in the details.';

  @override
  String get closetNoMatches => 'Nothing matches these filters.';

  @override
  String get closetLoadError => 'We could not load your closet.';

  @override
  String get closetLoadingMore => 'Loading more';

  @override
  String get closetItemAnalysing => 'Analysing';

  @override
  String get closetItemNeedsReview => 'Check details';

  @override
  String get closetItemNeedsManual => 'Add details';

  @override
  String get closetItemFavourite => 'Favourite';

  @override
  String get closetItemArchived => 'Archived';

  @override
  String get closetItemSample => 'Sample';

  @override
  String closetItemLabel(String name, String status) {
    return '$name, $status';
  }

  @override
  String closetResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get availabilityAvailable => 'Available';

  @override
  String get availabilityLaundry => 'In the laundry';

  @override
  String get availabilityLent => 'Lent out';

  @override
  String get availabilityRepair => 'At repair';

  @override
  String availabilityBack(String date) {
    return 'Back on $date';
  }

  @override
  String get availabilitySetReturn => 'Set a return date';

  @override
  String get availabilityClearReturn => 'Remove return date';

  @override
  String get availabilityNote =>
      'Not used for outfits while it is unavailable or archived.';

  @override
  String get captureTitle => 'Add an item';

  @override
  String get captureHint =>
      'Lay it flat or hang it up on a plain background, in good light.';

  @override
  String get lightTooDark => 'Too dark. Move somewhere brighter.';

  @override
  String get lightTooBright => 'Too bright. Step out of direct sun.';

  @override
  String get lightOk => 'Lighting looks good.';

  @override
  String get captureTake => 'Take photo';

  @override
  String get captureLibrary => 'Choose from photos';

  @override
  String get captureFlip => 'Photo guide outline';

  @override
  String get captureRetake => 'Retake';

  @override
  String get captureUse => 'Use this photo';

  @override
  String get captureCrop => 'Crop to the item';

  @override
  String get captureCropOn => 'Cropped to the item';

  @override
  String get captureProcessing => 'Preparing your photo';

  @override
  String get captureUnavailable =>
      'The camera is not available. Choose a photo instead.';

  @override
  String get capturePermission =>
      'Camera access is off. Allow it in Settings, or choose a photo instead.';

  @override
  String get captureBad => 'That photo could not be read. Try another one.';

  @override
  String get captureReview => 'Review the photo';

  @override
  String get reviewTitle => 'Check the details';

  @override
  String get reviewAnalysing =>
      'Looking at your photo. You can start filling things in now.';

  @override
  String get reviewAnalysed =>
      'We filled in the details. Fix anything that is off.';

  @override
  String get reviewManual =>
      'We could not read this photo. Please fill in the details.';

  @override
  String get reviewUploading => 'Uploading your photo. You can keep going.';

  @override
  String get reviewWaiting =>
      'Waiting for a connection. Your photo is saved and will upload automatically.';

  @override
  String get reviewFailed => 'The upload did not work. Tap retry.';

  @override
  String get reviewCheck => 'Please check';

  @override
  String get reviewDone => 'Looks good';

  @override
  String get reviewSkipForNow => 'Review later';

  @override
  String get reviewFieldNone => 'None';

  @override
  String reviewLowConfidence(String field) {
    return '$field: please check';
  }

  @override
  String get reviewSaved => 'Saved';

  @override
  String get reviewSaveFailed => 'Could not save that change. Try again.';

  @override
  String get reviewPhoto => 'Photo of the item';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldSubcategory => 'Type';

  @override
  String get fieldPrimaryColor => 'Main colour';

  @override
  String get fieldSecondaryColor => 'Second colour';

  @override
  String get fieldPattern => 'Pattern';

  @override
  String get fieldFormality => 'Formality';

  @override
  String get fieldSeasons => 'Seasons';

  @override
  String get fieldFit => 'Fit';

  @override
  String get fieldMaterial => 'Material';

  @override
  String get fieldBrand => 'Brand';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get detailTitle => 'Item';

  @override
  String get detailFavourite => 'Add to favourites';

  @override
  String get detailUnfavourite => 'Remove from favourites';

  @override
  String get detailArchive => 'Archive';

  @override
  String get detailUnarchive => 'Restore from archive';

  @override
  String get detailArchiveNote =>
      'Archived items stay in your closet but are left out of outfits.';

  @override
  String get detailDelete => 'Delete item';

  @override
  String get detailDeleteTitle => 'Delete this item?';

  @override
  String get detailDeleteBody =>
      'This permanently deletes the item and its photos. It cannot be undone.';

  @override
  String get detailDeleteConfirm => 'Delete';

  @override
  String get detailReanalyse => 'Analyse photo again';

  @override
  String get detailMore => 'More options';

  @override
  String get detailSavedChanges => 'Changes saved';

  @override
  String get detailSaveFailed => 'Could not save your changes.';

  @override
  String get detailLoadFailed => 'We could not load this item.';

  @override
  String get bulkTitle => 'Add several items';

  @override
  String bulkBody(int max) {
    return 'Choose up to $max photos. We upload them in the background and fill in the details.';
  }

  @override
  String bulkRoom(int count) {
    return 'You have room for $count more items.';
  }

  @override
  String get bulkPick => 'Choose photos';

  @override
  String bulkProgress(int done, int total) {
    return '$done of $total uploaded';
  }

  @override
  String get bulkReviewTitle => 'Ready to review';

  @override
  String get bulkReviewBody => 'Look them over, or accept everything as is.';

  @override
  String get bulkAcceptAll => 'Accept all';

  @override
  String bulkAccepted(int count) {
    return '$count items accepted';
  }

  @override
  String bulkWorking(int count) {
    return 'Still analysing $count';
  }

  @override
  String get bulkFinished => 'All done';

  @override
  String get bulkDisabled =>
      'Adding several items at once is not available right now.';

  @override
  String bulkTooMany(int max) {
    return 'You picked more than $max. We kept the first $max.';
  }

  @override
  String get bulkView => 'Open my closet';

  @override
  String uploadBannerUploading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uploading $count photos',
      one: 'Uploading 1 photo',
    );
    return '$_temp0';
  }

  @override
  String get uploadBannerWaiting =>
      'Waiting for a connection. Your photos are saved.';

  @override
  String uploadBannerFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos need attention',
      one: '1 photo needs attention',
    );
    return '$_temp0';
  }

  @override
  String get uploadSheetTitle => 'Photo uploads';

  @override
  String get uploadStateQueued => 'Waiting';

  @override
  String get uploadStateWorking => 'Uploading';

  @override
  String get uploadStateDone => 'Uploaded';

  @override
  String get uploadStateFailed => 'Did not upload';

  @override
  String get uploadStateRejected => 'Not accepted';

  @override
  String get uploadRetry => 'Retry';

  @override
  String get uploadRemove => 'Remove';

  @override
  String uploadItemLabel(int index, String state) {
    return 'Photo $index: $state';
  }

  @override
  String get uploadErrFileTooLarge => 'This photo is too large.';

  @override
  String get uploadErrUnsupported => 'This kind of photo is not supported.';

  @override
  String get uploadErrLimit => 'Your closet is full.';

  @override
  String get uploadErrGeneric => 'Something went wrong. Try again.';

  @override
  String uploadProgressLabel(int percent) {
    return '$percent percent';
  }

  @override
  String get upgradeTitle => 'Your free closet is full';

  @override
  String upgradeBody(int limit) {
    return 'The free plan holds $limit items. Paid plans are coming soon. For now you can archive or delete items to make room.';
  }

  @override
  String get upgradeCta => 'Manage my closet';

  @override
  String limitReachedSnack(int limit) {
    return 'Your closet is full ($limit items).';
  }

  @override
  String get meterTitle => 'Outfit potential';

  @override
  String meterOutfits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possible outfits',
      one: '1 possible outfit',
      zero: 'No outfits yet',
    );
    return '$_temp0';
  }

  @override
  String get meterLevelEmpty => 'Add a top, a bottom and shoes to get started.';

  @override
  String get meterLevelStarting => 'A good start.';

  @override
  String get meterLevelGrowing => 'Your closet is filling out.';

  @override
  String get meterLevelRich => 'Plenty to work with.';

  @override
  String meterNudge(String item, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more outfits',
      one: '1 more outfit',
    );
    return 'Add $item to unlock $_temp0.';
  }

  @override
  String get meterNudgeFootwear => 'a pair of shoes';

  @override
  String get meterNudgeTop => 'a top';

  @override
  String get meterNudgeBottom => 'a bottom';

  @override
  String get meterNudgeDress => 'a dress';

  @override
  String meterProgressLabel(int percent) {
    return 'Closet progress, $percent percent';
  }

  @override
  String get homeClosetCard => 'My closet';

  @override
  String get homeClosetCardBody => 'Browse, add and edit your clothes.';

  @override
  String get firstItemsAddPhotos => 'Add from photos';

  @override
  String firstItemsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos are still being added',
      one: '1 photo is still being added',
    );
    return '$_temp0';
  }

  @override
  String get firstItemsOpenCloset => 'Open my closet';

  @override
  String get taxCatTop => 'Top';

  @override
  String get taxSubTShirt => 'T-shirt';

  @override
  String get taxSubLongSleeveTee => 'Long-sleeve tee';

  @override
  String get taxSubShirt => 'Shirt';

  @override
  String get taxSubBlouse => 'Blouse';

  @override
  String get taxSubPolo => 'Polo';

  @override
  String get taxSubSweater => 'Sweater';

  @override
  String get taxSubHoodie => 'Hoodie';

  @override
  String get taxSubTankTop => 'Tank top';

  @override
  String get taxSubCropTop => 'Crop top';

  @override
  String get taxSubCardigan => 'Cardigan';

  @override
  String get taxSubBodysuit => 'Bodysuit';

  @override
  String get taxCatBottom => 'Bottom';

  @override
  String get taxSubJeans => 'Jeans';

  @override
  String get taxSubTrousers => 'Trousers';

  @override
  String get taxSubChinos => 'Chinos';

  @override
  String get taxSubShorts => 'Shorts';

  @override
  String get taxSubJoggers => 'Joggers';

  @override
  String get taxSubLeggings => 'Leggings';

  @override
  String get taxSubSkirt => 'Skirt';

  @override
  String get taxCatOuterwear => 'Outerwear';

  @override
  String get taxSubJacket => 'Jacket';

  @override
  String get taxSubBlazer => 'Blazer';

  @override
  String get taxSubSuitJacket => 'Suit jacket';

  @override
  String get taxSubCoat => 'Coat';

  @override
  String get taxSubPuffer => 'Puffer jacket';

  @override
  String get taxSubDenimJacket => 'Denim jacket';

  @override
  String get taxSubRaincoat => 'Raincoat';

  @override
  String get taxSubVest => 'Vest';

  @override
  String get taxCatFootwear => 'Footwear';

  @override
  String get taxSubSneakers => 'Sneakers';

  @override
  String get taxSubBoots => 'Boots';

  @override
  String get taxSubLoafers => 'Loafers';

  @override
  String get taxSubSandals => 'Sandals';

  @override
  String get taxSubDressShoes => 'Dress shoes';

  @override
  String get taxSubHeels => 'Heels';

  @override
  String get taxSubFlats => 'Flats';

  @override
  String get taxCatDress => 'Dress';

  @override
  String get taxSubCasualDress => 'Casual dress';

  @override
  String get taxSubCocktailDress => 'Cocktail dress';

  @override
  String get taxSubMaxiDress => 'Maxi dress';

  @override
  String get taxSubJumpsuit => 'Jumpsuit';

  @override
  String get taxCatAccessory => 'Accessory';

  @override
  String get taxSubHat => 'Hat';

  @override
  String get taxSubScarf => 'Scarf';

  @override
  String get taxSubBelt => 'Belt';

  @override
  String get taxSubTie => 'Tie';

  @override
  String get taxSubBag => 'Bag';

  @override
  String get taxSubJewelry => 'Jewelry';

  @override
  String get taxSubSunglasses => 'Sunglasses';

  @override
  String get taxSubWatch => 'Watch';

  @override
  String get taxColorBlack => 'Black';

  @override
  String get taxColorWhite => 'White';

  @override
  String get taxColorGrey => 'Grey';

  @override
  String get taxColorNavy => 'Navy';

  @override
  String get taxColorBlue => 'Blue';

  @override
  String get taxColorLightBlue => 'Light blue';

  @override
  String get taxColorTeal => 'Teal';

  @override
  String get taxColorGreen => 'Green';

  @override
  String get taxColorOlive => 'Olive';

  @override
  String get taxColorYellow => 'Yellow';

  @override
  String get taxColorOrange => 'Orange';

  @override
  String get taxColorRed => 'Red';

  @override
  String get taxColorBurgundy => 'Burgundy';

  @override
  String get taxColorPink => 'Pink';

  @override
  String get taxColorPurple => 'Purple';

  @override
  String get taxColorBrown => 'Brown';

  @override
  String get taxColorBeige => 'Beige';

  @override
  String get taxColorCream => 'Cream';

  @override
  String get taxPatternSolid => 'Solid';

  @override
  String get taxPatternStriped => 'Striped';

  @override
  String get taxPatternChecked => 'Checked';

  @override
  String get taxPatternFloral => 'Floral';

  @override
  String get taxPatternPolkaDot => 'Polka dot';

  @override
  String get taxPatternGraphic => 'Graphic';

  @override
  String get taxPatternAnimalPrint => 'Animal print';

  @override
  String get taxPatternCamouflage => 'Camouflage';

  @override
  String get taxPatternOther => 'Other';

  @override
  String get taxSeasonSpring => 'Spring';

  @override
  String get taxSeasonSummer => 'Summer';

  @override
  String get taxSeasonAutumn => 'Autumn';

  @override
  String get taxSeasonWinter => 'Winter';

  @override
  String get taxFitSlim => 'Slim';

  @override
  String get taxFitRegular => 'Regular';

  @override
  String get taxFitRelaxed => 'Relaxed';

  @override
  String get taxFitOversized => 'Oversized';

  @override
  String get taxMaterialCotton => 'Cotton';

  @override
  String get taxMaterialLinen => 'Linen';

  @override
  String get taxMaterialWool => 'Wool';

  @override
  String get taxMaterialCashmere => 'Cashmere';

  @override
  String get taxMaterialSilk => 'Silk';

  @override
  String get taxMaterialDenim => 'Denim';

  @override
  String get taxMaterialLeather => 'Leather';

  @override
  String get taxMaterialSuede => 'Suede';

  @override
  String get taxMaterialPolyester => 'Polyester';

  @override
  String get taxMaterialNylon => 'Nylon';

  @override
  String get taxMaterialKnit => 'Knit';

  @override
  String get taxMaterialFleece => 'Fleece';

  @override
  String get taxMaterialOther => 'Other';

  @override
  String get taxFormality1 => 'Loungewear';

  @override
  String get taxFormality2 => 'Casual';

  @override
  String get taxFormality3 => 'Smart casual';

  @override
  String get taxFormality4 => 'Business';

  @override
  String get taxFormality5 => 'Formal';
}
