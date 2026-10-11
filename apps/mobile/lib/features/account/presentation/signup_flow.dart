import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/ui/duo_form.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../application/registration_controller.dart';
import '../data/account_repository.dart';

const _duoPrompt = ArtRegion('signup-01', Rect.fromLTWH(425, 1100, 380, 380));
const _duoWelcome = ArtRegion('signup-15', Rect.fromLTWH(395, 1260, 400, 405));

const _titleStyle = TextStyle(
  fontSize: 24,
  height: 1.25,
  fontWeight: FontWeight.w700,
  color: DuoFormColors.ink,
);

/// "Don't lose your progress! Let's create a profile." (signup/01).
class CreateProfilePromptScreen extends ConsumerWidget {
  const CreateProfilePromptScreen({
    required this.onCreate,
    required this.onLater,
    super.key,
  });
  final VoidCallback onCreate, onLater;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(accountRepositoryProvider).signupContent;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: SpeechBubble(
                    below: true,
                    child: Text(copy.promptMessage),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: ReferenceArt(_duoPrompt, width: 120, height: 120),
              ),
              const Spacer(flex: 5),
              DuoBlueButton(label: copy.promptCreate, onPressed: onCreate),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onLater,
                child: Text(
                  copy.promptLater,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                    color: DuoFormColors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Duolingo create-profile flow: age → name → email → password → welcome.
class RegistrationScreen extends ConsumerWidget {
  const RegistrationScreen({super.key});

  void _exit(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(registrationControllerProvider),
        vm = ref.read(registrationControllerProvider.notifier),
        copy = ref.watch(accountRepositoryProvider).signupContent;
    final title = s.step < 4
        ? copy.titles[s.step].replaceAll('{name}', s.fullName)
        : '';
    void submit() {
      FocusScope.of(context).unfocus();
      vm.next();
    }

    final primary = s.step == 4
        ? DuoBlueButton(
            key: const ValueKey('register-continue'),
            label: copy.continueLabel,
            onPressed: () => context.go('/auth/verify'),
          )
        : ReferenceButton(
            key: const ValueKey('register-next'),
            label: s.busy
                ? copy.creatingLabel
                : s.step == 3
                ? copy.createLabel
                : copy.nextLabel,
            onPressed: s.canSubmit ? submit : null,
          );
    final legal = AuthLegalFooter(
      prefix: copy.legalPrefix,
      terms: copy.termsLabel,
      privacy: copy.privacyLabel,
    );

    Widget body() => switch (s.step) {
      0 => DuoFieldGroup(
        error: s.error != null,
        children: [
          DuoInput(
            fieldKey: const ValueKey('register-age'),
            value: s.age,
            hint: copy.agePlaceholder,
            keyboardType: TextInputType.number,
            enabled: !s.busy,
            onChanged: (v) => vm.edit(age: v),
            onSubmitted: (_) => submit(),
            trailing: s.ageValid
                ? const Icon(
                    Icons.check_circle_rounded,
                    key: ValueKey('register-age-valid'),
                    color: DuoFormColors.check,
                    size: 22,
                  )
                : null,
          ),
        ],
      ),
      1 => DuoFieldGroup(
        error: s.error != null,
        children: [
          DuoInput(
            fieldKey: const ValueKey('register-first'),
            value: s.first,
            hint: copy.firstNamePlaceholder,
            enabled: !s.busy,
            textInputAction: TextInputAction.next,
            onChanged: (v) => vm.edit(first: v),
          ),
          DuoInput(
            fieldKey: const ValueKey('register-last'),
            value: s.last,
            hint: copy.lastNamePlaceholder,
            enabled: !s.busy,
            onChanged: (v) => vm.edit(last: v),
            onSubmitted: (_) => submit(),
          ),
        ],
      ),
      2 => DuoFieldGroup(
        children: [
          DuoInput(
            fieldKey: const ValueKey('register-email'),
            value: s.email,
            hint: copy.emailPlaceholder,
            keyboardType: TextInputType.emailAddress,
            enabled: !s.busy,
            onChanged: (v) => vm.edit(email: v),
            onSubmitted: (_) => submit(),
            trailing: s.emailInvalidShown
                ? const Icon(
                    Icons.error_rounded,
                    key: ValueKey('register-email-invalid'),
                    color: DuoFormColors.errorIcon,
                    size: 20,
                  )
                : null,
          ),
        ],
      ),
      3 => DuoFieldGroup(
        error: s.error != null,
        children: [
          DuoInput(
            fieldKey: const ValueKey('register-password'),
            value: s.password,
            hint: copy.passwordPlaceholder,
            obscure: s.hidden,
            enabled: !s.busy,
            onToggleObscure: vm.toggleHidden,
            onChanged: (v) => vm.edit(password: v),
            onSubmitted: (_) => submit(),
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };

    final step = s.step == 4
        ? Column(
            key: const ValueKey('register-step-4'),
            children: [
              const SizedBox(height: 150),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: SpeechBubble(
                  below: true,
                  child: Text(
                    copy.welcomeTemplate.replaceAll('{name}', s.fullName),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const ReferenceArt(_duoWelcome, width: 128, height: 130),
            ],
          )
        : Column(
            key: ValueKey('register-step-${s.step}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(title, style: _titleStyle),
              const SizedBox(height: 16),
              DuoShake(trigger: s.errorTick, child: body()),
              if (s.emailInvalidShown) ...[
                DuoFieldError(s.error!),
                if (s.emailSuggestion != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    copy.suggestedEmailLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DuoFormColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      key: const ValueKey('register-email-suggestion'),
                      onPressed: vm.acceptSuggestion,
                      child: Text(
                        s.emailSuggestion!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DuoFormColors.check,
                        ),
                      ),
                    ),
                  ),
                ],
              ] else if (s.error != null)
                DuoFieldError(s.error!),
              if (s.step == 1) ...[const SizedBox(height: 16), primary],
            ],
          );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (s.step < 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: s.step == 0 ? 'Close' : 'Back',
                      onPressed: s.busy
                          ? null
                          : s.step == 0
                          ? () => _exit(context)
                          : vm.back,
                      icon: s.step == 0
                          ? const Icon(
                              Icons.close_rounded,
                              size: 30,
                              color: ReferenceColors.disabled,
                            )
                          : const ReferenceBackIcon(),
                    ),
                    Expanded(child: _ProgressBar(value: (s.step + 1) / 6)),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DuoStepSwitcher(child: step),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.step == 1)
                    SocialAuthButtons(
                      verb: 'SIGN UP',
                      available: ref.watch(authAvailableProvidersProvider),
                      onPressed: (p) =>
                          ref.read(authControllerProvider.notifier).social(p),
                    )
                  else
                    primary,
                  if (s.step == 0 || s.step == 3) ...[
                    const SizedBox(height: 14),
                    legal,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Container(
      height: 16,
      decoration: BoxDecoration(
        color: ReferenceColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: DuoFormMotion.of(context, DuoFormMotion.page),
        curve: Curves.easeOutCubic,
        width: c.maxWidth * value.clamp(0, 1),
        decoration: BoxDecoration(
          color: ReferenceColors.green,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}
