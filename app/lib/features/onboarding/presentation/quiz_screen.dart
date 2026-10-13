import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/l10n/labels.dart';
import 'package:stylist/shared/widgets/selectable_tile.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Six swipeable question cards (~60 seconds). Single-choice answers advance
/// automatically; every action also has an explicit Back / Next button so the
/// quiz never depends on gestures.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late final PageController _pages;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    final start = ref.read(onboardingControllerProvider)!.quizIndex;
    _pages = PageController(
      initialPage: start.clamp(0, QuizQuestion.values.length - 1),
    );
  }

  @override
  void dispose() {
    _advance?.cancel();
    _pages.dispose();
    super.dispose();
  }

  OnboardingController get _ctl =>
      ref.read(onboardingControllerProvider.notifier);

  void _goTo(int i) => unawaited(
    _pages.animateToPage(
      i,
      duration: MotionTokens.medium,
      curve: MotionTokens.curve,
    ),
  );

  void _answer(
    QuizQuestion q,
    QuizAnswers Function(QuizAnswers) change, {
    bool advance = false,
  }) {
    _ctl.answerQuiz(q, change);
    if (advance && q.index < QuizQuestion.values.length - 1) {
      _advance?.cancel();
      _advance = Timer(const Duration(milliseconds: 250), () {
        if (mounted) _goTo(q.index + 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(onboardingControllerProvider)!;
    final answers = state.quiz;
    final index = state.quizIndex.clamp(0, QuizQuestion.values.length - 1);
    final q = QuizQuestion.values[index];
    final total = QuizQuestion.values.length;
    final isLast = index == total - 1;
    return Scaffold(
      body: PageBody(
        child: Column(
          children: [
            Semantics(
              label: l10n.quizProgress(index + 1, total),
              child: LinearProgressIndicator(
                value: (index + 1) / total,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.quizProgress(index + 1, total),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: total,
                physics: answers.isAnswered(q)
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: _ctl.setQuizIndex,
                itemBuilder: (_, i) => _QuizCard(
                  question: QuizQuestion.values[i],
                  answers: answers,
                  onAnswer: _answer,
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                if (index > 0)
                  TextButton(
                    onPressed: () => _goTo(index - 1),
                    child: Text(l10n.back),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: answers.isAnswered(q)
                      ? (isLast ? _ctl.completeQuiz : () => _goTo(index + 1))
                      : null,
                  child: Text(isLast ? l10n.quizFinish : l10n.next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.question,
    required this.answers,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final QuizAnswers answers;
  final void Function(
    QuizQuestion,
    QuizAnswers Function(QuizAnswers), {
    bool advance,
  })
  onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hint = switch (question) {
      QuizQuestion.colors || QuizQuestion.goals => l10n.quizHintMulti,
      QuizQuestion.neverWear => l10n.quizHintNone,
      QuizQuestion.dressCode => l10n.quizDressCodeHint,
      _ => null,
    };
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.question(question),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: Spacing.xs),
            Text(hint, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: Spacing.md),
          ..._options(
            context,
            l10n,
          ).expand((w) => [w, const SizedBox(height: Spacing.sm)]),
        ],
      ),
    );
  }

  List<Widget> _options(BuildContext context, AppLocalizations l10n) {
    switch (question) {
      case QuizQuestion.department:
        return [
          for (final d in ClothingDepartment.values)
            SelectableTile(
              label: l10n.department(d),
              selected: answers.department == d,
              onTap: () => onAnswer(
                question,
                (a) => a.copyWith(department: d),
                advance: true,
              ),
            ),
        ];
      case QuizQuestion.fit:
        return [
          for (final f in Fit.values)
            SelectableTile(
              label: l10n.fit(f),
              selected: answers.fit == f,
              onTap: () =>
                  onAnswer(question, (a) => a.copyWith(fit: f), advance: true),
            ),
        ];
      case QuizQuestion.colors:
        return [
          for (final c in ClothingColor.values)
            SelectableTile(
              label: l10n.color(c),
              selected: answers.colors.contains(c),
              leading: _Swatch(color: c),
              onTap: () => onAnswer(
                question,
                (a) => a.copyWith(
                  colors: a.colors.contains(c)
                      ? ({...a.colors}..remove(c))
                      : {...a.colors, c},
                ),
              ),
            ),
        ];
      case QuizQuestion.neverWear:
        final chosen = answers.neverWear ?? const <NeverWear>{};
        return [
          for (final n in neverWearOptions(answers.department))
            SelectableTile(
              label: l10n.neverWear(n),
              selected: chosen.contains(n),
              onTap: () => onAnswer(
                question,
                (a) => a.copyWith(
                  neverWear: chosen.contains(n)
                      ? ({...chosen}..remove(n))
                      : {...chosen, n},
                ),
              ),
            ),
          SelectableTile(
            label: l10n.quizNoneOfThese,
            selected: answers.neverWear != null && answers.neverWear!.isEmpty,
            onTap: () =>
                onAnswer(question, (a) => a.copyWith(neverWear: <NeverWear>{})),
          ),
        ];
      case QuizQuestion.dressCode:
        return [
          for (var i = 0; i < dressCodeLevels; i++)
            SelectableTile(
              label: l10n.dressCode(i),
              selected: answers.dressCode == i,
              onTap: () => onAnswer(
                question,
                (a) => a.copyWith(dressCode: i),
                advance: true,
              ),
            ),
        ];
      case QuizQuestion.goals:
        final chosen = answers.goals ?? const <Goal>{};
        return [
          for (final g in Goal.values)
            SelectableTile(
              label: l10n.goal(g),
              selected: chosen.contains(g),
              onTap: () => onAnswer(
                question,
                (a) => a.copyWith(
                  goals: chosen.contains(g)
                      ? ({...chosen}..remove(g))
                      : {...chosen, g},
                ),
              ),
            ),
        ];
    }
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});
  final ClothingColor color;

  static const Map<ClothingColor, Color> _values = {
    ClothingColor.black: Color(0xFF111111),
    ClothingColor.white: Color(0xFFFFFFFF),
    ClothingColor.grey: Color(0xFF9E9E9E),
    ClothingColor.navy: Color(0xFF1B2A55),
    ClothingColor.beige: Color(0xFFD9C7A3),
    ClothingColor.brown: Color(0xFF6B4A32),
    ClothingColor.olive: Color(0xFF6B6B2F),
    ClothingColor.red: Color(0xFFD32F2F),
    ClothingColor.pink: Color(0xFFF48FB1),
    ClothingColor.blue: Color(0xFF1976D2),
    ClothingColor.green: Color(0xFF388E3C),
    ClothingColor.yellow: Color(0xFFFBC02D),
    ClothingColor.purple: Color(0xFF7B1FA2),
    ClothingColor.orange: Color(0xFFF57C00),
  };

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _values[color],
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    ),
  );
}
