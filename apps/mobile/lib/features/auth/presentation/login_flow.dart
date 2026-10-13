import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/duo_illustration.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';
import '../../../core/ui/duo_form.dart';
import 'auth_widgets.dart';
import 'saved_account_management.dart';

const authBlue = DuoFormColors.blue;
const authBlueEdge = DuoFormColors.blueEdge;

class LoginFlow extends ConsumerStatefulWidget {
  const LoginFlow({
    required this.onExit,
    required this.onStart,
    this.initialize = true,
    this.recoveryUserId,
    this.recoverySecret,
    super.key,
  });
  final VoidCallback onExit, onStart;
  final bool initialize;
  final String? recoveryUserId, recoverySecret;
  @override
  ConsumerState<LoginFlow> createState() => _LoginFlowState();
}

class _LoginFlowState extends ConsumerState<LoginFlow> {
  final _fields = List.generate(5, (_) => TextEditingController());
  int _errorTick = 0;
  String? _lastError;
  AuthController get c => ref.read(authControllerProvider.notifier);
  @override
  void initState() {
    super.initState();
    if (widget.recoveryUserId != null && widget.recoverySecret != null) {
      Future.microtask(() {
        if (mounted) {
          c.showReset(widget.recoveryUserId!, widget.recoverySecret!);
        }
      });
    } else if (widget.initialize) {
      Future.microtask(() {
        if (mounted) c.initialize();
      });
    }
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (!c.back()) widget.onExit();
  }

  void _signIn() {
    FocusScope.of(context).unfocus();
    c.signIn();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authControllerProvider);
    if (s.error != _lastError) {
      if (s.error != null) _errorTick++;
      _lastError = s.error;
    }
    final values = [
      s.email,
      s.password,
      s.newPassword,
      s.confirmPassword,
      s.code,
    ];
    for (var i = 0; i < values.length; i++) {
      if (_fields[i].text != values[i]) {
        _fields[i].value = TextEditingValue(
          text: values[i],
          selection: TextSelection.collapsed(offset: values[i].length),
        );
      }
    }
    return PopScope(
      canPop: s.stage == AuthStage.choice && !s.busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !s.busy) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: s.stage == AuthStage.busy
              ? const SigningInView()
              : Column(
                  children: [
                    if (s.stage != AuthStage.choice || s.remembered == null)
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Back',
                              onPressed: s.busy ? null : _back,
                              icon: const ReferenceBackIcon(),
                            ),
                            Expanded(
                              child: Text(
                                s.stage == AuthStage.details
                                    ? 'Enter your details'
                                    : '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: ReferenceColors.disabled,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    Expanded(
                      child: DuoStepSwitcher(
                        child: KeyedSubtree(
                          key: ValueKey('auth-stage-${s.stage.name}'),
                          child: switch (s.stage) {
                            AuthStage.choice =>
                              s.remembered == null ? _choice() : _remembered(s),
                            AuthStage.details => _details(s),
                            AuthStage.forgot => _recovery(s),
                            AuthStage.reset => _reset(s),
                            AuthStage.signedIn => _signedIn(s),
                            AuthStage.emailCode => _emailCode(s),
                            AuthStage.emailCodeVerify => _emailCodeVerify(s),
                            AuthStage.busy => const SigningInView(),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _choice() => LayoutBuilder(
    builder: (context, size) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: (size.maxHeight * .22).clamp(32, 154)),
          heading('Already have an account?'),
          gap(13),
          caption('Pick up where you left off.'),
          gap(29),
          ReferenceButton(label: 'SIGN IN', onPressed: () => c.showDetails()),
          gap(60),
          const Divider(height: 2, thickness: 2, color: ReferenceColors.border),
          gap(36),
          heading('New to Duolingo?'),
          gap(13),
          caption('Start learning now.'),
          gap(29),
          ReferenceButton(
            label: 'GET STARTED',
            outlined: true,
            onPressed: widget.onStart,
          ),
          gap(32),
        ],
      ),
    ),
  );
  Widget _remembered(AuthState s) {
    final account = s.remembered!;
    final name = account.name.isEmpty ? account.email : account.name;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 46, 16, 24),
      child: Column(
        children: [
          const DuoIllustration(
            ReferenceArtRegions.loginDuo,
            width: 104,
            height: 121,
          ),
          gap(32),
          heading('Sign back in'),
          gap(28),
          JoinedAuthPanel(
            color: ReferenceColors.surface,
            children: [
              InkWell(
                onTap: () => c.showDetails(email: account.email),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: const Color(0xFF58A700),
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            gap(4),
                            Text(
                              account.email,
                              style: const TextStyle(
                                fontSize: 16,
                                color: ReferenceColors.disabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 28,
                        color: ReferenceColors.disabled,
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                minTileHeight: 76,
                leading: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 40,
                  color: ReferenceColors.disabled,
                ),
                title: const Text(
                  'Add another account',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ReferenceColors.disabled,
                  ),
                ),
                onTap: () => c.showDetails(email: ''),
              ),
            ],
          ),
          gap(32),
          TextButton(
            onPressed: () async {
              final removed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      SavedAccountManagementScreen(account: account),
                ),
              );
              if (removed == true && mounted) widget.onExit();
            },
            child: const Text(
              'MANAGE ACCOUNTS',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ReferenceColors.disabled,
                letterSpacing: 1,
              ),
            ),
          ),
          if (s.error != null) authError(s.error!),
        ],
      ),
    );
  }

  Widget _details(AuthState s) => _split(
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutofillGroup(
          child: DuoShake(
            trigger: _errorTick,
            child: JoinedAuthPanel(
              error: s.error != null,
              children: [
                _field(
                  0,
                  'Email, phone, or username',
                  c.updateEmail,
                  email: true,
                  autofill: const [AutofillHints.email],
                ),
                _field(
                  1,
                  'Password',
                  c.updatePassword,
                  hidden: s.hidden,
                  toggle: c.toggleHidden,
                  autofill: const [AutofillHints.password],
                  submit: s.canSignIn ? _signIn : null,
                ),
              ],
            ),
          ),
        ),
        gap(20),
        blueButton('SIGN IN', s.canSignIn ? _signIn : null),
        gap(18),
        TextButton(
          onPressed: c.showForgot,
          child: const Text(
            'FORGOT PASSWORD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: authBlue,
              letterSpacing: .8,
            ),
          ),
        ),
        if (ref.watch(authEmailCodeRepositoryProvider) != null)
          TextButton(
            key: const ValueKey('auth-email-code-entry'),
            onPressed: c.showEmailCode,
            child: const Text(
              'SIGN IN WITH EMAIL CODE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: authBlue,
                letterSpacing: .8,
              ),
            ),
          ),
        if (s.error != null) authError(s.error!),
      ],
    ),
    bottom: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialAuthButtons(
          verb: 'SIGN IN',
          available: ref.watch(authAvailableProvidersProvider),
          onPressed: (provider) {
            FocusScope.of(context).unfocus();
            c.social(provider);
          },
        ),
        gap(12),
        const AuthLegalFooter(
          prefix: 'By signing in to Duolingo, you agree to our ',
          terms: 'Terms',
          privacy: 'Privacy Policy',
        ),
      ],
    ),
  );
  Widget _recovery(AuthState s) => _split(
    bottomInset: 0,
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        gap(6),
        heading('Forgot password?', align: TextAlign.left),
        gap(14),
        JoinedAuthPanel(
          children: [_field(0, 'Email', c.updateEmail, email: true)],
        ),
        gap(8),
        const Text(
          'Enter your email address to receive a link to reset your password.',
          style: TextStyle(
            fontSize: 16.5,
            color: ReferenceColors.muted,
            height: 1.6,
          ),
        ),
        if (s.error != null) authError(s.error!),
      ],
    ),
    bottom: blueButton(
      s.busy ? 'SENDING…' : 'NEXT',
      s.canRecover && !s.busy
          ? () async {
              FocusScope.of(context).unfocus();
              await c.recover();
              if (mounted && ref.read(authControllerProvider).recoverySent) {
                c.dismissRecovery();
                final continueReset = await _sheet(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      heading('Check your email!'),
                      gap(24),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'If an account exists for '),
                            TextSpan(
                              text: ref.read(authControllerProvider).email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: ', you’ll receive a reset link. Check your spam folder or try again.',
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: ReferenceColors.muted,
                          height: 1.5,
                        ),
                      ),
                      gap(34),
                      blueButton('OKAY', () => Navigator.pop(context, true)),
                    ],
                  ),
                );
                if (mounted && continueReset == true && useMockAuth) {
                  c.showReset('demo-user-001', 'demo-recovery-token');
                }
              }
            }
          : null,
    ),
  );
  Widget _emailCode(AuthState s) => _split(
    bottomInset: 0,
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        gap(6),
        heading('Sign in with email code', align: TextAlign.left),
        gap(14),
        JoinedAuthPanel(
          error: s.error != null,
          children: [
            _field(
              0,
              'Email',
              c.updateEmail,
              email: true,
              autofill: const [AutofillHints.email],
              submit: s.canRecover ? _sendCode : null,
            ),
          ],
        ),
        gap(8),
        const Text(
          'We’ll email you a 6-digit code to sign in. No password needed.',
          key: ValueKey('auth-email-code-hint'),
          style: TextStyle(
            fontSize: 16.5,
            color: ReferenceColors.muted,
            height: 1.6,
          ),
        ),
        if (s.error != null) authError(s.error!),
      ],
    ),
    bottom: KeyedSubtree(
      key: const ValueKey('auth-email-code-send'),
      child: blueButton(
        s.busy ? 'SENDING…' : 'SEND CODE',
        s.canRecover && !s.busy ? _sendCode : null,
      ),
    ),
  );
  void _sendCode() {
    FocusScope.of(context).unfocus();
    c.sendEmailCode();
  }

  void _verifyCode() {
    FocusScope.of(context).unfocus();
    c.verifyEmailCode();
  }

  Widget _emailCodeVerify(AuthState s) => _split(
    bottomInset: 0,
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        gap(6),
        heading('Enter the 6-digit code', align: TextAlign.left),
        gap(14),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'We sent a code to '),
              TextSpan(
                text: s.email.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '. It expires in 15 minutes.'),
            ],
          ),
          style: const TextStyle(
            fontSize: 16.5,
            color: ReferenceColors.muted,
            height: 1.6,
          ),
        ),
        gap(14),
        DuoShake(
          trigger: _errorTick,
          child: JoinedAuthPanel(
            error: s.error != null,
            children: [
              TextField(
                key: const ValueKey('auth-email-code-field'),
                controller: _fields[4],
                onChanged: c.updateCode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onSubmitted: s.canVerifyCode ? (_) => _verifyCode() : null,
                enabled: !s.busy,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.1,
                  letterSpacing: 4,
                  color: ReferenceColors.ink,
                ),
                decoration: const InputDecoration(
                  constraints: BoxConstraints(minHeight: 48),
                  hintText: '6-digit code',
                  hintStyle: TextStyle(
                    color: ReferenceColors.disabled,
                    letterSpacing: 0,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 19,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (s.error != null) authError(s.error!),
        if (s.codeResent && s.error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'We sent you a new code.',
              key: ValueKey('auth-email-code-resent'),
              style: TextStyle(fontSize: 16, color: ReferenceColors.muted),
            ),
          ),
        gap(6),
        TextButton(
          key: const ValueKey('auth-email-code-resend'),
          onPressed: s.busy ? null : c.resendEmailCode,
          child: const Text(
            'RESEND CODE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: authBlue,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    ),
    bottom: KeyedSubtree(
      key: const ValueKey('auth-email-code-verify'),
      child: blueButton(
        'SIGN IN',
        s.canVerifyCode && !s.busy ? _verifyCode : null,
      ),
    ),
  );
  Widget _reset(AuthState s) => _split(
    bottomInset: 16,
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        gap(30),
        heading('Reset your password'),
        gap(34),
        JoinedAuthPanel(
          children: [
            _field(
              2,
              'New password',
              c.updateNewPassword,
              hidden: s.hidden,
              toggle: c.toggleHidden,
              autofill: const [AutofillHints.newPassword],
            ),
            _field(
              3,
              'Confirm new password',
              c.updateConfirmPassword,
              hidden: s.confirmHidden,
              toggle: c.toggleConfirmHidden,
            ),
          ],
        ),
        if (s.newPassword.isNotEmpty && s.newPassword.length < 12)
          authError('Use at least 12 characters.'),
        if (s.confirmPassword.isNotEmpty && s.newPassword != s.confirmPassword)
          authError('Passwords must match.'),
        if (s.error != null) authError(s.error!),
      ],
    ),
    bottom: blueButton(
      s.busy ? 'UPDATING…' : 'RESET PASSWORD',
      s.canReset && !s.busy
          ? () async {
              FocusScope.of(context).unfocus();
              await c.reset();
              if (mounted && ref.read(authControllerProvider).resetComplete) {
                await _sheet(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DuoIllustration(
                        ReferenceArtRegions.successDuo,
                        width: 105,
                        height: 163,
                      ),
                      gap(16),
                      heading('Success!'),
                      gap(24),
                      caption('Your password has been updated.'),
                      gap(34),
                      blueButton('CONTINUE', () => Navigator.pop(context)),
                    ],
                  ),
                );
                if (mounted) c.dismissReset();
              }
            }
          : null,
    ),
  );
  Future<bool?> _sheet(Widget child) =>
      showDuoSheet<bool>(context, (_) => child);
  Widget _signedIn(AuthState s) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        gap(56),
        const DuoIllustration(
          ReferenceArtRegions.loginDuo,
          width: 104,
          height: 121,
        ),
        gap(24),
        heading('Welcome back!'),
        gap(16),
        caption(
          s.user?.name.isNotEmpty == true ? s.user!.name : s.user?.email ?? '',
        ),
        gap(32),
        ReferenceButton(label: 'CONTINUE', onPressed: widget.onStart),
      ],
    ),
  );
  Widget _split({
    required Widget top,
    required Widget bottom,
    double bottomInset = 26,
  }) => LayoutBuilder(
    builder: (context, size) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(0, size.maxHeight - 14 - bottomInset),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            top,
            Padding(padding: const EdgeInsets.only(top: 32), child: bottom),
          ],
        ),
      ),
    ),
  );
  Widget _field(
    int index,
    String hint,
    ValueChanged<String> changed, {
    bool email = false,
    bool hidden = false,
    VoidCallback? toggle,
    List<String>? autofill,
    VoidCallback? submit,
  }) => TextField(
    controller: _fields[index],
    onChanged: changed,
    keyboardType: email
        ? TextInputType.emailAddress
        : TextInputType.visiblePassword,
    autofillHints: autofill,
    obscureText: !email && hidden,
    autocorrect: false,
    enableSuggestions: false,
    textInputAction: email ? TextInputAction.next : TextInputAction.done,
    onSubmitted: submit == null ? null : (_) => submit(),
    enabled: !ref.watch(authControllerProvider).busy,
    style: const TextStyle(
      fontSize: 20,
      height: 1.1,
      color: ReferenceColors.ink,
    ),
    decoration: InputDecoration(
      constraints: const BoxConstraints(minHeight: 48),
      hintText: hint,
      hintStyle: const TextStyle(color: ReferenceColors.disabled),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
      suffixIcon: email
          ? null
          : IconButton(
              tooltip: hidden ? 'Show $hint' : 'Hide $hint',
              onPressed: toggle,
              icon: hidden
                  ? const DuoIllustration(
                      ReferenceArtRegions.hiddenEye,
                      width: 28,
                      height: 22,
                    )
                  : const Icon(
                      Icons.visibility_outlined,
                      color: authBlue,
                      size: 28,
                    ),
            ),
    ),
  );
}

Widget gap(double height) => SizedBox(height: height);
Widget heading(String value, {TextAlign align = TextAlign.center}) => Text(
  value,
  textAlign: align,
  style: const TextStyle(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
  ),
);
Widget caption(String value) => Text(
  value,
  textAlign: TextAlign.center,
  style: const TextStyle(fontSize: 20, color: ReferenceColors.muted),
);
Widget blueButton(String value, VoidCallback? action) => ReferenceButton(
  label: value,
  onPressed: action,
  backgroundColor: authBlue,
  edgeColor: authBlueEdge,
);
Widget authError(String value) => Semantics(
  liveRegion: true,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      value,
      style: const TextStyle(fontSize: 16, color: DuoFormColors.errorText),
    ),
  ),
);

class JoinedAuthPanel extends StatelessWidget {
  const JoinedAuthPanel({
    required this.children,
    this.color = DuoFormColors.fieldFill,
    this.error = false,
    super.key,
  });
  final List<Widget> children;
  final Color color;
  final bool error;
  @override
  Widget build(BuildContext context) =>
      DuoFieldGroup(color: color, error: error, children: children);
}

class SigningInView extends StatelessWidget {
  const SigningInView({super.key});
  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(3, -58),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DuoIllustration(
              ReferenceArtRegions.building,
              width: 123,
              height: 154,
            ),
            gap(34),
            Semantics(
              liveRegion: true,
              child: const Text(
                'SIGNING YOU IN…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ReferenceColors.disabled,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
