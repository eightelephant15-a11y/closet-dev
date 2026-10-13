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
}
