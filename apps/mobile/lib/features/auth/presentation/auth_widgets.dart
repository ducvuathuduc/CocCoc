import 'package:flutter/material.dart';

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

/// Outlined social sign-in/up buttons (Google, Facebook, Apple).
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
            leading: DuoIllustration(
              switch (provider) {
                AuthProvider.google => ReferenceArtRegions.google,
                AuthProvider.facebook => ReferenceArtRegions.facebook,
                AuthProvider.apple => ReferenceArtRegions.apple,
              },
              width: provider == AuthProvider.apple ? 23 : 24,
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
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({
    required this.prefix,
    required this.terms,
    required this.privacy,
    super.key,
  });
  final String prefix, terms, privacy;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: prefix),
        TextSpan(
          text: terms,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const TextSpan(text: ' and '),
        TextSpan(
          text: '$privacy.',
          style: const TextStyle(fontWeight: FontWeight.w700),
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
