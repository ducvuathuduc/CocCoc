import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/extended_controller.dart';
import '../application/max_controller.dart';

const _purple = Color(0xFFCE82F2), _maxInk = Color(0xFF170C49);
const _maxGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF35105D), Color(0xFF240A2F), Colors.black],
  stops: [0, .16, .40],
);
const maxLogo = ArtRegion('max-individual', Rect.fromLTWH(922, 218, 216, 78));
const maxDuo = ArtRegion('max-individual', Rect.fromLTWH(304, 287, 582, 380));
const maxFamilyArt = ArtRegion('max-family', Rect.fromLTWH(270, 555, 635, 416));
const maxAppIcon = ArtRegion('max-icon', Rect.fromLTWH(444, 1125, 302, 315));
const _featureIcons = [
  ArtRegion('max-offer', Rect.fromLTWH(100, 1380, 147, 130)),
  ArtRegion('max-offer', Rect.fromLTWH(105, 1590, 150, 136)),
  ArtRegion('max-offer', Rect.fromLTWH(103, 1815, 155, 138)),
  ArtRegion('max-features', Rect.fromLTWH(100, 448, 149, 130)),
  ArtRegion('max-features', Rect.fromLTWH(100, 655, 150, 137)),
  ArtRegion('max-features', Rect.fromLTWH(110, 859, 140, 144)),
];
void _close(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/home');
Widget _title(String before, String accent, [String after = '']) => Text.rich(
  TextSpan(
    children: [
      TextSpan(text: before),
      TextSpan(
        text: accent,
        style: const TextStyle(color: _purple),
      ),
      TextSpan(text: after),
    ],
  ),
  textAlign: TextAlign.center,
  style: const TextStyle(
    color: Colors.white,
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.35,
  ),
);
Widget _whiteButton(String label, VoidCallback? action) => ReferenceButton(
  label: label,
  onPressed: action,
  backgroundColor: Colors.white,
  edgeColor: const Color(0xFFCCCCCC),
  foregroundColor: _maxInk,
);

class MaxScreen extends ConsumerWidget {
  const MaxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(maxControllerProvider),
        vm = ref.read(maxControllerProvider.notifier);
    final offer = s.stage == MaxStage.offer;
    final enabled = s.stage != MaxStage.reminder || s.reminderDays != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: offer ? null : _maxGradient,
          color: offer ? Colors.black : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    if (!offer)
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () {
                          if (!vm.back()) _close(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      )
                    else
                      const SizedBox(height: 48),
                    const Spacer(),
                    const ReferenceArt(maxLogo, width: 70, height: 25),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(s.stage),
                  child: Padding(
                    padding: EdgeInsets.only(top: offer ? 10 : 62),
                    child: switch (s.stage) {
                      MaxStage.offer => const _MaxOffer(),
                      MaxStage.comparison => const _MaxComparison(),
                      MaxStage.reminder => _MaxReminder(
                        state: s,
                        onPick: vm.chooseReminder,
                      ),
                      MaxStage.plans => _MaxPlans(
                        state: s,
                        onPick: vm.choosePlan,
                      ),
                    },
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: offer ? Colors.white : null,
                  border: offer
                      ? const Border(
                          top: BorderSide(
                            color: ReferenceColors.border,
                            width: 2,
                          ),
                        )
                      : null,
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.stage == MaxStage.reminder ||
                        s.stage == MaxStage.plans) ...[
                      Text(
                        s.stage == MaxStage.plans
                            ? 'Local trial preview • no payment'
                            : 'Easy to cancel, no penalties or fees',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (offer)
                      ReferenceButton(
                        label: 'TRY FOR \$0.00',
                        backgroundColor: const Color(0xFF6514C9),
                        edgeColor: const Color(0xFF410B88),
                        onPressed: vm.next,
                      )
                    else
                      _whiteButton(
                        'START MY FREE WEEK',
                        enabled
                            ? () {
                                if (s.stage == MaxStage.plans) {
                                  _checkout(context, ref);
                                } else {
                                  vm.next();
                                }
                              }
                            : null,
                      ),
                    if (offer)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextButton(
                          onPressed: () => _close(context),
                          child: const Text(
                            'NO THANKS',
                            style: TextStyle(
                              color: Color(0xFF6514C9),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFEDEDEF),
      builder: (sheetContext) {
        final plan = ref.read(maxControllerProvider).selectedPlan;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Mock checkout', style: headingStyle),
                    ),
                    IconButton(
                      tooltip: 'Close checkout',
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const ReferenceArt(maxAppIcon, width: 50, height: 52),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              plan == 'max-family'
                                  ? 'Duolingo Max Family'
                                  : 'Duolingo Max',
                              style: headingStyle.copyWith(fontSize: 22),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      const Text('1-week free trial', style: headingStyle),
                      const Text(
                        'Starting today',
                        style: TextStyle(
                          color: ReferenceColors.muted,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        plan == 'max-family'
                            ? '\$239.99 per year'
                            : '\$167.99 per year',
                        style: headingStyle,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This confirmation changes only your local preview. No App Store purchase, renewal or charge.',
                        style: TextStyle(fontSize: 17, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ReferenceButton(
                  label: 'CONFIRM PREVIEW',
                  backgroundColor: LearningColors.blue,
                  edgeColor: LearningColors.blueDark,
                  onPressed: () => Navigator.pop(sheetContext, true),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted || confirmed != true) return;
    if (!ref.read(maxControllerProvider.notifier).confirmCheckout()) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('You’re all set.'),
        content: const Text('Your local preview is ready.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (context.mounted) context.pushReplacement('/max/tour');
  }
}

class _MaxOffer extends StatelessWidget {
  const _MaxOffer();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _OfferTitle(),
      ),
      const SizedBox(height: 22),
      const ReferenceArt(
        ArtRegion('max-offer', Rect.fromLTWH(0, 580, 1179, 682)),
        width: 390,
        height: 226,
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(28, 28, 20, 32),
        child: Column(
          children: [
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ReferenceArt(_featureIcons[i], width: 45, height: 45),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: const [
                                'Video Call',
                                'Explain My Answer',
                                'Roleplay',
                                'Unlimited energy',
                                'Personalized Practice',
                                'No ads',
                              ][i],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: const [
                                ' for low-stress speaking practice',
                                ' for personalized feedback',
                                ' to prepare for real-world scenarios',
                                '',
                                ' to target your weak areas',
                                '',
                              ][i],
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 21,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const ReferenceArt(
              ArtRegion('max-features', Rect.fromLTWH(258, 1150, 785, 478)),
              width: 290,
              height: 177,
            ),
            const SizedBox(height: 20),
            const Text(
              'Cancel anytime, no penalties or fees',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OfferTitle extends StatelessWidget {
  const _OfferTitle();
  @override
  Widget build(BuildContext context) =>
      _title('', 'Speak English', ' with confidence\non Duolingo Max');
}

class _MaxComparison extends StatelessWidget {
  const _MaxComparison();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      children: [
        _title('Unlock ', 'deeper learning', ' with\nDuolingo Max'),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(flex: 5, child: SizedBox()),
            const Expanded(
              flex: 2,
              child: Text(
                'FREE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF38213F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Center(
                  child: ReferenceArt(maxLogo, width: 58, height: 21),
                ),
              ),
            ),
          ],
        ),
        for (final label in const [
          'Learning content',
          'Video Call',
          'Unlimited energy',
          'No ads',
          'Roleplay',
          'Explain My Answer',
          'Personalized Practice',
        ])
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Icon(
                  label == 'Learning content'
                      ? Icons.check_rounded
                      : Icons.remove_rounded,
                  color: const Color(0xFF66616B),
                  size: 26,
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  color: const Color(0x443D294C),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 25),
      ],
    ),
  );
}

class _MaxReminder extends StatelessWidget {
  const _MaxReminder({required this.state, required this.onPick});
  final MaxState state;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        _title(
          state.reminderDays == null
              ? 'When should we remind you\nbefore your trial ends?'
              : 'We’ll remind you ',
          state.reminderDays == null ? '' : '${state.reminderDays} days',
          state.reminderDays == null ? '' : ' before\nyour trial ends',
        ),
        const SizedBox(height: 30),
        ReferenceArt(
          ArtRegion(
            state.reminderDays == null
                ? 'max-reminder-choice'
                : 'max-reminder-selected',
            state.reminderDays == null
                ? const Rect.fromLTWH(325, 925, 545, 436)
                : const Rect.fromLTWH(325, 850, 570, 520),
          ),
          width: 230,
          height: 220,
        ),
        const SizedBox(height: 26),
        for (final days in [2, 3]) ...[
          _DarkChoice(
            label: '$days days before',
            detail: 'Day ${7 - days}',
            selected: state.reminderDays == days,
            onTap: () => onPick(days),
          ),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}

class _MaxPlans extends StatelessWidget {
  const _MaxPlans({required this.state, required this.onPick});
  final MaxState state;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        ReferenceArt(
          state.selectedPlan == 'max-family' ? maxFamilyArt : maxDuo,
          width: 230,
          height: 150,
        ),
        const SizedBox(height: 20),
        state.selectedPlan == 'max-family'
            ? _title(
                'Save up to 76% with Family\nPlan after your ',
                '7 day free trial',
              )
            : _title('Get started with a ', '7 day free trial', ' on Max'),
        const SizedBox(height: 28),
        _DarkChoice(
          label: 'Family Plan',
          detail: '\$19.99 / MO',
          subtitle: '12 mo • \$239.99',
          badge: '2–6 MEMBERS',
          selected: state.selectedPlan == 'max-family',
          onTap: () => onPick('max-family'),
        ),
        const SizedBox(height: 16),
        _DarkChoice(
          label: 'Individual',
          detail: '\$13.99 / MO',
          subtitle: '12 mo • \$167.99',
          badge: 'MOST POPULAR',
          selected: state.selectedPlan == 'max-individual',
          onTap: () => onPick('max-individual'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Archived reference prices. Local preview only.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

class _DarkChoice extends StatelessWidget {
  const _DarkChoice({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.badge,
  });
  final String label, detail;
  final String? subtitle, badge;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF251037),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _purple : const Color(0xFF49315A),
            width: selected ? 4 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFF9452D0)
                  : const Color(0xFF473153),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: const BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 15,
                    runSpacing: 8,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle,
                          color: _purple,
                          size: 25,
                        ),
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MaxTourScreen extends ConsumerWidget {
  const MaxTourScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(maxControllerProvider),
        vm = ref.read(maxControllerProvider.notifier);
    final family = ref.watch(extendedControllerProvider).isFamily;
    final p = s.tourStep - (family ? 1 : 0);
    final welcome = s.tourStep < 0 || s.tourComplete;
    final invite = !welcome && family && s.tourStep == 0;
    final complete = !welcome && p >= 5;
    final titles = [
      ('Practice ', 'speaking', '\nin Video Calls with Lily'),
      ('Get ', 'personalized explanations', '\nfor your English answers'),
      ('Prepare for ', 'real-world situations', '\nwith Roleplay'),
      ('Get ', 'Unlimited energy', ', no ads,\nand all the benefits of Super'),
      ('Turn on your ', 'Max App icon', ' to\nshow off your new Duo!'),
    ];
    final art = switch (p) {
      0 => const ArtRegion('max-call', Rect.fromLTWH(180, 1180, 999, 1030)),
      3 => const ArtRegion('max-benefits', Rect.fromLTWH(185, 1080, 994, 1125)),
      _ => maxAppIcon,
    };
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _maxGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: welcome
                    ? const Align(
                        alignment: Alignment.centerRight,
                        child: ReferenceArt(maxLogo, width: 70, height: 25),
                      )
                    : _TourProgress(total: family ? 6 : 5, step: s.tourStep),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(s.tourStep),
                  padding: const EdgeInsets.fromLTRB(16, 65, 16, 24),
                  child: Column(
                    children: [
                      if (welcome) ...[
                        _title(
                          '',
                          'Speak English',
                          ' with confidence\non Duolingo Max${family ? ' Family' : ''}',
                        ),
                        const SizedBox(height: 40),
                        const ReferenceArt(
                          ArtRegion(
                            'max-welcome',
                            Rect.fromLTWH(80, 910, 930, 1010),
                          ),
                          width: 330,
                          height: 358,
                        ),
                      ] else if (invite) ...[
                        _title(
                          'Invite friends and family to\n',
                          'learn together!',
                        ),
                        const SizedBox(height: 60),
                        const ReferenceArt(
                          ArtRegion(
                            'max-invite',
                            Rect.fromLTWH(175, 1200, 820, 545),
                          ),
                          width: 320,
                          height: 213,
                        ),
                      ] else if (complete) ...[
                        _title('Your ', '7-day trial preview', ' is ready!'),
                        const SizedBox(height: 20),
                        Text(
                          'Reminder selected: ${s.reminderDays ?? 2} days before it ends.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const ReferenceArt(
                          ArtRegion(
                            'max-complete',
                            Rect.fromLTWH(380, 1265, 475, 535),
                          ),
                          width: 200,
                          height: 225,
                        ),
                      ] else ...[
                        _title(titles[p].$1, titles[p].$2, titles[p].$3),
                        SizedBox(height: p == 0 ? 170 : 40),
                        if (p == 1 || p == 2) ...[
                          ReferenceArt(
                            _featureIcons[p],
                            width: 135,
                            height: 135,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            p == 1
                                ? 'Review grammar, vocabulary and examples after each answer.'
                                : 'Order food, plan a trip and build confidence in everyday conversations.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.4,
                            ),
                          ),
                        ] else if (p == 4)
                          Container(
                            width: 240,
                            padding: const EdgeInsets.symmetric(
                              vertical: 30,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: _purple, width: 4),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                const ReferenceArt(
                                  maxAppIcon,
                                  width: 105,
                                  height: 110,
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Max App Icon',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Semantics(
                                  label: 'Max App Icon preview',
                                  child: Switch(
                                    value: s.appIcon,
                                    onChanged: vm.setAppIcon,
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: _purple,
                                    inactiveTrackColor: const Color(0xFF542F9A),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ReferenceArt(
                            art,
                            width: 330,
                            height: p == 0 ? 340 : 370,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _whiteButton(
                      welcome || complete
                          ? 'LET’S GO'
                          : invite
                          ? 'INVITE MEMBERS'
                          : 'NEXT',
                      () {
                        if (complete) {
                          vm.finishTour();
                          context.go('/home');
                        } else {
                          vm.advanceTour();
                          if (invite) context.push('/subscription/family');
                        }
                      },
                    ),
                    if (invite)
                      TextButton(
                        onPressed: vm.advanceTour,
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourProgress extends StatelessWidget {
  const _TourProgress({required this.total, required this.step});
  final int total, step;
  @override
  Widget build(BuildContext context) => Semantics(
    label: step >= total
        ? 'Max tour complete'
        : 'Max tour, step ${step + 1} of $total',
    excludeSemantics: true,
    child: SizedBox(
      height: 32,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final first = total == 6 ? 44.0 : 58.0;
          final stride = (bounds.maxWidth - first - 12) / total;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF542F9A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                width: first + stride * step.clamp(0, total),
                top: 8,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFA568E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              for (var i = 0; i <= total; i++)
                Positioned(
                  left: first + stride * i - (i == step ? 16 : 12),
                  top: i == step ? 0 : 4,
                  child: Container(
                    width: i == step ? 32 : 24,
                    height: i == step ? 32 : 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= step ? _purple : const Color(0xFF542F9A),
                      border: i == step
                          ? Border.all(color: const Color(0xFF995BC8), width: 2)
                          : null,
                    ),
                    child: i == total
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 19,
                          )
                        : Text(
                            '${i + 1}',
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
