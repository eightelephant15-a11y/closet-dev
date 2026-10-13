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
