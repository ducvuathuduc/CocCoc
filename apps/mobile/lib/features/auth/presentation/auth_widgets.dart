import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/duo_illustration.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/ui/duo_form.dart';
import '../domain/auth_state.dart';

/// Blue 3D primary button used across login/signup/delete flows.
class DuoBlueButton extends StatelessWidget {
  const DuoBlueButton({required this.label, this.onPressed, super.key});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ReferenceButton(
    label: label,
    onPressed: onPressed,
    backgroundColor: DuoFormColors.blue,
    edgeColor: DuoFormColors.blueEdge,
  );
}

/// Outlined social sign-in/up buttons (Google).
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    required this.verb,
    required this.onPressed,
    this.available = const {...AuthProvider.values},
    super.key,
  });

  /// "SIGN IN" or "SIGN UP".
  final String verb;
  final ValueChanged<AuthProvider> onPressed;
  final Set<AuthProvider> available;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final provider in AuthProvider.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ReferenceButton(
            key: ValueKey('social-${provider.name}'),
            label: '$verb WITH ${provider.name.toUpperCase()}',
            outlined: true,
            foregroundColor: DuoFormColors.ink,
            leading: const DuoIllustration(
              ReferenceArtRegions.google,
              width: 24,
              height: 24,
            ),
            onPressed: available.contains(provider)
                ? () => onPressed(provider)
                : null,
          ),
        ),
    ],
  );
}

/// "By signing in to Duolingo, you agree to our Terms and Privacy Policy."
class AuthLegalFooter extends StatefulWidget {
  const AuthLegalFooter({
    required this.prefix,
    required this.terms,
    required this.privacy,
    super.key,
  });
  final String prefix, terms, privacy;
  @override
  State<AuthLegalFooter> createState() => _AuthLegalFooterState();
}

class _AuthLegalFooterState extends State<AuthLegalFooter> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => context.push('/settings/legal/terms');
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => context.push('/settings/legal/privacy');

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: widget.prefix),
        TextSpan(
          text: widget.terms,
          style: const TextStyle(fontWeight: FontWeight.w700),
          recognizer: _terms,
          mouseCursor: SystemMouseCursors.click,
        ),
        const TextSpan(text: ' and '),
        TextSpan(
          text: '${widget.privacy}.',
          style: const TextStyle(fontWeight: FontWeight.w700),
          recognizer: _privacy,
          mouseCursor: SystemMouseCursors.click,
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 14,
      color: DuoFormColors.body,
      height: 1.5,
    ),
  );
}
