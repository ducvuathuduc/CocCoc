import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/login_flow.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../application/onboarding_controller.dart';

class LoginEntryScreen extends ConsumerWidget {
  const LoginEntryScreen({this.recoveryUserId, this.recoverySecret, super.key});
  final String? recoveryUserId, recoverySecret;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LoginFlow(
    recoveryUserId: recoveryUserId,
    recoverySecret: recoverySecret,
    onExit: () => context.canPop() ? context.pop() : context.go('/welcome'),
    onStart: () {
      if (ref.read(authControllerProvider).stage == AuthStage.signedIn) {
        context.go('/home');
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/welcome');
      }
      ref.read(onboardingControllerProvider.notifier).advance();
    },
  );
}
