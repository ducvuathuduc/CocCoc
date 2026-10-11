import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/gift_controller.dart';
import '../domain/gift_models.dart';

// Colors sampled from Gummble "Gift a Super Duolingo" refs.
abstract final class GiftColors {
  static const ink = Color(0xFF4B4B4B);
  static const body = Color(0xFF777777);
  static const label = Color(0xFFAFAFAF);
  static const border = Color(0xFFE5E5E5);
  static const field = Color(0xFFF7F7F7);
  static const superBlue = Color(0xFF3C4DFF);
  static const superEdge = Color(0xFF3F22EC);
  static const superFill = Color(0xFFEFF0FF);
  static const freeCheck = Color(0xFF787878);
  static const dash = Color(0xFFDDDDDE);
}

abstract final class GiftArt {
  static const duoGift = ArtRegion(
    'gift-subscription',
    Rect.fromLTWH(800, 540, 255, 260),
  );
  static const introHero = ArtRegion(
    'gift-intro',
    Rect.fromLTWH(0, 0, 1179, 940),
  );
  static const superLogo = ArtRegion(
    'gift-intro',
    Rect.fromLTWH(840, 1278, 230, 62),
  );
  static const noteHero = ArtRegion(
    'gift-note',
    Rect.fromLTWH(0, 0, 1179, 1150),
  );
}

abstract final class GiftRoutes {
  static const hub = '/subscription/gift';
  static const intro = '/subscription/gift/super';
  static const recipient = '/subscription/gift/super/recipient';
  static const note = '/subscription/gift/super/note';
  static const sent = '/subscription/gift/super/sent';
}

const _sectionLabel = TextStyle(
  color: GiftColors.label,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
);

/// Heavy rounded check like the refs (Material's check glyph is too thin).
class _Check extends StatelessWidget {
  const _Check({required this.color, this.size = 26});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CheckPainter(color)),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * .14, w * .52)
      ..lineTo(w * .40, w * .76)
      ..lineTo(w * .88, w * .24);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .17
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

class _SuperButton extends StatelessWidget {
  const _SuperButton({required this.label, this.onPressed, super.key});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ReferenceButton(
    label: label,
    onPressed: onPressed,
    backgroundColor: GiftColors.superBlue,
    edgeColor: GiftColors.superEdge,
    cornerRadius: 16,
    minHeight: 48,
    textStyle: const TextStyle(fontSize: 17, letterSpacing: 1.2),
  );
}

/// Full-bleed illustration with a tappable target over the baked nav glyph.
class _Hero extends StatelessWidget {
  const _Hero({required this.art, required this.tooltip, required this.onNav});
  final ArtRegion art;
  final String tooltip;
  final VoidCallback onNav;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth, k = w / art.source.width;
      return SizedBox(
        width: w,
        height: art.source.height * k,
        child: Stack(
          children: [
            ReferenceArt(art, width: w, height: art.source.height * k),
            Positioned(
              left: 20 * k,
              top: 200 * k,
              width: 130 * k,
              height: 120 * k,
              child: Tooltip(
                message: tooltip,
                child: Semantics(
                  button: true,
                  label: tooltip,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onNav,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _closeGift(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(GiftRoutes.hub);

/// Subscription > GIFT SUBSCRIPTION (ref Gift_a_Super_Duolingo/00).
class GiftSubscriptionScreen extends ConsumerWidget {
  const GiftSubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(giftControllerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.only(left: 12, right: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: GiftColors.border, width: 2),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/shop'),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: GiftColors.label,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Subscription',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: headingStyle.copyWith(
                        fontSize: 26,
                        color: GiftColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(27, 38, 27, 32),
                children: [
                  const Text('GIFT SUBSCRIPTION', style: _sectionLabel),
                  const SizedBox(height: 18),
                  _GiftCard(
                    onGift: () {
                      ref.read(giftControllerProvider.notifier).start();
                      context.push(GiftRoutes.intro);
                    },
                  ),
                  if (s.sent.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const Text('SENT GIFTS', style: _sectionLabel),
                    const SizedBox(height: 14),
                    for (final order in s.sent.reversed) _SentRow(order: order),
                  ],
                  const SizedBox(height: 30),
                  const Text('FAQS', style: _sectionLabel),
                  const SizedBox(height: 22),
                  _FaqCard(faqs: s.faqs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.onGift});
  final VoidCallback onGift;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GiftColors.border, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super',
                    style: headingStyle.copyWith(
                      fontSize: 22,
                      color: GiftColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gift distraction-free learning',
                    style: TextStyle(fontSize: 17, color: GiftColors.ink),
                  ),
                  const SizedBox(height: 14),
                  for (final line in const [
                    'Add a personalized note',
                    'Lasts all year long',
                    'No auto-renewal',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const _Check(color: GiftColors.superBlue, size: 24),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontSize: 17,
                                color: GiftColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: ReferenceArt(GiftArt.duoGift, width: 93, height: 95),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ReferenceButton(
          key: const ValueKey('gift-super'),
          label: 'GIFT SUPER',
          outlined: true,
          foregroundColor: GiftColors.superBlue,
          cornerRadius: 16,
          minHeight: 44,
          textStyle: const TextStyle(fontSize: 17, letterSpacing: 1.2),
          onPressed: onGift,
        ),
      ],
    ),
  );
}

class _SentRow extends StatelessWidget {
  const _SentRow({required this.order});
  final GiftOrder order;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        _Avatar(order.recipient),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${order.plan.name} • ${order.plan.duration} for '
            '${order.recipient.name}',
            style: const TextStyle(fontSize: 16, color: GiftColors.ink),
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: GiftColors.superBlue),
      ],
    ),
  );
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.faqs});
  final List<GiftFaq> faqs;
  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  int? open;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GiftColors.border, width: 2),
    ),
    child: Column(
      children: [
        for (var i = 0; i < widget.faqs.length; i++) ...[
          if (i > 0)
            const Divider(height: 2, thickness: 2, color: GiftColors.field),
          InkWell(
            onTap: () => setState(() => open = open == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.faqs[i].question,
                          style: headingStyle.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w400,
                            color: GiftColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: open == i ? .5 : 0,
                        duration: motionDuration(context, 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: GiftColors.label,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: motionDuration(context, 180),
                    alignment: Alignment.topLeft,
                    child: open == i
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              widget.faqs[i].answer,
                              style: const TextStyle(
                                fontSize: 16,
                                color: GiftColors.body,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Gift Super intro with FREE vs SUPER table (ref Gift_a_Super_Duolingo/01).
class GiftSuperIntroScreen extends StatelessWidget {
  const GiftSuperIntroScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _Hero(
                  art: GiftArt.introHero,
                  tooltip: 'Close',
                  onNav: () => _closeGift(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 26, 30, 0),
                  child: Text(
                    'Gift an entire year of unlimited energy and no ads!',
                    textAlign: TextAlign.center,
                    style: headingStyle.copyWith(
                      fontSize: 24,
                      height: 1.25,
                      color: GiftColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _CompareTable(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _Footer(
          caption: 'One-time payment. No auto-renewal.',
          button: _SuperButton(
            key: const ValueKey('gift-intro-continue'),
            label: 'CONTINUE',
            onPressed: () => context.push(GiftRoutes.recipient),
          ),
        ),
      ],
    ),
  );
}

class _CompareTable extends StatelessWidget {
  const _CompareTable();
  static const _rows = [
    ('Learning content', true),
    ('Unlimited energy', false),
    ('No ads', false),
    ('Unlimited practice', false),
    ('Unlimited Legendary', false),
  ];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 27),
    child: Stack(
      children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 112,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GiftColors.superFill,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Column(
          children: [
            SizedBox(
              height: 57,
              child: Row(
                children: [
                  const Spacer(),
                  const SizedBox(
                    width: 70,
                    child: Text(
                      'FREE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GiftColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 112,
                    child: Center(
                      child: ReferenceArt(
                        GiftArt.superLogo,
                        width: 84,
                        height: 23,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (label, free) in _rows)
              SizedBox(
                height: 47,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          color: GiftColors.ink,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Center(
                        child: free
                            ? const _Check(color: GiftColors.freeCheck)
                            : Container(
                                width: 15,
                                height: 2.5,
                                color: GiftColors.dash,
                              ),
                      ),
                    ),
                    const SizedBox(
                      width: 112,
                      child: Center(child: _Check(color: GiftColors.superBlue)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
          ],
        ),
      ],
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.caption, required this.button});
  final String caption;
  final Widget button;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: GiftColors.body),
          ),
          const SizedBox(height: 14),
          button,
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.person);
  final GiftRecipient person;
  static const double size = 44;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: GiftColors.superFill,
      shape: BoxShape.circle,
    ),
    child: Text(
      person.initial,
      style: TextStyle(
        color: GiftColors.superBlue,
        fontSize: size * .45,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Recipient + plan picker between intro and note (not in the source flow,
/// which starts from a friend profile; required to know who receives it).
class GiftRecipientScreen extends ConsumerWidget {
  const GiftRecipientScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(giftControllerProvider);
    final vm = ref.read(giftControllerProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => _closeGift(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 30,
                      color: GiftColors.label,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                children: [
                  Text(
                    'Who’s the lucky friend?',
                    textAlign: TextAlign.center,
                    style: headingStyle.copyWith(
                      fontSize: 24,
                      color: GiftColors.ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (final f in s.friends)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectCard(
                        key: ValueKey('gift-recipient-${f.id}'),
                        selected: s.recipientId == f.id,
                        label: '${f.name}, @${f.username}',
                        onTap: () => vm.selectRecipient(f.id),
                        child: Row(
                          children: [
                            _Avatar(f),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.name,
                                    style: headingStyle.copyWith(
                                      fontSize: 18,
                                      color: GiftColors.ink,
                                    ),
                                  ),
                                  Text(
                                    '@${f.username}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: GiftColors.body,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Text('CHOOSE A PLAN', style: _sectionLabel),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < s.plans.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _SelectCard(
                            key: ValueKey('gift-plan-${s.plans[i].id}'),
                            selected: s.planId == s.plans[i].id,
                            label:
                                '${s.plans[i].name} ${s.plans[i].duration} '
                                '${s.plans[i].priceLabel}',
                            onTap: () => vm.selectPlan(s.plans[i].id),
                            child: Column(
                              children: [
                                Text(
                                  s.plans[i].name,
                                  style: headingStyle.copyWith(
                                    fontSize: 20,
                                    color: GiftColors.ink,
                                  ),
                                ),
                                Text(
                                  s.plans[i].duration,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: GiftColors.body,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  s.plans[i].priceLabel,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: GiftColors.superBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _Footer(
              caption: s.plan.footer,
              button: _SuperButton(
                key: const ValueKey('gift-recipient-continue'),
                label: 'CONTINUE',
                onPressed: s.canContinue
                    ? () => context.push(GiftRoutes.note)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectCard extends StatefulWidget {
  const _SelectCard({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_SelectCard> createState() => _SelectCardState();
}

class _SelectCardState extends State<_SelectCard> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.selected ? GiftColors.superBlue : GiftColors.border;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedPadding(
          duration: motionDuration(context, 100),
          padding: EdgeInsets.only(top: _down ? 2 : 0),
          child: AnimatedContainer(
            duration: motionDuration(context, 120),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.selected ? GiftColors.superFill : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                top: BorderSide(color: c, width: 2),
                left: BorderSide(color: c, width: 2),
                right: BorderSide(color: c, width: 2),
                bottom: BorderSide(color: c, width: _down ? 2 : 4),
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// "Almost ready! Add a note…" (refs Gift_a_Super_Duolingo/02–03) with the
/// mock checkout sheet behind CONTINUE TO PAYMENT.
class GiftNoteScreen extends ConsumerStatefulWidget {
  const GiftNoteScreen({super.key});
  @override
  ConsumerState<GiftNoteScreen> createState() => _GiftNoteState();
}

class _GiftNoteState extends ConsumerState<GiftNoteScreen> {
  late final TextEditingController _note = TextEditingController(
    text: ref.read(giftControllerProvider).note,
  );
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    FocusScope.of(context).unfocus();
    ref.read(giftControllerProvider.notifier).setNote(_note.text);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const GiftCheckoutSheet(),
    );
    if (confirmed == true && mounted) {
      context.pushReplacement(GiftRoutes.sent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(giftControllerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _Hero(
                    art: GiftArt.noteHero,
                    tooltip: 'Back',
                    onNav: () => _closeGift(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    child: Text(
                      'Almost ready! Add a note to make the gift more personal.',
                      textAlign: TextAlign.center,
                      style: headingStyle.copyWith(
                        fontSize: 25,
                        height: 1.3,
                        color: GiftColors.ink,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 26, 18, 16),
                    child: TextField(
                      key: const ValueKey('gift-note-field'),
                      controller: _note,
                      maxLines: 5,
                      minLines: 5,
                      maxLength: 200,
                      onChanged: ref
                          .read(giftControllerProvider.notifier)
                          .setNote,
                      style: const TextStyle(
                        fontSize: 17,
                        color: GiftColors.ink,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText:
                            '(Optional) I got you Super Duolingo! Enjoy no '
                            'ads and unlimited energy for a whole year!',
                        hintMaxLines: 3,
                        hintStyle: const TextStyle(
                          fontSize: 17,
                          color: GiftColors.label,
                          height: 1.4,
                        ),
                        filled: true,
                        fillColor: GiftColors.field,
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: GiftColors.border,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: GiftColors.superBlue,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _Footer(
            caption: s.plan.footer,
            button: _SuperButton(
              key: const ValueKey('gift-continue-payment'),
              label: 'CONTINUE TO PAYMENT',
              onPressed: s.canContinue ? _checkout : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock order review: no card is collected and nothing is charged.
class GiftCheckoutSheet extends ConsumerWidget {
  const GiftCheckoutSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(giftControllerProvider);
    final r = s.recipient;
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: const TextStyle(fontSize: 16, color: GiftColors.body),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 16,
                color: GiftColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: GiftColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Review your gift',
              textAlign: TextAlign.center,
              style: headingStyle.copyWith(fontSize: 22, color: GiftColors.ink),
            ),
            const SizedBox(height: 16),
            row('To', r == null ? '—' : '${r.name} (@${r.username})'),
            row('Plan', '${s.plan.name}, ${s.plan.duration}'),
            if (s.note.trim().isNotEmpty) row('Note', s.note.trim()),
            row('Total', s.plan.priceLabel),
            const SizedBox(height: 10),
            const Text(
              'Demo checkout: no real payment is made.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: GiftColors.label),
            ),
            const SizedBox(height: 16),
            _SuperButton(
              key: const ValueKey('gift-buy'),
              label: s.purchasing ? 'PROCESSING…' : 'BUY GIFT',
              onPressed: s.purchasing || r == null
                  ? null
                  : () async {
                      final order = await ref
                          .read(giftControllerProvider.notifier)
                          .purchase();
                      if (context.mounted) {
                        Navigator.pop(context, order != null);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation after the mock purchase, with a bouncing check.
class GiftSentScreen extends ConsumerWidget {
  const GiftSentScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(giftControllerProvider).lastOrder;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: motionDuration(context, 650),
                      curve: Curves.elasticOut,
                      builder: (context, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          color: GiftColors.superBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Gift sent!',
                      textAlign: TextAlign.center,
                      style: headingStyle.copyWith(
                        fontSize: 28,
                        color: GiftColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      order == null
                          ? 'Your gift is on its way.'
                          : '${order.recipient.name} will get ${order.plan.duration} '
                                'of ${order.plan.name}. We’ll let them know it’s '
                                'from you.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: GiftColors.body,
                      ),
                    ),
                    if (order != null && order.note.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GiftColors.field,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: GiftColors.border,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '“${order.note}”',
                          style: const TextStyle(
                            fontSize: 16,
                            color: GiftColors.ink,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    _Footer(
                      caption: order == null
                          ? ''
                          : '${order.plan.priceLabel} • One-time payment',
                      button: _SuperButton(
                        key: const ValueKey('gift-done'),
                        label: 'DONE',
                        onPressed: () => context.go(GiftRoutes.hub),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
