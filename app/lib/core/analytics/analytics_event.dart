/// Typed event taxonomy. Keep in sync with docs/analytics.md.
enum AnalyticsEvent {
  appFirstFrame('app_first_frame'),
  onboardingStarted('onboarding_started'),
  welcomeViewed('welcome_viewed'),
  guestStarted('guest_started'),
  signinStarted('signin_started'),
  signinCompleted('signin_completed'),
  ageConfirmed('age_confirmed'),
  quizQuestionAnswered('quiz_question_answered'),
  quizCompleted('quiz_completed'),
  basicsCompleted('basics_completed'),
  permissionPromptShown('permission_prompt_shown'),
  permissionGranted('permission_granted'),
  permissionDenied('permission_denied'),
  firstItemsProgress('first_items_progress'),
  firstOutfitViewed('first_outfit_viewed'),
  onboardingCompleted('onboarding_completed'),
  onboardingAbandoned('onboarding_abandoned'),
  accountDeleted('account_deleted'),
  dataExported('data_exported'),
  closetItemCaptureStarted('closet_item_capture_started'),
  closetItemUploaded('closet_item_uploaded'),
  closetItemAnalysed('closet_item_analysed'),
  closetItemCorrected('closet_item_corrected'),
  closetItemDeleted('closet_item_deleted'),
  closetBulkAddStarted('closet_bulk_add_started'),
  closetBulkAddCompleted('closet_bulk_add_completed'),
  closetFilterUsed('closet_filter_used'),
  closetLimitReached('closet_limit_reached'),
  closetMeterNudgeShown('closet_meter_nudge_shown')
  ;

  const AnalyticsEvent(this.wireName);
  final String wireName;
}
