import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/boot.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/presentation/sign_in_screen.dart';
import 'package:stylist/features/home/home_screen.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';
import 'package:stylist/features/onboarding/presentation/age_gate_screen.dart';
import 'package:stylist/features/onboarding/presentation/blocked_screen.dart';
import 'package:stylist/features/onboarding/presentation/quiz_screen.dart';
import 'package:stylist/features/onboarding/presentation/splash_screen.dart';
import 'package:stylist/features/onboarding/presentation/step_placeholder_screen.dart';
import 'package:stylist/features/onboarding/presentation/welcome_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const signIn = '/signin';
  static const blocked = '/blocked';
  static const home = '/home';
  static const resume = '/onboarding/resume';
}

/// Pure routing decision, unit-tested separately from widgets.
String? decideRedirect({
  required String location,
  required bool bootDone,
  required bool blocked,
  required SessionStatus session,
  required bool guestEnabled,
  required OnboardingState? onboarding,
}) {
  String go(String target) => location == target ? '' : target;
  String? result(String? r) => r == '' ? null : r;

  if (!bootDone) return result(go(Routes.splash));
  if (blocked) return result(go(Routes.blocked));
  if (session == SessionStatus.unknown) return result(go(Routes.splash));
  if (session == SessionStatus.signedOut) {
    if (location == Routes.signIn && !guestEnabled) return null;
    if (location == Routes.welcome && guestEnabled) return null;
    return result(go(guestEnabled ? Routes.welcome : Routes.signIn));
  }
  // Signed in from here.
  if (onboarding == null) return result(go(Routes.splash));
  if (onboarding.isDone) {
    final inFlow =
        location.startsWith('/onboarding') ||
        const {
          Routes.splash,
          Routes.welcome,
          Routes.signIn,
          Routes.blocked,
        }.contains(location);
    return inFlow ? Routes.home : null;
  }
  final target = onboarding.current.path;
  if (location == Routes.resume) return target;
  if (location.startsWith('/onboarding/')) {
    final step = OnboardingStep.tryParse(
      location.substring('/onboarding/'.length),
    );
    final idx = step == null ? -1 : onboarding.order.indexOf(step);
    // Earlier-or-current steps are fine; unknown or future steps snap to current.
    if (idx >= 0 && idx <= onboarding.currentIndex) return null;
  }
  return result(go(target));
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  late final GoRouter router;
  ref
    ..listen(bootProvider, (_, _) => refresh.notify())
    ..listen(sessionControllerProvider, (_, _) => refresh.notify())
    ..listen(onboardingControllerProvider, (prev, next) {
      refresh.notify();
      // Moving forward: navigate to the new current step.
      if (next != null &&
          !next.isDone &&
          prev != null &&
          prev.current != next.current &&
          next.currentIndex > prev.currentIndex) {
        router.go(next.current.path);
      }
    })
    ..listen(remoteConfigProvider, (_, _) => refresh.notify())
    ..onDispose(refresh.dispose);

  router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final boot = ref.read(bootProvider);
      final ctl = ref.read(onboardingControllerProvider.notifier);
      return decideRedirect(
        location: state.matchedLocation,
        bootDone: boot.hasValue,
        blocked: ctl.isBlocked,
        session: ref.read(sessionControllerProvider).status,
        guestEnabled:
            ref.read(remoteConfigProvider).valueOrNull?.guestModeEnabled ??
            true,
        onboarding: ref.read(onboardingControllerProvider),
      );
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.blocked, builder: (_, _) => const BlockedScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(path: Routes.resume, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: OnboardingStep.age.path,
        builder: (_, _) => const AgeGateScreen(),
      ),
      GoRoute(
        path: OnboardingStep.quiz.path,
        builder: (_, _) => const QuizScreen(),
      ),
      for (final s in const [
        OnboardingStep.basics,
        OnboardingStep.permissions,
        OnboardingStep.firstItems,
        OnboardingStep.firstOutfit,
        OnboardingStep.optional,
      ])
        GoRoute(
          path: s.path,
          builder: (_, _) => StepPlaceholderScreen(step: s),
        ),
    ],
  );
  return router;
});
