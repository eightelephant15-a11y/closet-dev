# Analytics: onboarding funnel

Provider: PostHog (behind `AnalyticsService`). Events are defined once, as the typed
`AnalyticsEvent` enum in `app/lib/core/analytics/analytics_event.dart`. The test
`app/test/analytics_taxonomy_test.dart` fails if this file and the enum drift apart, or if an
event is never emitted by the app flows.

## Consent rules

* Analytics is **opt-in**. The question is asked once, right after the age confirmation, and can be
  changed any time under Settings → Privacy choices.
* Until the user decides, events are held **in memory only** (cap 200) and nothing is sent. Opt-in
  flushes them (so the funnel from `welcome_viewed` onwards is complete); opt-out discards them.
* Turning analytics off stops all events immediately. Sign-out returns the gate to "undecided".
* The decision is stored locally and on the server (`consents` table) with timestamp and policy version.
* We identify users by internal user id only: never email, name, city or photos. No event property
  contains free text.
* Crash reporting (Sentry) is separate: errors and traces only, `sendDefaultPii = false`.

## Events

| Event | Fired when | Properties |
|---|---|---|
| `app_first_frame` | First frame drawn after launch (once per process) | `ms` (main() to first frame), `flavor`, `within_budget` (<= 2000 ms) |
| `onboarding_started` | Onboarding state is created for a new user (after guest start or sign-in) | `variant` (`quiz_first`/`closet_first`) |
| `welcome_viewed` | Welcome screen shown | none |
| `guest_started` | "Try it first" tapped | none |
| `signin_started` | Google sign-in begins (welcome, sign-in screen, or guest upgrade) | `method` (`google`), `upgrade` (bool, only on upgrade) |
| `signin_completed` | Google sign-in succeeds | `method`, `upgrade` |
| `age_confirmed` | "I am 16 or older" confirmed | none |
| `quiz_question_answered` | A quiz answer is given or changed | `question` (`department`, `fit`, `colors`, `neverWear`, `dressCode`, `goals`), `index` (0-5) |
| `quiz_completed` | Finish tapped on the last question | `questions` (6) |
| `basics_completed` | Basics step submitted or skipped | `has_name` (bool), `units`, `has_city` (bool) |
| `permission_prompt_shown` | One of our priming screens appears | `permission` (`camera`, `photos`, `location`, `notifications`) |
| `permission_granted` | OS permission granted | `permission` |
| `permission_denied` | OS permission denied | `permission` |
| `first_items_progress` | Number of usable closet items changes | `count`, `unlocked` (bool) |
| `first_outfit_viewed` | First outfit shown (once) | `time_to_first_outfit_ms`, `variant`, `used_sample_closet` |
| `onboarding_completed` | Last step finished | `variant`, `duration_ms`, `time_to_first_outfit_ms` |
| `onboarding_abandoned` | App backgrounded/closed mid-onboarding (once per background trip) | `last_step`, `variant`, `elapsed_ms` |
| `account_deleted` | Deletion confirmed | none |
| `data_exported` | Export file shared | none |

### Time to first outfit

`time_to_first_outfit_ms` = time from `onboarding_started` to the first `first_outfit_viewed`
(measured with the device clock, counted once, also stored server-side in
`onboarding_state.time_to_first_outfit_ms`). It is reported on `first_outfit_viewed` and repeated on
`onboarding_completed`. Phase 1 target: **under 300000 ms (5 minutes)** at the 90th percentile.

## Funnel definition (PostHog)

1. `welcome_viewed`
2. `guest_started` **or** `signin_completed` (any of)
3. `age_confirmed`
4. `quiz_completed` (quiz_first) / `first_items_progress` with `unlocked = true` (closet_first)
5. `basics_completed`
6. `first_items_progress` with `unlocked = true`
7. `first_outfit_viewed`
8. `onboarding_completed`

Breakdowns: `variant` (A/B for `onboarding_variant`), platform. Drop-off per step = users with
`onboarding_abandoned` grouped by `last_step`. Permission opt-in rate =
`permission_granted / permission_prompt_shown` per `permission`.

## Adding an event

1. Add it to the `AnalyticsEvent` enum.
2. Document it in the table above (the taxonomy test checks the wire name appears here).
3. Emit it in application code (controllers), not widgets, and cover it in a test.
