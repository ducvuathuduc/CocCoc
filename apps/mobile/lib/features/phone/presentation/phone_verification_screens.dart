import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/phone_verification_controller.dart';
import '../domain/phone_models.dart';

/// Colors sampled from the Duolingo "Verify phone number" refs.
abstract final class PhoneColors {
  static const ink = Color(0xFF4B4B4B);
  static const muted = Color(0xFF777777);
  static const hint = Color(0xFFAFAFAF);
  static const fill = Color(0xFFF7F7F7);
  static const line = Color(0xFFE5E5E5);
}

const phoneRoute = '/settings/phone';
const phoneCountryRoute = '/settings/phone/country';
const phoneCodeRoute = '/settings/phone/code';

class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader({this.title});
  final String? title;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: double.infinity,
        height: title == null ? 50 : 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (title != null)
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: PhoneColors.ink,
                ),
              ),
            Positioned(
              left: 4,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back,
                  size: 26,
                  color: PhoneColors.hint,
                ),
              ),
            ),
          ],
        ),
      ),
      if (title != null)
        const Divider(height: 2, thickness: 2, color: PhoneColors.line),
    ],
  );
}

const _titleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: PhoneColors.ink,
  height: 1.2,
);
const _hintStyle = TextStyle(
  fontSize: 16,
  color: PhoneColors.muted,
  height: 1.5,
);

InputDecoration _bare(String hint) => InputDecoration(
  isCollapsed: true,
  border: InputBorder.none,
  counterText: '',
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 20, color: PhoneColors.hint),
);

/// Grey Duolingo text box (F7F7F7 fill, 2px E5E5E5 border).
class _Box extends StatelessWidget {
  const _Box({required this.child, this.error = false});
  final Widget child;
  final bool error;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    constraints: const BoxConstraints(minHeight: 57),
    decoration: BoxDecoration(
      color: PhoneColors.fill,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: error ? LearningColors.red : PhoneColors.line,
        width: 2,
      ),
    ),
    child: child,
  );
}

class _ErrorMark extends StatelessWidget {
  const _ErrorMark();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(right: 16),
    child: Icon(Icons.error, size: 20, color: LearningColors.red),
  );
}

Future<void> _showServerError(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x33000000),
      builder: (context) => Dialog(
        key: const ValueKey('phone-server-error'),
        backgroundColor: const Color(0xFFF1F1F1),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 61),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF010101),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: PhoneColors.line),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1080FF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

/// "What's your phone number?" — country code + number, SMS notice, NEXT.
class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({this.autofocus = true, super.key});
  final bool autofocus;
  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  late final TextEditingController _number = TextEditingController(
    text: ref.read(phoneVerificationControllerProvider).national,
  );

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final vm = ref.read(phoneVerificationControllerProvider.notifier);
    if (!await vm.sendCode() || !mounted) {
      final error = ref.read(phoneVerificationControllerProvider).serverError;
      if (error != null && mounted) {
        await _showServerError(context, error);
        vm.dismissServerError();
      }
      return;
    }
    final done = await context.push<bool>(phoneCodeRoute);
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(phoneVerificationControllerProvider);
    final vm = ref.read(phoneVerificationControllerProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PhoneHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("What’s your phone number?", style: _titleStyle),
                    const SizedBox(height: 29),
                    _Box(
                      error: false,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              button: true,
                              label: 'Country code ${s.country.prefix}',
                              child: InkWell(
                                key: const ValueKey('phone-country'),
                                onTap: () => context.push(phoneCountryRoute),
                                child: SizedBox(
                                  width: 74,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          s.country.prefix,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            color: PhoneColors.muted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 24,
                                        color: PhoneColors.hint,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 2,
                              thickness: 2,
                              color: PhoneColors.line,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 9),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    key: const ValueKey('phone-number'),
                                    controller: _number,
                                    autofocus: widget.autofocus,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    maxLength: 15,
                                    onChanged: vm.editNumber,
                                    onSubmitted: (_) => _next(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: PhoneColors.ink,
                                      letterSpacing: 0.6,
                                    ),
                                    decoration: _bare('Phone number'),
                                  ),
                                ),
                              ),
                            ),
                            if (s.numberError != null) const _ErrorMark(),
                          ],
                        ),
                      ),
                    ),
                    if (s.numberError != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          s.numberError!,
                          key: const ValueKey('phone-number-error'),
                          style: _hintStyle.copyWith(color: LearningColors.red),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ] else
                      const SizedBox(height: 25),
                    const Text(
                      'You will receive an SMS to verify your phone. '
                      'Standard SMS rates may apply.',
                      style: _hintStyle,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ReferenceButton(
                key: const ValueKey('phone-next'),
                label: 'NEXT',
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                onPressed: s.canSend ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Country/Region list with search; tapping a row sets the dial code.
class PhoneCountryScreen extends ConsumerStatefulWidget {
  const PhoneCountryScreen({super.key});
  @override
  ConsumerState<PhoneCountryScreen> createState() => _PhoneCountryScreenState();
}

class _PhoneCountryScreenState extends ConsumerState<PhoneCountryScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    ref.watch(phoneVerificationControllerProvider);
    final vm = ref.read(phoneVerificationControllerProvider.notifier);
    final list = vm.countries(_query);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PhoneHeader(title: 'Country/Region'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _Box(
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(
                        Icons.search,
                        size: 24,
                        color: PhoneColors.hint,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('phone-country-search'),
                        onChanged: (v) => setState(() => _query = v),
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          fontSize: 19,
                          color: PhoneColors.ink,
                        ),
                        decoration: _bare('Search'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No countries found',
                        key: ValueKey('phone-country-empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: PhoneColors.muted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('phone-country-list'),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _CountryRow(
                        country: list[i],
                        first: i == 0,
                        last: i == list.length - 1,
                        onTap: () {
                          vm.selectCountry(list[i]);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.first,
    required this.last,
    required this.onTap,
  });
  final PhoneCountry country;
  final bool first, last;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: PhoneColors.line, width: 2);
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(12) : Radius.zero,
      bottom: last ? const Radius.circular(12) : Radius.zero,
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        key: ValueKey('phone-country-${country.iso}'),
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 55.7,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border(
              left: side,
              right: side,
              top: side,
              bottom: last ? side : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  country.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19.5,
                    fontWeight: FontWeight.w700,
                    color: PhoneColors.ink,
                  ),
                ),
              ),
              Text(
                country.prefix,
                style: const TextStyle(fontSize: 15, color: PhoneColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Enter the 6-digit code" with resend countdown, wrong-code error and the
/// verified success state.
class PhoneCodeScreen extends ConsumerStatefulWidget {
  const PhoneCodeScreen({this.autofocus = true, super.key});
  final bool autofocus;
  @override
  ConsumerState<PhoneCodeScreen> createState() => _PhoneCodeScreenState();
}

class _PhoneCodeScreenState extends ConsumerState<PhoneCodeScreen> {
  final _code = TextEditingController();
  bool _success = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await ref
        .read(phoneVerificationControllerProvider.notifier)
        .verify();
    if (!mounted) return;
    if (ok) {
      FocusScope.of(context).unfocus();
      setState(() => _success = true);
    }
  }

  Future<void> _resend() async {
    final vm = ref.read(phoneVerificationControllerProvider.notifier);
    await vm.resend();
    _code.clear();
    final error = ref.read(phoneVerificationControllerProvider).serverError;
    if (error != null && mounted) {
      await _showServerError(context, error);
      vm.dismissServerError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(phoneVerificationControllerProvider);
    final vm = ref.read(phoneVerificationControllerProvider.notifier);
    final number = s.pending;
    if (_success && s.verified != null) {
      return _PhoneVerifiedView(
        number: s.verified!,
        onContinue: () => Navigator.of(context).pop(true),
      );
    }
    String mmss(int sec) =>
        '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PhoneHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Enter the 6-digit code', style: _titleStyle),
                    const SizedBox(height: 12),
                    Text(
                      'We sent a code to ${number?.e164 ?? ''} to verify '
                      'your phone number',
                      style: const TextStyle(
                        fontSize: 19,
                        color: PhoneColors.muted,
                        height: 1.26,
                      ),
                    ),
                    const SizedBox(height: 17),
                    _Box(
                      error: s.codeError != null,
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              child: TextField(
                                key: const ValueKey('phone-code'),
                                controller: _code,
                                autofocus: widget.autofocus,
                                keyboardType: TextInputType.number,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 6,
                                onChanged: vm.editCode,
                                onSubmitted: (_) => _verify(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: PhoneColors.ink,
                                  letterSpacing: 1,
                                ),
                                decoration: _bare('6-digit code'),
                              ),
                            ),
                          ),
                          if (s.codeError != null) const _ErrorMark(),
                        ],
                      ),
                    ),
                    if (s.codeError != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          s.codeError!,
                          key: const ValueKey('phone-code-error'),
                          style: _hintStyle.copyWith(color: LearningColors.red),
                        ),
                      ),
                    ],
                    if (s.resent && s.codeError == null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'We sent a new code to ${number?.e164 ?? ''}.',
                        key: const ValueKey('phone-code-resent'),
                        style: _hintStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Center(
              child: TextButton(
                key: const ValueKey('phone-resend'),
                onPressed: s.canResend ? _resend : null,
                child: Text(
                  s.resendSeconds > 0
                      ? 'RESEND CODE IN ${mmss(s.resendSeconds)}'
                      : 'DIDN’T RECEIVE THE CODE?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: s.canResend ? LearningColors.blue : PhoneColors.hint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReferenceButton(
                key: const ValueKey('phone-code-next'),
                label: 'NEXT',
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                onPressed: s.canVerify ? _verify : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneVerifiedView extends StatelessWidget {
  const _PhoneVerifiedView({required this.number, required this.onContinue});
  final PhoneNumber number;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      key: const ValueKey('phone-verified'),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 50),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: still ? 1 : 0, end: 1),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.elasticOut,
                        builder: (context, t, child) =>
                            Transform.scale(scale: t, child: child),
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: const BoxDecoration(
                            color: LearningColors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: LearningColors.greenDark,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 76,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Phone number verified',
                        textAlign: TextAlign.center,
                        style: _titleStyle,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${number.e164} is now linked to your account.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17.5,
                          color: PhoneColors.muted,
                          height: 1.37,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReferenceButton(
                key: const ValueKey('phone-done'),
                label: 'CONTINUE',
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
