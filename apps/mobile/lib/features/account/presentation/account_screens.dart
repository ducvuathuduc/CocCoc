import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/presentation/hub_screens.dart';
import '../application/registration_controller.dart';

class RegistrationScreen extends ConsumerWidget {
  const RegistrationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(registrationControllerProvider),
        vm = ref.read(registrationControllerProvider.notifier);
    final titles = [
      'How old are you?',
      'What’s your name?',
      'What’s your email?',
      'Create a password',
    ];
    Widget input(
      String id,
      String value,
      String hint,
      void Function(String) onChanged, {
      TextInputType? type,
      bool password = false,
    }) => TextFormField(
      key: ValueKey('register-$id'),
      initialValue: value,
      onChanged: onChanged,
      maxLength: password ? 128 : 60,
      keyboardType: type,
      obscureText: password && s.hidden,
      enabled: !s.busy,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        suffixIcon: password
            ? IconButton(
                tooltip: s.hidden ? 'Show password' : 'Hide password',
                onPressed: vm.toggleHidden,
                icon: Icon(
                  s.hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: LearningColors.blue,
                ),
              )
            : null,
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: s.busy
                        ? null
                        : () {
                            if (s.step == 0 || s.step == 4) {
                              context.canPop()
                                  ? context.pop()
                                  : context.go('/home');
                            } else {
                              vm.back();
                            }
                          },
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 32,
                      color: ReferenceColors.disabled,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: (s.step + 1) / 5,
                        minHeight: 15,
                        color: LearningColors.green,
                        backgroundColor: ReferenceColors.border,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: motionDuration(context, 180),
                  child: Column(
                    key: ValueKey(s.step),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.step < 4) ...[
                        const SizedBox(height: 10),
                        Text(
                          titles[s.step],
                          style: headingStyle.copyWith(fontSize: 27),
                        ),
                        const SizedBox(height: 25),
                      ],
                      if (s.step == 0)
                        input(
                          'age',
                          s.age,
                          'Age',
                          (v) => vm.edit(age: v),
                          type: TextInputType.number,
                        ),
                      if (s.step == 1) ...[
                        input(
                          'first',
                          s.first,
                          'First name',
                          (v) => vm.edit(first: v),
                        ),
                        const SizedBox(height: 15),
                        input(
                          'last',
                          s.last,
                          'Last name (optional)',
                          (v) => vm.edit(last: v),
                        ),
                      ],
                      if (s.step == 2)
                        input(
                          'email',
                          s.email,
                          'Email',
                          (v) => vm.edit(email: v),
                          type: TextInputType.emailAddress,
                        ),
                      if (s.step == 3) ...[
                        input(
                          'password',
                          s.password,
                          'Password',
                          (v) => vm.edit(password: v),
                          password: true,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Use at least 12 characters.',
                          style: TextStyle(color: ReferenceColors.muted),
                        ),
                      ],
                      if (s.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            s.error!,
                            style: const TextStyle(
                              color: LearningColors.red,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      if (s.step == 4) ...[
                        const SizedBox(height: 110),
                        Text(
                          'Welcome, ${s.first}! Your profile has been created in this preview.',
                          textAlign: TextAlign.center,
                          style: headingStyle,
                        ),
                        const SizedBox(height: 25),
                        const Center(
                          child: ReferenceArt(
                            ArtRegion(
                              'signup-15',
                              Rect.fromLTWH(395, 1260, 400, 405),
                            ),
                            width: 155,
                            height: 158,
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Continue to the email verification preview.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: ReferenceColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                children: [
                  ReferenceButton(
                    label: s.busy
                        ? 'CREATING PROFILE…'
                        : s.step == 3
                        ? 'CREATE PROFILE'
                        : 'CONTINUE',
                    onPressed: s.busy
                        ? null
                        : s.step == 4
                        ? () => context.go('/auth/verify')
                        : vm.next,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Local preview • no account or email is created on a server.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ReferenceColors.muted,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});
  @override
  ConsumerState<VerificationScreen> createState() => _VerificationState();
}

class _VerificationState extends ConsumerState<VerificationScreen> {
  bool sent = false;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(previewControllerProvider);
    return PreviewPage(
      title: 'Verify email',
      children: [
        const SizedBox(height: 55),
        const ReferenceArt(
          ReferenceArtRegions.loginDuo,
          width: 125,
          height: 145,
        ),
        const SizedBox(height: 25),
        Text(
          s.verified ? 'Email verified!' : 'Check your email',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 18),
        Text(
          s.verified
              ? 'Your demo verification is complete.'
              : '${s.email}\nThis preview does not send email. Use the simulated verification below.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: ReferenceColors.muted),
        ),
        const SizedBox(height: 30),
        ReferenceButton(
          label: s.verified ? 'CONTINUE' : 'SIMULATE VERIFIED LINK',
          onPressed: () {
            if (s.verified) {
              context.go('/home');
            } else {
              ref.read(previewControllerProvider.notifier).verify();
            }
          },
        ),
        const SizedBox(height: 20),
        if (!s.verified)
          ReferenceButton(
            label: sent ? 'PREVIEW LINK READY' : 'RESEND PREVIEW LINK',
            outlined: true,
            onPressed: sent ? null : () => setState(() => sent = true),
          ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Text(
            'VERIFY LATER',
            style: TextStyle(
              color: LearningColors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(previewControllerProvider),
        vm = ref.read(previewControllerProvider.notifier);
    Widget row(String title, String route) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: ReferenceColors.disabled,
      ),
      onTap: () => context.push(route),
    );
    return PreviewPage(
      title: 'Settings',
      children: [
        const Text('ACCOUNT', style: sectionStyle),
        const SizedBox(height: 10),
        row('Profile', '/settings/profile'),
        const Divider(),
        row('Verify email', '/auth/verify'),
        const Divider(),
        row('My courses', '/settings/courses'),
        const Divider(),
        row('Password', '/settings/password'),
        const SizedBox(height: 25),
        const Text('PREFERENCES', style: sectionStyle),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Sound effects',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          value: s.sound,
          onChanged: vm.setSound,
          activeThumbColor: LearningColors.green,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Private profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          value: s.private,
          onChanged: vm.setPrivate,
          activeThumbColor: LearningColors.green,
        ),
        row('Practice reminders', '/settings/reminders'),
        const Divider(),
        row('Super Duolingo', '/super'),
        const Divider(),
        row('Duolingo Max', '/max'),
        const Divider(),
        row('Manage subscription', '/subscription'),
        const Divider(),
        row('Sync status', '/sync'),
        const SizedBox(height: 25),
        const Text('HELP', style: sectionStyle),
        row('Connection and recovery', '/recovery'),
        const SizedBox(height: 25),
        ReferenceButton(
          label: 'LOG OUT OF PREVIEW',
          outlined: true,
          foregroundColor: LearningColors.blue,
          onPressed: () => learningSheet<void>(
            context,
            title: 'Log out?',
            child: Column(
              children: [
                const Text('Your preview progress stays in this session.'),
                const SizedBox(height: 20),
                ReferenceButton(
                  label: 'LOG OUT',
                  backgroundColor: LearningColors.blue,
                  edgeColor: LearningColors.blueDark,
                  onPressed: () {
                    ref.invalidate(authControllerProvider);
                    Navigator.pop(context);
                    context.go('/welcome');
                  },
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => context.push('/account/delete'),
          child: const Text(
            'DELETE ACCOUNT',
            style: TextStyle(
              color: LearningColors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController name, email;
  String? error;
  @override
  void initState() {
    super.initState();
    final s = ref.read(previewControllerProvider);
    name = TextEditingController(text: s.name);
    email = TextEditingController(text: s.email);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Profile',
    children: [
      const SizedBox(height: 15),
      const Center(
        child: ReferenceArt(LearningArt.avatar, width: 130, height: 133),
      ),
      const SizedBox(height: 25),
      TextField(
        controller: name,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        maxLength: 254,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Change password',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: ReferenceColors.disabled,
        ),
        onTap: () => context.push('/settings/password'),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            error!,
            style: const TextStyle(color: LearningColors.red),
          ),
        ),
      const SizedBox(height: 25),
      ReferenceButton(
        label: 'SAVE CHANGES',
        onPressed: () {
          final result = ref
              .read(previewControllerProvider.notifier)
              .saveProfile(name.text, email.text);
          setState(() => error = result);
          if (result == null) {
            context.pop();
          }
        },
      ),
    ],
  );
}

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({super.key});
  @override
  ConsumerState<ReminderScreen> createState() => _ReminderState();
}

class _ReminderState extends ConsumerState<ReminderScreen> {
  bool denied = false;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(previewControllerProvider),
        vm = ref.read(previewControllerProvider.notifier);
    return PreviewPage(
      title: 'Practice reminders',
      children: [
        const SizedBox(height: 30),
        const ReferenceArt(
          ReferenceArtRegions.writing,
          width: 145,
          height: 139,
        ),
        const SizedBox(height: 25),
        const Text(
          'Make learning a habit',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 25),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: s.reminder,
          onChanged: (v) => vm.reminder(enabled: v),
          title: const Text(
            'Daily reminder',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reminder time'),
          trailing: Text(s.reminderTime, style: headingStyle),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 19, minute: 0),
            );
            if (t != null && mounted) {
              vm.reminder(
                enabled: s.reminder,
                time:
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              );
            }
          },
        ),
        const SizedBox(height: 20),
        LearningCard(
          child: Text(
            denied
                ? 'Notifications denied. You can still practise anytime.'
                : s.reminder
                ? 'Reminder preference saved for ${s.reminderTime}.'
                : 'Turn reminders on whenever you’re ready.',
            style: const TextStyle(fontSize: 17),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Preview preferences only. No operating-system notification is scheduled.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ReferenceColors.muted),
        ),
        const SizedBox(height: 20),
        ReferenceButton(
          label: denied
              ? 'RESET PERMISSION PREVIEW'
              : 'PREVIEW PERMISSION DENIED',
          outlined: true,
          onPressed: () => setState(() => denied = !denied),
        ),
      ],
    );
  }
}

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});
  @override
  ConsumerState<SyncScreen> createState() => _SyncState();
}

class _SyncState extends ConsumerState<SyncScreen> {
  bool offline = false, conflict = false;
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Sync status',
    children: [
      const SizedBox(height: 35),
      Icon(
        offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
        size: 90,
        color: LearningColors.blue,
      ),
      const SizedBox(height: 25),
      Text(
        conflict
            ? 'Review needed'
            : offline
            ? 'You’re offline'
            : 'Preview is ready',
        textAlign: TextAlign.center,
        style: headingStyle,
      ),
      const SizedBox(height: 20),
      LearningCard(
        child: Text(
          conflict
              ? 'Sample retired content: your answer is preserved. Continue with a current lesson.'
              : 'Local mock lessons and profile changes remain in this session. Cloud synchronization is not connected.',
          style: const TextStyle(fontSize: 18),
        ),
      ),
      const SizedBox(height: 20),
      ReferenceButton(
        label: offline ? 'RECONNECT PREVIEW' : 'REFRESH PREVIEW',
        onPressed: () => setState(() {
          offline = false;
          conflict = false;
        }),
      ),
      const SizedBox(height: 20),
      ReferenceButton(
        label: 'SIMULATE OFFLINE',
        outlined: true,
        onPressed: () => setState(() => offline = true),
      ),
      const SizedBox(height: 16),
      ReferenceButton(
        label: 'SIMULATE RETIRED CONTENT',
        outlined: true,
        onPressed: () => setState(() => conflict = true),
      ),
    ],
  );
}

class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requested = ref.watch(previewControllerProvider).deletionRequested;
    return PreviewPage(
      title: 'Delete Account',
      children: [
        SizedBox(height: requested ? 90 : 35),
        if (requested)
          const ReferenceArt(
            ArtRegion('delete-06', Rect.fromLTWH(383, 805, 414, 445)),
            width: 145,
            height: 156,
          ),
        const SizedBox(height: 25),
        Text(
          requested ? 'Request preview complete' : 'Delete your account?',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 20),
        Text(
          requested
              ? 'This is a simulated receipt. Your account and data have been preserved. No email was sent.'
              : 'Deleting a real account removes its profile and progress. You can review the confirmation here without deleting any data.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            color: ReferenceColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 35),
        ReferenceButton(
          label: requested ? 'DONE' : 'PREVIEW DELETE REQUEST',
          backgroundColor: requested ? LearningColors.blue : LearningColors.red,
          edgeColor: requested
              ? LearningColors.blueDark
              : LearningColors.redDark,
          onPressed: requested
              ? () => context.pop()
              : () => learningSheet<void>(
                  context,
                  title: 'Confirm request preview?',
                  child: Column(
                    children: [
                      const Text(
                        'This confirmation only records a local preview receipt.',
                      ),
                      const SizedBox(height: 25),
                      ReferenceButton(
                        label: 'CONFIRM PREVIEW',
                        backgroundColor: LearningColors.red,
                        edgeColor: LearningColors.redDark,
                        onPressed: () {
                          ref
                              .read(previewControllerProvider.notifier)
                              .requestDeletion();
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});
  @override
  State<RecoveryScreen> createState() => _RecoveryState();
}

class _RecoveryState extends State<RecoveryScreen> {
  String failure = 'timeout';
  bool recovered = false;
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Connection and recovery',
    children: [
      const SizedBox(height: 35),
      Icon(
        recovered ? Icons.check_circle_outline : Icons.wifi_off_rounded,
        size: 80,
        color: LearningColors.blue,
      ),
      const SizedBox(height: 25),
      Text(
        recovered
            ? 'You’re ready to continue'
            : failure == '401'
            ? 'Sign in to continue'
            : failure == '429'
            ? 'Let’s take a short break'
            : 'Something went wrong',
        textAlign: TextAlign.center,
        style: headingStyle,
      ),
      const SizedBox(height: 18),
      const Text(
        'Your answers and profile changes are preserved. This is a recovery-state preview.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: ReferenceColors.muted),
      ),
      const SizedBox(height: 30),
      ReferenceButton(
        label: failure == '401' && !recovered ? 'LOG IN' : 'RETRY',
        onPressed: () => failure == '401' && !recovered
            ? context.push('/login')
            : setState(() => recovered = true),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        children: [
          for (final code in ['timeout', '401', '429'])
            ChoiceChip(
              label: Text(code),
              selected: failure == code,
              onSelected: (_) => setState(() {
                failure = code;
                recovered = false;
              }),
            ),
        ],
      ),
    ],
  );
}
