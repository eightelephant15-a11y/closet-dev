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
/// import 'gen/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Stylist'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your stylist is getting ready.'**
  String get homePlaceholder;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Changes will sync when you reconnect.'**
  String get offlineBanner;

  /// No description provided for @emptyState.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get emptyState;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @welcomeTitle1.
  ///
  /// In en, this message translates to:
  /// **'Your wardrobe, styled'**
  String get welcomeTitle1;

  /// No description provided for @welcomeBody1.
  ///
  /// In en, this message translates to:
  /// **'Snap the clothes you own and get outfit ideas that actually use them.'**
  String get welcomeBody1;

  /// No description provided for @welcomeTitle2.
  ///
  /// In en, this message translates to:
  /// **'Outfits that feel like you'**
  String get welcomeTitle2;

  /// No description provided for @welcomeBody2.
  ///
  /// In en, this message translates to:
  /// **'Answer a few quick questions and your stylist learns your taste.'**
  String get welcomeBody2;

  /// No description provided for @welcomeTitle3.
  ///
  /// In en, this message translates to:
  /// **'Dress with less thinking'**
  String get welcomeTitle3;

  /// No description provided for @welcomeBody3.
  ///
  /// In en, this message translates to:
  /// **'Get a fresh outfit suggestion whenever you need one, for work, dates and travel.'**
  String get welcomeBody3;

  /// No description provided for @welcomePageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String welcomePageIndicator(int current, int total);

  /// No description provided for @tryItFirst.
  ///
  /// In en, this message translates to:
  /// **'Try it first'**
  String get tryItFirst;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google to keep your wardrobe and preferences safe.'**
  String get signInBody;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn\'t work. Please try again.'**
  String get signInFailed;

  /// No description provided for @ageTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get ageTitle;

  /// No description provided for @ageBody.
  ///
  /// In en, this message translates to:
  /// **'You must be 16 or older to use this app. We only record that you confirmed it, not your birth date.'**
  String get ageBody;

  /// No description provided for @ageConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'I am 16 or older'**
  String get ageConfirmButton;

  /// No description provided for @ageUnderButton.
  ///
  /// In en, this message translates to:
  /// **'I am under 16'**
  String get ageUnderButton;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks for stopping by'**
  String get blockedTitle;

  /// No description provided for @blockedBody.
  ///
  /// In en, this message translates to:
  /// **'This app is for people 16 and older. We haven\'t kept any of your information. Come back when you\'re 16!'**
  String get blockedBody;

  /// No description provided for @quizProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String quizProgress(int current, int total);

  /// No description provided for @quizFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get quizFinish;

  /// No description provided for @quizHintMulti.
  ///
  /// In en, this message translates to:
  /// **'Pick as many as you like'**
  String get quizHintMulti;

  /// No description provided for @quizHintNone.
  ///
  /// In en, this message translates to:
  /// **'Pick any, or skip if none apply'**
  String get quizHintNone;

  /// No description provided for @quizQDepartment.
  ///
  /// In en, this message translates to:
  /// **'Which clothes should we show you?'**
  String get quizQDepartment;

  /// No description provided for @quizQFit.
  ///
  /// In en, this message translates to:
  /// **'How do you like your clothes to fit?'**
  String get quizQFit;

  /// No description provided for @quizQColors.
  ///
  /// In en, this message translates to:
  /// **'Which colours do you love?'**
  String get quizQColors;

  /// No description provided for @quizQNeverWear.
  ///
  /// In en, this message translates to:
  /// **'Anything you would never wear?'**
  String get quizQNeverWear;

  /// No description provided for @quizQDressCode.
  ///
  /// In en, this message translates to:
  /// **'How dressed up is your usual day?'**
  String get quizQDressCode;

  /// No description provided for @quizQGoals.
  ///
  /// In en, this message translates to:
  /// **'What do you want help with?'**
  String get quizQGoals;

  /// No description provided for @deptMenswear.
  ///
  /// In en, this message translates to:
  /// **'Menswear'**
  String get deptMenswear;

  /// No description provided for @deptWomenswear.
  ///
  /// In en, this message translates to:
  /// **'Womenswear'**
  String get deptWomenswear;

  /// No description provided for @deptBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get deptBoth;

  /// No description provided for @deptEverything.
  ///
  /// In en, this message translates to:
  /// **'Show everything'**
  String get deptEverything;

  /// No description provided for @fitRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get fitRelaxed;

  /// No description provided for @fitRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get fitRegular;

  /// No description provided for @fitSlim.
  ///
  /// In en, this message translates to:
  /// **'Slim'**
  String get fitSlim;

  /// No description provided for @dressCode0.
  ///
  /// In en, this message translates to:
  /// **'Very casual'**
  String get dressCode0;

  /// No description provided for @dressCode1.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get dressCode1;

  /// No description provided for @dressCode2.
  ///
  /// In en, this message translates to:
  /// **'Smart casual'**
  String get dressCode2;

  /// No description provided for @dressCode3.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get dressCode3;

  /// No description provided for @dressCode4.
  ///
  /// In en, this message translates to:
  /// **'Formal'**
  String get dressCode4;

  /// No description provided for @goalWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get goalWork;

  /// No description provided for @goalDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get goalDates;

  /// No description provided for @goalTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get goalTravel;

  /// No description provided for @goalEveryday.
  ///
  /// In en, this message translates to:
  /// **'Everyday'**
  String get goalEveryday;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get colorGrey;

  /// No description provided for @colorNavy.
  ///
  /// In en, this message translates to:
  /// **'Navy'**
  String get colorNavy;

  /// No description provided for @colorBeige.
  ///
  /// In en, this message translates to:
  /// **'Beige'**
  String get colorBeige;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get colorOlive;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @neverSleeveless.
  ///
  /// In en, this message translates to:
  /// **'Sleeveless'**
  String get neverSleeveless;

  /// No description provided for @neverShorts.
  ///
  /// In en, this message translates to:
  /// **'Shorts'**
  String get neverShorts;

  /// No description provided for @neverBrightColors.
  ///
  /// In en, this message translates to:
  /// **'Bright colours'**
  String get neverBrightColors;

  /// No description provided for @neverSuits.
  ///
  /// In en, this message translates to:
  /// **'Suits'**
  String get neverSuits;

  /// No description provided for @neverTies.
  ///
  /// In en, this message translates to:
  /// **'Ties'**
  String get neverTies;

  /// No description provided for @neverHats.
  ///
  /// In en, this message translates to:
  /// **'Hats'**
  String get neverHats;

  /// No description provided for @neverHeels.
  ///
  /// In en, this message translates to:
  /// **'Heels'**
  String get neverHeels;

  /// No description provided for @neverSkirts.
  ///
  /// In en, this message translates to:
  /// **'Skirts'**
  String get neverSkirts;

  /// No description provided for @neverDresses.
  ///
  /// In en, this message translates to:
  /// **'Dresses'**
  String get neverDresses;

  /// No description provided for @neverCropTops.
  ///
  /// In en, this message translates to:
  /// **'Crop tops'**
  String get neverCropTops;

  /// No description provided for @optionSelected.
  ///
  /// In en, this message translates to:
  /// **'{label}, selected'**
  String optionSelected(String label);

  /// No description provided for @optionNotSelected.
  ///
  /// In en, this message translates to:
  /// **'{label}, not selected'**
  String optionNotSelected(String label);

  /// No description provided for @startingUp.
  ///
  /// In en, this message translates to:
  /// **'Getting things ready'**
  String get startingUp;

  /// No description provided for @quizNoneOfThese.
  ///
  /// In en, this message translates to:
  /// **'Nothing, I\'ll wear anything'**
  String get quizNoneOfThese;

  /// No description provided for @quizDressCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the closest match'**
  String get quizDressCodeHint;

  /// No description provided for @basicsTitle.
  ///
  /// In en, this message translates to:
  /// **'A few basics'**
  String get basicsTitle;

  /// No description provided for @basicsBody.
  ///
  /// In en, this message translates to:
  /// **'This helps tailor your outfits. Everything here is optional.'**
  String get basicsBody;

  /// No description provided for @basicsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get basicsNameLabel;

  /// No description provided for @basicsUnitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get basicsUnitsLabel;

  /// No description provided for @unitsImperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial (in, lb, °F)'**
  String get unitsImperial;

  /// No description provided for @unitsMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric (cm, kg, °C)'**
  String get unitsMetric;

  /// No description provided for @basicsCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get basicsCityLabel;

  /// No description provided for @basicsCityHint.
  ///
  /// In en, this message translates to:
  /// **'Start typing your city'**
  String get basicsCityHint;

  /// No description provided for @basicsCityPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We only store the city you type, never your exact location.'**
  String get basicsCityPrivacy;

  /// No description provided for @cityNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches. You can keep what you typed.'**
  String get cityNoMatches;

  /// No description provided for @permCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Photograph your clothes'**
  String get permCameraTitle;

  /// No description provided for @permCameraBody.
  ///
  /// In en, this message translates to:
  /// **'We use the camera so you can add clothes you own. Your photos stay private to you.'**
  String get permCameraBody;

  /// No description provided for @permPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick photos from your library'**
  String get permPhotosTitle;

  /// No description provided for @permPhotosBody.
  ///
  /// In en, this message translates to:
  /// **'Choose pictures of your clothes. We only read the ones you select.'**
  String get permPhotosBody;

  /// No description provided for @permLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather-aware outfits'**
  String get permLocationTitle;

  /// No description provided for @permLocationBody.
  ///
  /// In en, this message translates to:
  /// **'We use your approximate location to check the weather. We never store your exact position.'**
  String get permLocationBody;

  /// No description provided for @permNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your daily outfit'**
  String get permNotificationsTitle;

  /// No description provided for @permNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Get one outfit idea each morning, at the time you choose.'**
  String get permNotificationsBody;

  /// No description provided for @permAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permAllow;

  /// No description provided for @permNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get permNotNow;

  /// No description provided for @permOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permOpenSettings;

  /// No description provided for @permDeniedCamera.
  ///
  /// In en, this message translates to:
  /// **'No problem. You can use the sample closet or add photos from your library instead.'**
  String get permDeniedCamera;

  /// No description provided for @permDeniedPhotos.
  ///
  /// In en, this message translates to:
  /// **'No problem. You can use the sample closet for now.'**
  String get permDeniedPhotos;

  /// No description provided for @permDeniedLocation.
  ///
  /// In en, this message translates to:
  /// **'No problem. Type your city and we\'ll use that for the weather.'**
  String get permDeniedLocation;

  /// No description provided for @permDeniedNotifications.
  ///
  /// In en, this message translates to:
  /// **'No problem. You\'ll see your daily outfit when you open the app.'**
  String get permDeniedNotifications;

  /// No description provided for @permGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed. Thanks!'**
  String get permGranted;

  /// No description provided for @firstItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first 10 items'**
  String get firstItemsTitle;

  /// No description provided for @firstItemsBody.
  ///
  /// In en, this message translates to:
  /// **'A few pieces are enough to style your first outfit. You don\'t need your whole closet.'**
  String get firstItemsBody;

  /// No description provided for @firstItemsProgress.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} items'**
  String firstItemsProgress(int count, int total);

  /// No description provided for @unlockRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'To unlock your first outfit'**
  String get unlockRuleTitle;

  /// No description provided for @unlockRuleOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get unlockRuleOr;

  /// No description provided for @ruleTops.
  ///
  /// In en, this message translates to:
  /// **'Tops: {have} of 2'**
  String ruleTops(int have);

  /// No description provided for @ruleBottoms.
  ///
  /// In en, this message translates to:
  /// **'Bottoms: {have} of 2'**
  String ruleBottoms(int have);

  /// No description provided for @ruleShoes.
  ///
  /// In en, this message translates to:
  /// **'Shoes: {have} of 1'**
  String ruleShoes(int have);

  /// No description provided for @ruleDress.
  ///
  /// In en, this message translates to:
  /// **'A dress: {have} of 1'**
  String ruleDress(int have);

  /// No description provided for @firstItemsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Ready! Your first outfit is unlocked.'**
  String get firstItemsUnlocked;

  /// No description provided for @useSampleCloset.
  ///
  /// In en, this message translates to:
  /// **'Use sample closet'**
  String get useSampleCloset;

  /// No description provided for @addWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Add with camera'**
  String get addWithCamera;

  /// No description provided for @seeFirstOutfit.
  ///
  /// In en, this message translates to:
  /// **'See my first outfit'**
  String get seeFirstOutfit;

  /// No description provided for @firstItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Add items or use the sample closet to continue.'**
  String get firstItemsHint;

  /// No description provided for @firstOutfitTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first outfit'**
  String get firstOutfitTitle;

  /// No description provided for @firstOutfitAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Two more ideas'**
  String get firstOutfitAlternatives;

  /// No description provided for @whyFavouriteColor.
  ///
  /// In en, this message translates to:
  /// **'Built around {color}, one of your favourite colours.'**
  String whyFavouriteColor(String color);

  /// No description provided for @whyDressCode.
  ///
  /// In en, this message translates to:
  /// **'Fits your {level} dress code.'**
  String whyDressCode(String level);

  /// No description provided for @whyGoal.
  ///
  /// In en, this message translates to:
  /// **'A good pick for {goal}.'**
  String whyGoal(String goal);

  /// No description provided for @whyVersatile.
  ///
  /// In en, this message translates to:
  /// **'A versatile pick from your closet.'**
  String get whyVersatile;

  /// No description provided for @outfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Outfit {n}'**
  String outfitLabel(int n);

  /// No description provided for @saveOutfit.
  ///
  /// In en, this message translates to:
  /// **'Save outfit'**
  String get saveOutfit;

  /// No description provided for @outfitSaved.
  ///
  /// In en, this message translates to:
  /// **'Outfit saved'**
  String get outfitSaved;

  /// No description provided for @saveSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save'**
  String get saveSignInTitle;

  /// No description provided for @saveSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Create your account to keep this outfit and your closet on every device. Nothing you\'ve done so far is lost.'**
  String get saveSignInBody;

  /// No description provided for @saveSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get saveSignInButton;

  /// No description provided for @saveSignInLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get saveSignInLater;

  /// No description provided for @firstOutfitEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'We need a bit more'**
  String get firstOutfitEmptyTitle;

  /// No description provided for @firstOutfitEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a few more items and we\'ll build your outfit.'**
  String get firstOutfitEmptyBody;

  /// No description provided for @backToItems.
  ///
  /// In en, this message translates to:
  /// **'Back to items'**
  String get backToItems;

  /// No description provided for @optionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Two optional extras'**
  String get optionalTitle;

  /// No description provided for @optionalBody.
  ///
  /// In en, this message translates to:
  /// **'Both can wait. You can find them on Home any time.'**
  String get optionalBody;

  /// No description provided for @optionalPartnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a partner'**
  String get optionalPartnerTitle;

  /// No description provided for @optionalPartnerBody.
  ///
  /// In en, this message translates to:
  /// **'Style together. Coming soon.'**
  String get optionalPartnerBody;

  /// No description provided for @optionalNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily outfit time'**
  String get optionalNotifTitle;

  /// No description provided for @optionalNotifBody.
  ///
  /// In en, this message translates to:
  /// **'Pick when you\'d like your outfit idea.'**
  String get optionalNotifBody;

  /// No description provided for @optionalFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get optionalFinish;

  /// No description provided for @optionalSetFor.
  ///
  /// In en, this message translates to:
  /// **'Set for {time}'**
  String optionalSetFor(String time);

  /// No description provided for @partnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a partner'**
  String get partnerTitle;

  /// No description provided for @partnerBody.
  ///
  /// In en, this message translates to:
  /// **'Couples styling is coming soon. We\'ll let you know when you can invite someone.'**
  String get partnerBody;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'When should we send your outfit?'**
  String get notifTitle;

  /// No description provided for @notifBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll suggest one outfit a day at this time.'**
  String get notifBody;

  /// No description provided for @notifSave.
  ///
  /// In en, this message translates to:
  /// **'Save time'**
  String get notifSave;

  /// No description provided for @notifChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose time'**
  String get notifChooseTime;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingNoName.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get homeGreetingNoName;

  /// No description provided for @homeFinishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up'**
  String get homeFinishSetup;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @consentPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Help us improve'**
  String get consentPromptTitle;

  /// No description provided for @consentPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage data, like which screens you use. We never include your photos. You can change this any time in Settings.'**
  String get consentPromptBody;

  /// No description provided for @consentAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow analytics'**
  String get consentAllow;

  /// No description provided for @consentDecline.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get consentDecline;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsGuest.
  ///
  /// In en, this message translates to:
  /// **'You\'re using a guest account'**
  String get settingsGuest;

  /// No description provided for @settingsGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your wardrobe and preferences on every device.'**
  String get settingsGuestBody;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String settingsSignedInAs(String email);

  /// No description provided for @settingsPrivacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacySection;

  /// No description provided for @settingsConsentCentre.
  ///
  /// In en, this message translates to:
  /// **'Privacy choices'**
  String get settingsConsentCentre;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get settingsTerms;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsDataSection;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get settingsExport;

  /// No description provided for @settingsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDelete;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays safe in your account. You can sign back in any time.'**
  String get signOutConfirmBody;

  /// No description provided for @consentCentreTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy choices'**
  String get consentCentreTitle;

  /// No description provided for @consentAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage analytics'**
  String get consentAnalyticsTitle;

  /// No description provided for @consentAnalyticsBody.
  ///
  /// In en, this message translates to:
  /// **'Helps us understand which parts of the app work well. Off until you turn it on.'**
  String get consentAnalyticsBody;

  /// No description provided for @consentNoAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Do not use my photos to train AI models'**
  String get consentNoAiTitle;

  /// No description provided for @consentNoAiBody.
  ///
  /// In en, this message translates to:
  /// **'On by default. Your photos are only used to style your outfits.'**
  String get consentNoAiBody;

  /// No description provided for @consentLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'How we use your location'**
  String get consentLocationTitle;

  /// No description provided for @consentLocationBody.
  ///
  /// In en, this message translates to:
  /// **'If you allow it, we use your approximate location to check the weather. We never store your exact position, only the city you type.'**
  String get consentLocationBody;

  /// No description provided for @consentPolicyVersion.
  ///
  /// In en, this message translates to:
  /// **'Policy version {version}'**
  String consentPolicyVersion(String version);

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get exportTitle;

  /// No description provided for @exportBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll prepare a JSON file with everything we hold about you. It can take a moment.'**
  String get exportBody;

  /// No description provided for @exportRequest.
  ///
  /// In en, this message translates to:
  /// **'Request export'**
  String get exportRequest;

  /// No description provided for @exportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your export…'**
  String get exportPreparing;

  /// No description provided for @exportReady.
  ///
  /// In en, this message translates to:
  /// **'Your export is ready.'**
  String get exportReady;

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Download and share'**
  String get exportShare;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t prepare your export. Please try again.'**
  String get exportFailed;

  /// No description provided for @exportShared.
  ///
  /// In en, this message translates to:
  /// **'Export saved'**
  String get exportShared;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In en, this message translates to:
  /// **'This signs you out everywhere and schedules your account for deletion. All your data and images are removed within 30 days. Until then you can sign back in to cancel.'**
  String get deleteBody;

  /// No description provided for @deleteTypePrompt.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get deleteTypePrompt;

  /// No description provided for @deleteConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteConfirmWord;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteButton;

  /// No description provided for @deleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled for deletion. It will be fully removed within 30 days.'**
  String get deleteDone;

  /// No description provided for @restoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled for deletion'**
  String get restoreTitle;

  /// No description provided for @restoreBody.
  ///
  /// In en, this message translates to:
  /// **'Restore it now to keep your data, or sign out and let the deletion go ahead.'**
  String get restoreBody;

  /// No description provided for @restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore my account'**
  String get restoreButton;

  /// iOS NSCameraUsageDescription (generated into InfoPlist.strings by tool/gen_ios_strings.py)
  ///
  /// In en, this message translates to:
  /// **'Stylist uses the camera so you can photograph the clothes you own.'**
  String get iosCameraUsage;

  /// iOS NSPhotoLibraryUsageDescription
  ///
  /// In en, this message translates to:
  /// **'Stylist reads photos you choose so you can add clothes you already have pictures of.'**
  String get iosPhotoLibraryUsage;

  /// iOS NSLocationWhenInUseUsageDescription
  ///
  /// In en, this message translates to:
  /// **'Stylist uses your approximate location to suggest weather-appropriate outfits. We never store your exact position.'**
  String get iosLocationUsage;

  /// No description provided for @garmentName.
  ///
  /// In en, this message translates to:
  /// **'{color} {type}'**
  String garmentName(String color, String type);

  /// No description provided for @closetTitle.
  ///
  /// In en, this message translates to:
  /// **'My closet'**
  String get closetTitle;

  /// No description provided for @closetCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} items'**
  String closetCount(int count, int limit);

  /// No description provided for @closetAdd.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get closetAdd;

  /// No description provided for @closetAddMany.
  ///
  /// In en, this message translates to:
  /// **'Add several'**
  String get closetAddMany;

  /// No description provided for @closetSearch.
  ///
  /// In en, this message translates to:
  /// **'Search your closet'**
  String get closetSearch;

  /// No description provided for @closetSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get closetSearchClear;

  /// No description provided for @closetSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get closetSort;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldest;

  /// No description provided for @sortRecentlyEdited.
  ///
  /// In en, this message translates to:
  /// **'Recently edited'**
  String get sortRecentlyEdited;

  /// No description provided for @sortFormalityLow.
  ///
  /// In en, this message translates to:
  /// **'Most casual first'**
  String get sortFormalityLow;

  /// No description provided for @sortFormalityHigh.
  ///
  /// In en, this message translates to:
  /// **'Most formal first'**
  String get sortFormalityHigh;

  /// No description provided for @closetFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get closetFilters;

  /// No description provided for @closetFiltersActive.
  ///
  /// In en, this message translates to:
  /// **'Filters, {count} active'**
  String closetFiltersActive(int count);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get filterCategory;

  /// No description provided for @filterColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get filterColour;

  /// No description provided for @filterSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get filterSeason;

  /// No description provided for @filterFormality.
  ///
  /// In en, this message translates to:
  /// **'Formality'**
  String get filterFormality;

  /// No description provided for @filterAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get filterAvailability;

  /// No description provided for @filterFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites only'**
  String get filterFavourites;

  /// No description provided for @filterArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived items'**
  String get filterArchived;

  /// No description provided for @filterArchivedOnly.
  ///
  /// In en, this message translates to:
  /// **'Archived only'**
  String get filterArchivedOnly;

  /// No description provided for @filterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get filterClear;

  /// No description provided for @filterApply.
  ///
  /// In en, this message translates to:
  /// **'Show {count} items'**
  String filterApply(int count);

  /// No description provided for @closetEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your closet is empty'**
  String get closetEmptyTitle;

  /// No description provided for @closetEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first item: one quick photo and we fill in the details.'**
  String get closetEmptyBody;

  /// No description provided for @closetNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters.'**
  String get closetNoMatches;

  /// No description provided for @closetLoadError.
  ///
  /// In en, this message translates to:
  /// **'We could not load your closet.'**
  String get closetLoadError;

  /// No description provided for @closetLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more'**
  String get closetLoadingMore;

  /// No description provided for @closetItemAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing'**
  String get closetItemAnalysing;

  /// No description provided for @closetItemNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Check details'**
  String get closetItemNeedsReview;

  /// No description provided for @closetItemNeedsManual.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get closetItemNeedsManual;

  /// No description provided for @closetItemFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get closetItemFavourite;

  /// No description provided for @closetItemArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get closetItemArchived;

  /// No description provided for @closetItemSample.
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get closetItemSample;

  /// No description provided for @closetItemLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, {status}'**
  String closetItemLabel(String name, String status);

  /// No description provided for @closetResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String closetResultCount(int count);

  /// No description provided for @availabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availabilityAvailable;

  /// No description provided for @availabilityLaundry.
  ///
  /// In en, this message translates to:
  /// **'In the laundry'**
  String get availabilityLaundry;

  /// No description provided for @availabilityLent.
  ///
  /// In en, this message translates to:
  /// **'Lent out'**
  String get availabilityLent;

  /// No description provided for @availabilityRepair.
  ///
  /// In en, this message translates to:
  /// **'At repair'**
  String get availabilityRepair;

  /// No description provided for @availabilityBack.
  ///
  /// In en, this message translates to:
  /// **'Back on {date}'**
  String availabilityBack(String date);

  /// No description provided for @availabilitySetReturn.
  ///
  /// In en, this message translates to:
  /// **'Set a return date'**
  String get availabilitySetReturn;

  /// No description provided for @availabilityClearReturn.
  ///
  /// In en, this message translates to:
  /// **'Remove return date'**
  String get availabilityClearReturn;

  /// No description provided for @availabilityNote.
  ///
  /// In en, this message translates to:
  /// **'Not used for outfits while it is unavailable or archived.'**
  String get availabilityNote;

  /// No description provided for @captureTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get captureTitle;

  /// No description provided for @captureHint.
  ///
  /// In en, this message translates to:
  /// **'Lay it flat or hang it up on a plain background, in good light.'**
  String get captureHint;

  /// No description provided for @lightTooDark.
  ///
  /// In en, this message translates to:
  /// **'Too dark. Move somewhere brighter.'**
  String get lightTooDark;

  /// No description provided for @lightTooBright.
  ///
  /// In en, this message translates to:
  /// **'Too bright. Step out of direct sun.'**
  String get lightTooBright;

  /// No description provided for @lightOk.
  ///
  /// In en, this message translates to:
  /// **'Lighting looks good.'**
  String get lightOk;

  /// No description provided for @captureTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get captureTake;

  /// No description provided for @captureLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from photos'**
  String get captureLibrary;

  /// No description provided for @captureFlip.
  ///
  /// In en, this message translates to:
  /// **'Photo guide outline'**
  String get captureFlip;

  /// No description provided for @captureRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get captureRetake;

  /// No description provided for @captureUse.
  ///
  /// In en, this message translates to:
  /// **'Use this photo'**
  String get captureUse;

  /// No description provided for @captureCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop to the item'**
  String get captureCrop;

  /// No description provided for @captureCropOn.
  ///
  /// In en, this message translates to:
  /// **'Cropped to the item'**
  String get captureCropOn;

  /// No description provided for @captureProcessing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your photo'**
  String get captureProcessing;

  /// No description provided for @captureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is not available. Choose a photo instead.'**
  String get captureUnavailable;

  /// No description provided for @capturePermission.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Allow it in Settings, or choose a photo instead.'**
  String get capturePermission;

  /// No description provided for @captureBad.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be read. Try another one.'**
  String get captureBad;

  /// No description provided for @captureReview.
  ///
  /// In en, this message translates to:
  /// **'Review the photo'**
  String get captureReview;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Check the details'**
  String get reviewTitle;

  /// No description provided for @reviewAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Looking at your photo. You can start filling things in now.'**
  String get reviewAnalysing;

  /// No description provided for @reviewAnalysed.
  ///
  /// In en, this message translates to:
  /// **'We filled in the details. Fix anything that is off.'**
  String get reviewAnalysed;

  /// No description provided for @reviewManual.
  ///
  /// In en, this message translates to:
  /// **'We could not read this photo. Please fill in the details.'**
  String get reviewManual;

  /// No description provided for @reviewUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading your photo. You can keep going.'**
  String get reviewUploading;

  /// No description provided for @reviewWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection. Your photo is saved and will upload automatically.'**
  String get reviewWaiting;

  /// No description provided for @reviewFailed.
  ///
  /// In en, this message translates to:
  /// **'The upload did not work. Tap retry.'**
  String get reviewFailed;

  /// No description provided for @reviewCheck.
  ///
  /// In en, this message translates to:
  /// **'Please check'**
  String get reviewCheck;

  /// No description provided for @reviewDone.
  ///
  /// In en, this message translates to:
  /// **'Looks good'**
  String get reviewDone;

  /// No description provided for @reviewSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Review later'**
  String get reviewSkipForNow;

  /// No description provided for @reviewFieldNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get reviewFieldNone;

  /// No description provided for @reviewLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'{field}: please check'**
  String reviewLowConfidence(String field);

  /// No description provided for @reviewSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get reviewSaved;

  /// No description provided for @reviewSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save that change. Try again.'**
  String get reviewSaveFailed;

  /// No description provided for @reviewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo of the item'**
  String get reviewPhoto;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldSubcategory;

  /// No description provided for @fieldPrimaryColor.
  ///
  /// In en, this message translates to:
  /// **'Main colour'**
  String get fieldPrimaryColor;

  /// No description provided for @fieldSecondaryColor.
  ///
  /// In en, this message translates to:
  /// **'Second colour'**
  String get fieldSecondaryColor;

  /// No description provided for @fieldPattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get fieldPattern;

  /// No description provided for @fieldFormality.
  ///
  /// In en, this message translates to:
  /// **'Formality'**
  String get fieldFormality;

  /// No description provided for @fieldSeasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get fieldSeasons;

  /// No description provided for @fieldFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get fieldFit;

  /// No description provided for @fieldMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get fieldMaterial;

  /// No description provided for @fieldBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get fieldBrand;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get detailTitle;

  /// No description provided for @detailFavourite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get detailFavourite;

  /// No description provided for @detailUnfavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get detailUnfavourite;

  /// No description provided for @detailArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get detailArchive;

  /// No description provided for @detailUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Restore from archive'**
  String get detailUnarchive;

  /// No description provided for @detailArchiveNote.
  ///
  /// In en, this message translates to:
  /// **'Archived items stay in your closet but are left out of outfits.'**
  String get detailArchiveNote;

  /// No description provided for @detailDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get detailDelete;

  /// No description provided for @detailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get detailDeleteTitle;

  /// No description provided for @detailDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the item and its photos. It cannot be undone.'**
  String get detailDeleteBody;

  /// No description provided for @detailDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get detailDeleteConfirm;

  /// No description provided for @detailReanalyse.
  ///
  /// In en, this message translates to:
  /// **'Analyse photo again'**
  String get detailReanalyse;

  /// No description provided for @detailMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get detailMore;

  /// No description provided for @detailSavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get detailSavedChanges;

  /// No description provided for @detailSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your changes.'**
  String get detailSaveFailed;

  /// No description provided for @detailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load this item.'**
  String get detailLoadFailed;

  /// No description provided for @bulkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add several items'**
  String get bulkTitle;

  /// No description provided for @bulkBody.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {max} photos. We upload them in the background and fill in the details.'**
  String bulkBody(int max);

  /// No description provided for @bulkRoom.
  ///
  /// In en, this message translates to:
  /// **'You have room for {count} more items.'**
  String bulkRoom(int count);

  /// No description provided for @bulkPick.
  ///
  /// In en, this message translates to:
  /// **'Choose photos'**
  String get bulkPick;

  /// No description provided for @bulkProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} uploaded'**
  String bulkProgress(int done, int total);

  /// No description provided for @bulkReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to review'**
  String get bulkReviewTitle;

  /// No description provided for @bulkReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Look them over, or accept everything as is.'**
  String get bulkReviewBody;

  /// No description provided for @bulkAcceptAll.
  ///
  /// In en, this message translates to:
  /// **'Accept all'**
  String get bulkAcceptAll;

  /// No description provided for @bulkAccepted.
  ///
  /// In en, this message translates to:
  /// **'{count} items accepted'**
  String bulkAccepted(int count);

  /// No description provided for @bulkWorking.
  ///
  /// In en, this message translates to:
  /// **'Still analysing {count}'**
  String bulkWorking(int count);

  /// No description provided for @bulkFinished.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get bulkFinished;

  /// No description provided for @bulkDisabled.
  ///
  /// In en, this message translates to:
  /// **'Adding several items at once is not available right now.'**
  String get bulkDisabled;

  /// No description provided for @bulkTooMany.
  ///
  /// In en, this message translates to:
  /// **'You picked more than {max}. We kept the first {max}.'**
  String bulkTooMany(int max);

  /// No description provided for @bulkView.
  ///
  /// In en, this message translates to:
  /// **'Open my closet'**
  String get bulkView;

  /// No description provided for @uploadBannerUploading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Uploading 1 photo} other{Uploading {count} photos}}'**
  String uploadBannerUploading(int count);

  /// No description provided for @uploadBannerWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection. Your photos are saved.'**
  String get uploadBannerWaiting;

  /// No description provided for @uploadBannerFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo needs attention} other{{count} photos need attention}}'**
  String uploadBannerFailed(int count);

  /// No description provided for @uploadSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo uploads'**
  String get uploadSheetTitle;

  /// No description provided for @uploadStateQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get uploadStateQueued;

  /// No description provided for @uploadStateWorking.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploadStateWorking;

  /// No description provided for @uploadStateDone.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploadStateDone;

  /// No description provided for @uploadStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Did not upload'**
  String get uploadStateFailed;

  /// No description provided for @uploadStateRejected.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get uploadStateRejected;

  /// No description provided for @uploadRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get uploadRetry;

  /// No description provided for @uploadRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get uploadRemove;

  /// No description provided for @uploadItemLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo {index}: {state}'**
  String uploadItemLabel(int index, String state);

  /// No description provided for @uploadErrFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This photo is too large.'**
  String get uploadErrFileTooLarge;

  /// No description provided for @uploadErrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This kind of photo is not supported.'**
  String get uploadErrUnsupported;

  /// No description provided for @uploadErrLimit.
  ///
  /// In en, this message translates to:
  /// **'Your closet is full.'**
  String get uploadErrLimit;

  /// No description provided for @uploadErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get uploadErrGeneric;

  /// No description provided for @uploadProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent'**
  String uploadProgressLabel(int percent);

  /// No description provided for @upgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your free closet is full'**
  String get upgradeTitle;

  /// No description provided for @upgradeBody.
  ///
  /// In en, this message translates to:
  /// **'The free plan holds {limit} items. Paid plans are coming soon. For now you can archive or delete items to make room.'**
  String upgradeBody(int limit);

  /// No description provided for @upgradeCta.
  ///
  /// In en, this message translates to:
  /// **'Manage my closet'**
  String get upgradeCta;

  /// No description provided for @limitReachedSnack.
  ///
  /// In en, this message translates to:
  /// **'Your closet is full ({limit} items).'**
  String limitReachedSnack(int limit);

  /// No description provided for @meterTitle.
  ///
  /// In en, this message translates to:
  /// **'Outfit potential'**
  String get meterTitle;

  /// No description provided for @meterOutfits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No outfits yet} =1{1 possible outfit} other{{count} possible outfits}}'**
  String meterOutfits(int count);

  /// No description provided for @meterLevelEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a top, a bottom and shoes to get started.'**
  String get meterLevelEmpty;

  /// No description provided for @meterLevelStarting.
  ///
  /// In en, this message translates to:
  /// **'A good start.'**
  String get meterLevelStarting;

  /// No description provided for @meterLevelGrowing.
  ///
  /// In en, this message translates to:
  /// **'Your closet is filling out.'**
  String get meterLevelGrowing;

  /// No description provided for @meterLevelRich.
  ///
  /// In en, this message translates to:
  /// **'Plenty to work with.'**
  String get meterLevelRich;

  /// No description provided for @meterNudge.
  ///
  /// In en, this message translates to:
  /// **'Add {item} to unlock {count, plural, =1{1 more outfit} other{{count} more outfits}}.'**
  String meterNudge(String item, int count);

  /// No description provided for @meterNudgeFootwear.
  ///
  /// In en, this message translates to:
  /// **'a pair of shoes'**
  String get meterNudgeFootwear;

  /// No description provided for @meterNudgeTop.
  ///
  /// In en, this message translates to:
  /// **'a top'**
  String get meterNudgeTop;

  /// No description provided for @meterNudgeBottom.
  ///
  /// In en, this message translates to:
  /// **'a bottom'**
  String get meterNudgeBottom;

  /// No description provided for @meterNudgeDress.
  ///
  /// In en, this message translates to:
  /// **'a dress'**
  String get meterNudgeDress;

  /// No description provided for @meterProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Closet progress, {percent} percent'**
  String meterProgressLabel(int percent);

  /// No description provided for @homeClosetCard.
  ///
  /// In en, this message translates to:
  /// **'My closet'**
  String get homeClosetCard;

  /// No description provided for @homeClosetCardBody.
  ///
  /// In en, this message translates to:
  /// **'Browse, add and edit your clothes.'**
  String get homeClosetCardBody;

  /// No description provided for @firstItemsAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add from photos'**
  String get firstItemsAddPhotos;

  /// No description provided for @firstItemsPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo is still being added} other{{count} photos are still being added}}'**
  String firstItemsPending(int count);

  /// No description provided for @firstItemsOpenCloset.
  ///
  /// In en, this message translates to:
  /// **'Open my closet'**
  String get firstItemsOpenCloset;

  /// No description provided for @taxCatTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get taxCatTop;

  /// No description provided for @taxSubTShirt.
  ///
  /// In en, this message translates to:
  /// **'T-shirt'**
  String get taxSubTShirt;

  /// No description provided for @taxSubLongSleeveTee.
  ///
  /// In en, this message translates to:
  /// **'Long-sleeve tee'**
  String get taxSubLongSleeveTee;

  /// No description provided for @taxSubShirt.
  ///
  /// In en, this message translates to:
  /// **'Shirt'**
  String get taxSubShirt;

  /// No description provided for @taxSubBlouse.
  ///
  /// In en, this message translates to:
  /// **'Blouse'**
  String get taxSubBlouse;

  /// No description provided for @taxSubPolo.
  ///
  /// In en, this message translates to:
  /// **'Polo'**
  String get taxSubPolo;

  /// No description provided for @taxSubSweater.
  ///
  /// In en, this message translates to:
  /// **'Sweater'**
  String get taxSubSweater;

  /// No description provided for @taxSubHoodie.
  ///
  /// In en, this message translates to:
  /// **'Hoodie'**
  String get taxSubHoodie;

  /// No description provided for @taxSubTankTop.
  ///
  /// In en, this message translates to:
  /// **'Tank top'**
  String get taxSubTankTop;

  /// No description provided for @taxSubCropTop.
  ///
  /// In en, this message translates to:
  /// **'Crop top'**
  String get taxSubCropTop;

  /// No description provided for @taxSubCardigan.
  ///
  /// In en, this message translates to:
  /// **'Cardigan'**
  String get taxSubCardigan;

  /// No description provided for @taxSubBodysuit.
  ///
  /// In en, this message translates to:
  /// **'Bodysuit'**
  String get taxSubBodysuit;

  /// No description provided for @taxCatBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get taxCatBottom;

  /// No description provided for @taxSubJeans.
  ///
  /// In en, this message translates to:
  /// **'Jeans'**
  String get taxSubJeans;

  /// No description provided for @taxSubTrousers.
  ///
  /// In en, this message translates to:
  /// **'Trousers'**
  String get taxSubTrousers;

  /// No description provided for @taxSubChinos.
  ///
  /// In en, this message translates to:
  /// **'Chinos'**
  String get taxSubChinos;

  /// No description provided for @taxSubShorts.
  ///
  /// In en, this message translates to:
  /// **'Shorts'**
  String get taxSubShorts;

  /// No description provided for @taxSubJoggers.
  ///
  /// In en, this message translates to:
  /// **'Joggers'**
  String get taxSubJoggers;

  /// No description provided for @taxSubLeggings.
  ///
  /// In en, this message translates to:
  /// **'Leggings'**
  String get taxSubLeggings;

  /// No description provided for @taxSubSkirt.
  ///
  /// In en, this message translates to:
  /// **'Skirt'**
  String get taxSubSkirt;

  /// No description provided for @taxCatOuterwear.
  ///
  /// In en, this message translates to:
  /// **'Outerwear'**
  String get taxCatOuterwear;

  /// No description provided for @taxSubJacket.
  ///
  /// In en, this message translates to:
  /// **'Jacket'**
  String get taxSubJacket;

  /// No description provided for @taxSubBlazer.
  ///
  /// In en, this message translates to:
  /// **'Blazer'**
  String get taxSubBlazer;

  /// No description provided for @taxSubSuitJacket.
  ///
  /// In en, this message translates to:
  /// **'Suit jacket'**
  String get taxSubSuitJacket;

  /// No description provided for @taxSubCoat.
  ///
  /// In en, this message translates to:
  /// **'Coat'**
  String get taxSubCoat;

  /// No description provided for @taxSubPuffer.
  ///
  /// In en, this message translates to:
  /// **'Puffer jacket'**
  String get taxSubPuffer;

  /// No description provided for @taxSubDenimJacket.
  ///
  /// In en, this message translates to:
  /// **'Denim jacket'**
  String get taxSubDenimJacket;

  /// No description provided for @taxSubRaincoat.
  ///
  /// In en, this message translates to:
  /// **'Raincoat'**
  String get taxSubRaincoat;

  /// No description provided for @taxSubVest.
  ///
  /// In en, this message translates to:
  /// **'Vest'**
  String get taxSubVest;

  /// No description provided for @taxCatFootwear.
  ///
  /// In en, this message translates to:
  /// **'Footwear'**
  String get taxCatFootwear;

  /// No description provided for @taxSubSneakers.
  ///
  /// In en, this message translates to:
  /// **'Sneakers'**
  String get taxSubSneakers;

  /// No description provided for @taxSubBoots.
  ///
  /// In en, this message translates to:
  /// **'Boots'**
  String get taxSubBoots;

  /// No description provided for @taxSubLoafers.
  ///
  /// In en, this message translates to:
  /// **'Loafers'**
  String get taxSubLoafers;

  /// No description provided for @taxSubSandals.
  ///
  /// In en, this message translates to:
  /// **'Sandals'**
  String get taxSubSandals;

  /// No description provided for @taxSubDressShoes.
  ///
  /// In en, this message translates to:
  /// **'Dress shoes'**
  String get taxSubDressShoes;

  /// No description provided for @taxSubHeels.
  ///
  /// In en, this message translates to:
  /// **'Heels'**
  String get taxSubHeels;

  /// No description provided for @taxSubFlats.
  ///
  /// In en, this message translates to:
  /// **'Flats'**
  String get taxSubFlats;

  /// No description provided for @taxCatDress.
  ///
  /// In en, this message translates to:
  /// **'Dress'**
  String get taxCatDress;

  /// No description provided for @taxSubCasualDress.
  ///
  /// In en, this message translates to:
  /// **'Casual dress'**
  String get taxSubCasualDress;

  /// No description provided for @taxSubCocktailDress.
  ///
  /// In en, this message translates to:
  /// **'Cocktail dress'**
  String get taxSubCocktailDress;

  /// No description provided for @taxSubMaxiDress.
  ///
  /// In en, this message translates to:
  /// **'Maxi dress'**
  String get taxSubMaxiDress;

  /// No description provided for @taxSubJumpsuit.
  ///
  /// In en, this message translates to:
  /// **'Jumpsuit'**
  String get taxSubJumpsuit;

  /// No description provided for @taxCatAccessory.
  ///
  /// In en, this message translates to:
  /// **'Accessory'**
  String get taxCatAccessory;

  /// No description provided for @taxSubHat.
  ///
  /// In en, this message translates to:
  /// **'Hat'**
  String get taxSubHat;

  /// No description provided for @taxSubScarf.
  ///
  /// In en, this message translates to:
  /// **'Scarf'**
  String get taxSubScarf;

  /// No description provided for @taxSubBelt.
  ///
  /// In en, this message translates to:
  /// **'Belt'**
  String get taxSubBelt;

  /// No description provided for @taxSubTie.
  ///
  /// In en, this message translates to:
  /// **'Tie'**
  String get taxSubTie;

  /// No description provided for @taxSubBag.
  ///
  /// In en, this message translates to:
  /// **'Bag'**
  String get taxSubBag;

  /// No description provided for @taxSubJewelry.
  ///
  /// In en, this message translates to:
  /// **'Jewelry'**
  String get taxSubJewelry;

  /// No description provided for @taxSubSunglasses.
  ///
  /// In en, this message translates to:
  /// **'Sunglasses'**
  String get taxSubSunglasses;

  /// No description provided for @taxSubWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get taxSubWatch;

  /// No description provided for @taxColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get taxColorBlack;

  /// No description provided for @taxColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get taxColorWhite;

  /// No description provided for @taxColorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get taxColorGrey;

  /// No description provided for @taxColorNavy.
  ///
  /// In en, this message translates to:
  /// **'Navy'**
  String get taxColorNavy;

  /// No description provided for @taxColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get taxColorBlue;

  /// No description provided for @taxColorLightBlue.
  ///
  /// In en, this message translates to:
  /// **'Light blue'**
  String get taxColorLightBlue;

  /// No description provided for @taxColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get taxColorTeal;

  /// No description provided for @taxColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get taxColorGreen;

  /// No description provided for @taxColorOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get taxColorOlive;

  /// No description provided for @taxColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get taxColorYellow;

  /// No description provided for @taxColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get taxColorOrange;

  /// No description provided for @taxColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get taxColorRed;

  /// No description provided for @taxColorBurgundy.
  ///
  /// In en, this message translates to:
  /// **'Burgundy'**
  String get taxColorBurgundy;

  /// No description provided for @taxColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get taxColorPink;

  /// No description provided for @taxColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get taxColorPurple;

  /// No description provided for @taxColorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get taxColorBrown;

  /// No description provided for @taxColorBeige.
  ///
  /// In en, this message translates to:
  /// **'Beige'**
  String get taxColorBeige;

  /// No description provided for @taxColorCream.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get taxColorCream;

  /// No description provided for @taxPatternSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get taxPatternSolid;

  /// No description provided for @taxPatternStriped.
  ///
  /// In en, this message translates to:
  /// **'Striped'**
  String get taxPatternStriped;

  /// No description provided for @taxPatternChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get taxPatternChecked;

  /// No description provided for @taxPatternFloral.
  ///
  /// In en, this message translates to:
  /// **'Floral'**
  String get taxPatternFloral;

  /// No description provided for @taxPatternPolkaDot.
  ///
  /// In en, this message translates to:
  /// **'Polka dot'**
  String get taxPatternPolkaDot;

  /// No description provided for @taxPatternGraphic.
  ///
  /// In en, this message translates to:
  /// **'Graphic'**
  String get taxPatternGraphic;

  /// No description provided for @taxPatternAnimalPrint.
  ///
  /// In en, this message translates to:
  /// **'Animal print'**
  String get taxPatternAnimalPrint;

  /// No description provided for @taxPatternCamouflage.
  ///
  /// In en, this message translates to:
  /// **'Camouflage'**
  String get taxPatternCamouflage;

  /// No description provided for @taxPatternOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get taxPatternOther;

  /// No description provided for @taxSeasonSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get taxSeasonSpring;

  /// No description provided for @taxSeasonSummer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get taxSeasonSummer;

  /// No description provided for @taxSeasonAutumn.
  ///
  /// In en, this message translates to:
  /// **'Autumn'**
  String get taxSeasonAutumn;

  /// No description provided for @taxSeasonWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get taxSeasonWinter;

  /// No description provided for @taxFitSlim.
  ///
  /// In en, this message translates to:
  /// **'Slim'**
  String get taxFitSlim;

  /// No description provided for @taxFitRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get taxFitRegular;

  /// No description provided for @taxFitRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get taxFitRelaxed;

  /// No description provided for @taxFitOversized.
  ///
  /// In en, this message translates to:
  /// **'Oversized'**
  String get taxFitOversized;

  /// No description provided for @taxMaterialCotton.
  ///
  /// In en, this message translates to:
  /// **'Cotton'**
  String get taxMaterialCotton;

  /// No description provided for @taxMaterialLinen.
  ///
  /// In en, this message translates to:
  /// **'Linen'**
  String get taxMaterialLinen;

  /// No description provided for @taxMaterialWool.
  ///
  /// In en, this message translates to:
  /// **'Wool'**
  String get taxMaterialWool;

  /// No description provided for @taxMaterialCashmere.
  ///
  /// In en, this message translates to:
  /// **'Cashmere'**
  String get taxMaterialCashmere;

  /// No description provided for @taxMaterialSilk.
  ///
  /// In en, this message translates to:
  /// **'Silk'**
  String get taxMaterialSilk;

  /// No description provided for @taxMaterialDenim.
  ///
  /// In en, this message translates to:
  /// **'Denim'**
  String get taxMaterialDenim;

  /// No description provided for @taxMaterialLeather.
  ///
  /// In en, this message translates to:
  /// **'Leather'**
  String get taxMaterialLeather;

  /// No description provided for @taxMaterialSuede.
  ///
  /// In en, this message translates to:
  /// **'Suede'**
  String get taxMaterialSuede;

  /// No description provided for @taxMaterialPolyester.
  ///
  /// In en, this message translates to:
  /// **'Polyester'**
  String get taxMaterialPolyester;

  /// No description provided for @taxMaterialNylon.
  ///
  /// In en, this message translates to:
  /// **'Nylon'**
  String get taxMaterialNylon;

  /// No description provided for @taxMaterialKnit.
  ///
  /// In en, this message translates to:
  /// **'Knit'**
  String get taxMaterialKnit;

  /// No description provided for @taxMaterialFleece.
  ///
  /// In en, this message translates to:
  /// **'Fleece'**
  String get taxMaterialFleece;

  /// No description provided for @taxMaterialOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get taxMaterialOther;

  /// No description provided for @taxFormality1.
  ///
  /// In en, this message translates to:
  /// **'Loungewear'**
  String get taxFormality1;

  /// No description provided for @taxFormality2.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get taxFormality2;

  /// No description provided for @taxFormality3.
  ///
  /// In en, this message translates to:
  /// **'Smart casual'**
  String get taxFormality3;

  /// No description provided for @taxFormality4.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get taxFormality4;

  /// No description provided for @taxFormality5.
  ///
  /// In en, this message translates to:
  /// **'Formal'**
  String get taxFormality5;
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
