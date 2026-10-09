import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/extended_controller.dart';
import 'hub_screens.dart';
import 'max_screen.dart';

const _superInk = Color(0xFF0C1149);
const _superAccent = Color(0xFF20ED88);
const _superGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0A484C), Color(0xFF122D79), Color(0xFF531972)],
);
const _superLogo = ArtRegion('super-07', Rect.fromLTWH(880, 220, 250, 74));
const _superDuo = ArtRegion('super-07', Rect.fromLTWH(430, 153, 320, 493));

class SuperScreen extends ConsumerStatefulWidget {
  const SuperScreen({super.key});
  @override
  ConsumerState<SuperScreen> createState() => _SuperState();
}

class _SuperState extends ConsumerState<SuperScreen> {
  int step = 0;
  bool allPlans = false;
  bool reminder = true;
  void next() => setState(() => step++);
  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(extendedControllerProvider).selectedPlan;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _superGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: step == 0 ? 'Close' : 'Back',
                      onPressed: () {
                        if (step == 0) {
                          context.canPop()
                              ? context.pop()
                              : context.go('/home');
                        } else {
                          setState(() => step--);
                        }
                      },
                      icon: Icon(
                        step == 0
                            ? Icons.close_rounded
                            : Icons.arrow_back_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const ReferenceArt(_superLogo, width: 84, height: 25),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: motionDuration(context, 220),
                  child: ListView(
                    key: ValueKey(step),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      if (step == 0) ...[
                        const SizedBox(height: 35),
                        _title(
                          'Progress faster in your\nEnglish course with Super!',
                        ),
                        const SizedBox(height: 35),
                        const Row(
                          children: [
                            Expanded(flex: 2, child: SizedBox()),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'FREE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: ReferenceArt(
                                  _superLogo,
                                  width: 74,
                                  height: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        for (final label in const [
                          'Learning content',
                          'Unlimited energy',
                          'No ads',
                          'Unlimited practice',
                          'Unlimited Legendary',
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Icon(
                                    label == 'Learning content'
                                        ? Icons.check_rounded
                                        : Icons.remove_rounded,
                                    color: label == 'Learning content'
                                        ? Colors.white
                                        : const Color(0xFF576BB1),
                                  ),
                                ),
                                const Expanded(
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else if (step == 1) ...[
                        const SizedBox(height: 25),
                        _title('Try Super free for 7 days'),
                        const SizedBox(height: 28),
                        const Center(
                          child: ReferenceArt(
                            _superDuo,
                            width: 145,
                            height: 223,
                          ),
                        ),
                        const SizedBox(height: 25),
                        const _TrialRow(
                          icon: Icons.lock_open_rounded,
                          title: 'Today',
                          subtitle: 'Unlock all Super features.',
                        ),
                        const _TrialRow(
                          icon: Icons.notifications_active_outlined,
                          title: 'Day 5',
                          subtitle: 'We’ll remind you before your trial ends.',
                        ),
                        const _TrialRow(
                          icon: Icons.star_rounded,
                          title: 'Day 7',
                          subtitle: 'Your trial ends. Cancel anytime.',
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Free trial reminder',
                            style: TextStyle(color: Colors.white, fontSize: 19),
                          ),
                          value: reminder,
                          onChanged: (value) =>
                              setState(() => reminder = value),
                          activeThumbColor: _superAccent,
                        ),
                      ] else ...[
                        const Center(
                          child: ReferenceArt(
                            _superDuo,
                            width: 110,
                            height: 169,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _title('Get started with a 7 day free trial on Super'),
                        const SizedBox(height: 26),
                        for (final plan in const [
                          (
                            'family',
                            'Family Plan',
                            '12 mo • \$119.99',
                            '\$9.99 / MO',
                          ),
                          (
                            'individual',
                            'Individual',
                            '12 mo • \$95.99',
                            '\$7.99 / MO',
                          ),
                          (
                            'monthly',
                            'Monthly',
                            '1 mo • \$12.99',
                            '\$12.99 / MO',
                          ),
                        ])
                          if (plan.$1 != 'monthly' || allPlans) ...[
                            Semantics(
                              selected: selected == plan.$1,
                              button: true,
                              child: InkWell(
                                onTap: () => ref
                                    .read(extendedControllerProvider.notifier)
                                    .choosePlan(plan.$1),
                                borderRadius: BorderRadius.circular(17),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .06),
                                    border: Border.all(
                                      color: selected == plan.$1
                                          ? const Color(0xFF53B0FF)
                                          : const Color(0xFF4568A5),
                                      width: selected == plan.$1 ? 3 : 2,
                                    ),
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (plan.$1 == 'individual')
                                        const Text(
                                          'MOST POPULAR',
                                          style: TextStyle(
                                            color: _superAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              plan.$2,
                                              style: headingStyle.copyWith(
                                                color: Colors.white,
                                                fontSize: 25,
                                              ),
                                            ),
                                          ),
                                          if (selected == plan.$1)
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF53B0FF),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Wrap(
                                        spacing: 20,
                                        children: [
                                          Text(
                                            plan.$3,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            plan.$4,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        TextButton(
                          onPressed: () => setState(() => allPlans = !allPlans),
                          child: Text(
                            allPlans ? 'FEWER PLANS' : 'VIEW ALL PLANS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Text(
                          'Cancel anytime in the App Store',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Choose your plan and keep learning with Super Duolingo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFCACBE5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: ReferenceButton(
                  label: 'START MY FREE WEEK',
                  backgroundColor: Colors.white,
                  edgeColor: const Color(0xFF9A90B4),
                  foregroundColor: _superInk,
                  onPressed: step < 2
                      ? next
                      : selected == null
                      ? null
                      : () => _confirm(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 27,
      height: 1.3,
    ),
  );
  Future<void> _confirm(BuildContext context) => learningSheet<void>(
    context,
    title: 'Try Super',
    child: Column(
      children: [
        const Text(
          'Continue with your selected plan?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 22),
        ReferenceButton(
          label: 'START FREE TRIAL',
          onPressed: () {
            ref.read(extendedControllerProvider.notifier).confirmPlan();
            Navigator.pop(context);
            context.pushReplacement('/super/tour');
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('NOT NOW'),
        ),
      ],
    ),
  );
}

class _TrialRow extends StatelessWidget {
  const _TrialRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Icon(icon, size: 30, color: _superAccent),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 17, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SuperTourScreen extends StatefulWidget {
  const SuperTourScreen({super.key});
  @override
  State<SuperTourScreen> createState() => _SuperTourState();
}

class _SuperTourState extends State<SuperTourScreen> {
  int step = 0;
  static const pages = [
    (
      'Enjoy continuous learning with ad-free lessons',
      'super-11',
      Rect.fromLTWH(45, 1047, 1135, 1168),
    ),
    (
      'Target weak areas and review mistakes in the Practice Hub',
      'super-12',
      Rect.fromLTWH(45, 1075, 1050, 1140),
    ),
    (
      'Your 7-day free trial has started!',
      'super-13',
      Rect.fromLTWH(340, 1280, 510, 480),
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: _superGradient),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LinearProgressIndicator(
                value: (step + 1) / 3,
                minHeight: 12,
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF625CFF),
                backgroundColor: const Color(0xFF24137F),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 34),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        pages[step].$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    ReferenceArt(
                      ArtRegion(pages[step].$2, pages[step].$3),
                      width: step == 2 ? 175 : 335,
                      height: step == 2 ? 165 : 347,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: ReferenceButton(
                label: step == 2 ? 'LET’S GO' : 'MORE',
                backgroundColor: Colors.white,
                edgeColor: const Color(0xFF9A90B4),
                foregroundColor: _superInk,
                onPressed: () =>
                    step == 2 ? context.go('/home') : setState(() => step++),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(extendedControllerProvider);
    return PreviewPage(
      title: 'Manage subscription',
      children: [
        const SizedBox(height: 20),
        Center(
          child: ReferenceArt(
            state.isMax ? maxDuo : _superDuo,
            width: 115,
            height: 177,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          state.isMax
              ? 'Duolingo Max'
              : state.unlimited
              ? 'Super Duolingo'
              : 'No active plan',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 12),
        Text(
          state.isFamily
              ? 'Family Plan • up to 6 people'
              : state.plan == 'monthly'
              ? 'Individual Monthly'
              : state.unlimited
              ? 'Individual Annual'
              : 'Try all Super features.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19),
        ),
        const SizedBox(height: 26),
        if (state.isFamily) ...[
          ReferenceButton(
            label: 'MANAGE FAMILY',
            onPressed: () => context.push('/subscription/family'),
          ),
          const SizedBox(height: 16),
        ],
        ReferenceButton(
          label: state.unlimited ? 'CHANGE PLAN' : 'EXPLORE SUPER',
          outlined: true,
          onPressed: () => context.push(state.isMax ? '/max' : '/super'),
        ),
        const SizedBox(height: 24),
        LearningCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Max', style: headingStyle)),
                  const ReferenceArt(maxDuo, width: 70, height: 80),
                ],
              ),
              const Text(
                'Speak English with confidence',
                style: TextStyle(fontSize: 19),
              ),
              const SizedBox(height: 12),
              for (final feature in const [
                'Video Call with Lily',
                'Roleplay',
                'Explain My Answer',
                'Unlimited energy',
                'No ads',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded, color: Color(0xFF6514C9)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ReferenceButton(
                label: state.isMax ? 'EXPLORE MAX' : 'UPGRADE TO MAX',
                outlined: true,
                foregroundColor: const Color(0xFF6514C9),
                onPressed: () => context.push('/max'),
              ),
            ],
          ),
        ),
        if (state.unlimited) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push('/subscription/cancel'),
            child: const Text(
              'CANCEL SUBSCRIPTION',
              style: TextStyle(
                color: LearningColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        const Text(
          'Enjoy unlimited learning with Super Duolingo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: ReferenceColors.muted),
        ),
      ],
    );
  }
}

class CancelSubscriptionScreen extends ConsumerStatefulWidget {
  const CancelSubscriptionScreen({super.key});
  @override
  ConsumerState<CancelSubscriptionScreen> createState() =>
      _CancelSubscriptionState();
}

class _CancelSubscriptionState extends ConsumerState<CancelSubscriptionScreen> {
  String? reason;
  bool cancelled = false;
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: cancelled ? 'Subscription cancelled' : 'Before you go',
    children: [
      const SizedBox(height: 24),
      Text(
        cancelled ? 'Your plan is cancelled.' : 'Why are you cancelling?',
        style: headingStyle,
      ),
      const SizedBox(height: 16),
      if (!cancelled) ...[
        for (final option in const [
          'Too expensive',
          'Not using it enough',
          'Technical issues',
          'Other',
        ])
          ListTile(
            title: Text(option, style: const TextStyle(fontSize: 19)),
            leading: Icon(
              reason == option
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: reason == option
                  ? LearningColors.blue
                  : ReferenceColors.disabled,
            ),
            onTap: () => setState(() => reason = option),
          ),
        const SizedBox(height: 24),
        ReferenceButton(
          label: ref.watch(extendedControllerProvider).isMax
              ? 'KEEP MAX'
              : 'KEEP SUPER',
          onPressed: () => context.pop(),
        ),
        const SizedBox(height: 18),
        ReferenceButton(
          label: 'CONFIRM CANCELLATION',
          outlined: true,
          foregroundColor: LearningColors.red,
          onPressed: reason == null
              ? null
              : () {
                  ref
                      .read(extendedControllerProvider.notifier)
                      .cancelPlan(reason);
                  setState(() => cancelled = true);
                },
        ),
      ] else
        ReferenceButton(label: 'DONE', onPressed: () => context.pop()),
    ],
  );
}

class FamilyPlanScreen extends ConsumerStatefulWidget {
  const FamilyPlanScreen({super.key});
  @override
  ConsumerState<FamilyPlanScreen> createState() => _FamilyPlanState();
}

class _FamilyPlanState extends ConsumerState<FamilyPlanScreen> {
  final input = TextEditingController();
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extendedControllerProvider);
    return PreviewPage(
      title: 'Family Plan',
      children: [
        const SizedBox(height: 15),
        Center(
          child: ReferenceArt(
            state.isMax ? maxFamilyArt : _superDuo,
            width: state.isMax ? 230 : 110,
            height: state.isMax ? 150 : 169,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Learning is better together!',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 18),
        Text(
          '${state.invited.length + 1} of 6 spaces filled',
          style: const TextStyle(fontSize: 19, color: ReferenceColors.muted),
        ),
        const ListTile(
          leading: Icon(Icons.person, color: LearningColors.blue),
          title: Text('You'),
          trailing: Text('Manager'),
        ),
        for (final person in state.invited)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(person),
            trailing: const Text('Invited'),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: input,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Invite a family member',
            hintText: 'Name',
          ),
        ),
        if (error != null)
          Text(
            error!,
            style: const TextStyle(color: LearningColors.red, fontSize: 16),
          ),
        const SizedBox(height: 16),
        ReferenceButton(
          label: 'INVITE',
          onPressed: () {
            final result = ref
                .read(extendedControllerProvider.notifier)
                .invite(input.text);
            setState(() => error = result);
            if (result == null) input.clear();
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Invite your family to learn together.',
          style: TextStyle(fontSize: 15, color: ReferenceColors.muted),
        ),
      ],
    );
  }
}
