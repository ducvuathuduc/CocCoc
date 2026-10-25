import 'super_trial_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../billing/application/billing_controller.dart';
import '../../billing/domain/billing_models.dart';
import '../../billing/presentation/billing_checkout.dart';
import '../../learning/presentation/learning_path.dart';
import '../application/android_super_controller.dart';
import '../application/super_access_reminder.dart';

const _ink = Color(0xFF000433);
const _green = Color(0xFF67DE96);
const _badge = ArtRegion('android-super-02', Rect.fromLTWH(266, 58, 79, 25));

/// Native Android layouts traced to Mobbin Super 01–05. Product prices and
/// access dates come from this app, with explicit simulation labeling.
class AndroidSuperFlow extends ConsumerWidget {
  const AndroidSuperFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(androidSuperControllerProvider);
    final vm = ref.read(androidSuperControllerProvider.notifier);
    final reminder = ref.watch(superAccessReminderProvider);
    return PopScope(
      canPop: !s.busy && s.step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !s.busy) vm.back();
      },
      child: Scaffold(
        backgroundColor: _ink,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/reference_art/android-super-gradient.png',
              ),
              fit: BoxFit.fill,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Super 01 has an empty header (NO THANKS and system back
                // exit); later steps show close/back and the SUPER badge.
                if (s.step == 0)
                  const SizedBox(height: 48)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: s.step == 0 ? 'Close' : 'Back',
                          onPressed: s.busy
                              ? null
                              : () {
                                  if (s.step > 0) {
                                    vm.back();
                                  } else if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/home');
                                  }
                                },
                          icon: Icon(
                            s.step == 0 ? Icons.close : Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const ReferenceArt(_badge, width: 79, height: 25),
                        const SizedBox(width: 15),
                      ],
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: ListView(
                      key: ValueKey(s.step),
                      padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                      children: [
                        if (s.step == 0) ...[
                          const SizedBox(height: 41),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Progress faster in your English course with Super!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                height: 1.435,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const AndroidSuperComparison(),
                        ] else if (s.step == 1) ...[
                          const SizedBox(height: 80),
                          _title('Get a reminder 2 days before access ends'),
                          const SizedBox(height: 15),
                          const Text(
                            'We’ll use your confirmed access end date.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 85),
                          const Center(
                            child: ReferenceArt(
                              ArtRegion(
                                'android-super-02',
                                Rect.fromLTWH(88, 390, 180, 215),
                              ),
                              width: 180,
                              height: 215,
                            ),
                          ),
                          SwitchListTile(
                            title: const Text(
                              'Remind me',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            value: reminder.enabled,
                            activeThumbColor: _green,
                            onChanged: (v) => ref
                                .read(superAccessReminderProvider.notifier)
                                .select(v),
                          ),
                          if (reminder.status == SuperReminderStatus.denied)
                            const Text(
                              'Notifications are off. Enable them in Android settings to receive the reminder.',
                              style: TextStyle(color: Colors.white),
                            ),
                          if (reminder.status ==
                              SuperReminderStatus.unavailable)
                            const Text(
                              'Could not save the reminder. Please try again.',
                              style: TextStyle(color: Colors.white),
                            ),
                        ] else ...[
                          _title('Choose a plan'),
                          const SizedBox(height: 12),
                          const Text(
                            'Demo billing • no real charges',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          const SizedBox(height: 24),
                          for (final selection in ['individual', 'family']) ...[
                            _PlanCard(
                              product: BillingProduct.forSelection(selection)!,
                              selected: s.selection == selection,
                              onTap: () => vm.choose(selection),
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextButton(
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: _ink,
                              builder: (_) => const _AllPlans(),
                            ),
                            child: const Text(
                              'VIEW ALL PLANS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (s.step == 0)
                  const Divider(
                    height: 2,
                    thickness: 2,
                    color: Color(0x33FFFFFF),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    s.step == 0 ? 15 : 10,
                    16,
                    16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReferenceButton(
                        key: const ValueKey('android-super-next'),
                        label: s.step == 2
                            ? 'CONTINUE TO DEMO CHECKOUT'
                            : 'CONTINUE',
                        backgroundColor: Colors.white,
                        edgeColor: const Color(0xFFE5E5E5),
                        foregroundColor: _ink,
                        onPressed: s.busy
                            ? null
                            : () async {
                                if (s.step < 2) {
                                  vm.next();
                                  return;
                                }
                                if (!vm.beginCheckout()) return;
                                try {
                                  final success = await showBillingCheckout(
                                    context,
                                    s.selection,
                                  );
                                  if (!context.mounted || !success) return;
                                  context.pushReplacement('/super/tour');
                                } finally {
                                  vm.endCheckout();
                                }
                              },
                      ),
                      if (s.step == 0) const SizedBox(height: 13),
                      if (s.step == 0)
                        TextButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/home'),
                          child: const Text(
                            'NO THANKS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 1.3,
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
      ),
    );
  }
}

Widget _title(String text) => Text(
  text,
  textAlign: TextAlign.center,
  style: const TextStyle(
    color: Colors.white,
    fontSize: 25,
    fontWeight: FontWeight.w800,
    height: 1.25,
  ),
);

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.selected,
    required this.onTap,
  });
  final BillingProduct product;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _green : const Color(0xFF4569A4),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _green : Colors.white,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (product.selection) {
                      'individual' => 'Individual',
                      'family' => 'Family Plan',
                      _ => 'Monthly',
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.price,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
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

class _AllPlans extends ConsumerWidget {
  const _AllPlans();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(androidSuperControllerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _title('Choose a plan'),
              const SizedBox(height: 20),
              for (final selection in ['monthly', 'individual', 'family']) ...[
                _PlanCard(
                  product: BillingProduct.forSelection(selection)!,
                  selected: s.selection == selection,
                  onTap: () => ref
                      .read(androidSuperControllerProvider.notifier)
                      .choose(selection),
                ),
                const SizedBox(height: 14),
              ],
              ReferenceButton(
                label: 'GO BACK',
                backgroundColor: Colors.white,
                foregroundColor: _ink,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AndroidSuperWelcome extends ConsumerStatefulWidget {
  const AndroidSuperWelcome({super.key});
  @override
  ConsumerState<AndroidSuperWelcome> createState() =>
      _AndroidSuperWelcomeState();
}

class _AndroidSuperWelcomeState extends ConsumerState<AndroidSuperWelcome> {
  int step = 0;
  Timer? _brandTimer;
  @override
  void dispose() {
    _brandTimer?.cancel();
    super.dispose();
  }

  void next() {
    if (step >= 2) return;
    setState(() => step++);
    if (step == 2) {
      _brandTimer = Timer(
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 1000),
        () {
          if (mounted) context.go('/home?superWelcome=1');
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingControllerProvider);
    final expires =
        billing.snapshot.activeUntil ?? billing.snapshot.receipt?.expiresAt;
    final active =
        billing.loaded &&
        !billing.hasError &&
        billing.snapshot.selection != null &&
        expires != null &&
        expires.isAfter(DateTime.now());
    if (!active) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Super access has not been confirmed.'),
                  const SizedBox(height: 20),
                  ReferenceButton(
                    label: 'CHECK ACCESS',
                    onPressed: billing.busy
                        ? null
                        : ref.read(billingControllerProvider.notifier).restore,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (step == 2) {
      return Scaffold(
        backgroundColor: _ink,
        body: SafeArea(
          child: Stack(
            children: [
              const Center(
                child: ReferenceArt(
                  ArtRegion(
                    'android-super-10',
                    Rect.fromLTWH(92, 345, 175, 75),
                  ),
                  width: 175,
                  height: 75,
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: ReferenceArt(
                  ArtRegion(
                    'android-super-10',
                    Rect.fromLTWH(120, 665, 125, 100),
                  ),
                  width: 125,
                  height: 100,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final reminder = ref.watch(superAccessReminderProvider);
    final date =
        '${expires.year}-${expires.month.toString().padLeft(2, '0')}-${expires.day.toString().padLeft(2, '0')}';
    if (step == 1) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 125, 28, 24),
                    child: Column(
                      children: [
                        const ReferenceArt(
                          ArtRegion(
                            'android-super-09',
                            Rect.fromLTWH(125, 220, 120, 180),
                          ),
                          width: 120,
                          height: 180,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Welcome to Super!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF4B4B4B),
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Enjoy your English course with Super.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 18,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                child: ReferenceButton(
                  label: 'CONTINUE',
                  backgroundColor: const Color(0xFF1CB0F6),
                  edgeColor: const Color(0xFF1899D6),
                  onPressed: next,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 62, 22, 20),
                  child: Column(
                    children: [
                      _title(
                        step == 0 ? 'Super is ready!' : 'Welcome to Super!',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step == 0
                            ? 'Your confirmed access ends on $date.'
                            : 'Enjoy your English course with Super.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.4,
                        ),
                      ),
                      if (step == 0 &&
                          reminder.status == SuperReminderStatus.scheduled)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Your reminder is scheduled 2 days before access ends.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _green),
                          ),
                        ),
                      const SizedBox(height: 75),
                      ReferenceArt(
                        ArtRegion(
                          step == 0 ? 'android-super-08' : 'android-super-09',
                          step == 0
                              ? const Rect.fromLTWH(88, 380, 185, 185)
                              : const Rect.fromLTWH(45, 340, 275, 250),
                        ),
                        width: step == 0 ? 185 : 275,
                        height: step == 0 ? 185 : 250,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ReferenceButton(
                label: step == 0 ? 'NEXT' : 'CONTINUE',
                backgroundColor: Colors.white,
                edgeColor: const Color(0xFFE5E5E5),
                foregroundColor: _ink,
                onPressed: next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Source Super 11: keep the live path underneath and point at its actual
/// subscription action. No screenshot is used as a fake home screen.
class SuperWelcomePath extends ConsumerStatefulWidget {
  const SuperWelcomePath({super.key});
  @override
  ConsumerState<SuperWelcomePath> createState() => _SuperWelcomePathState();
}

class _SuperWelcomePathState extends ConsumerState<SuperWelcomePath> {
  bool visible = true;
  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingControllerProvider);
    final until =
        billing.snapshot.activeUntil ?? billing.snapshot.receipt?.expiresAt;
    final active =
        billing.loaded &&
        !billing.hasError &&
        billing.snapshot.selection != null &&
        until != null &&
        until.isAfter(DateTime.now());
    return Stack(
      children: [
        const LearningPath(),
        if (visible && active) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => visible = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: .5)),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Super features',
                iconSize: 38,
                padding: const EdgeInsets.all(20),
                onPressed: () {
                  setState(() => visible = false);
                  context.push('/settings/super-features');
                },
                icon: const ReferenceArt(
                  ArtRegion('android-super-11', Rect.fromLTWH(313, 51, 30, 31)),
                  width: 38,
                  height: 38,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * .48,
            left: 16,
            right: 16,
            child: Semantics(
              liveRegion: true,
              child: GestureDetector(
                onTap: () => setState(() => visible = false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4225E5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Super lives here now!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You can manage your Super features by tapping here!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
