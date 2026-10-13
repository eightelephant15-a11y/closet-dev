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
  /// **'Add with camera (coming soon)'**
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
