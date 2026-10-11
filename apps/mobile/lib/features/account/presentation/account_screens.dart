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
import '../application/profile_editor_controller.dart';
import '../application/avatar_controller.dart';
import 'avatar_motion.dart';

export 'delete_account_screen.dart';
export 'signup_flow.dart';

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
              ? 'Your email is verified.'
              : '${s.email}\nVerify your email to keep your account up to date.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: ReferenceColors.muted),
        ),
        const SizedBox(height: 30),
        ReferenceButton(
          label: 'CONTINUE',
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
            label: sent ? 'LINK READY' : 'RESEND LINK',
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
    Widget row(String title, String route, {String? subtitle}) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: ReferenceColors.disabled,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: ReferenceColors.disabled,
      ),
      onTap: () => context.push(route),
    );

    Widget textLink(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: LearningColors.blue,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.8,
        ),
      ),
    );

    return PreviewPage(
      title: 'Settings',
      children: [
        const Text('ACCOUNT', style: sectionStyle),
        const SizedBox(height: 10),
        row('Preferences', '/settings/preferences'),
        row('Profile', '/settings/profile'),
        row('Notifications', '/settings/notifications'),
        row('Courses', '/settings/courses'),
        row('Duolingo for Schools', '/settings/schools'),
        row('Social accounts', '/settings/social'),
        row('Privacy settings', '/settings/privacy'),
        const Divider(),
        const SizedBox(height: 25),

        const Text('SUBSCRIPTION', style: sectionStyle),
        const SizedBox(height: 10),
        row(
          'Manage Subscription',
          '/subscription',
          subtitle: 'Super Duolingo 12 months',
        ),
        const SizedBox(height: 16),
        ReferenceButton(
          label: 'RESTORE SUBSCRIPTION',
          outlined: true,
          foregroundColor: LearningColors.blue,
          onPressed: () {},
        ),
        const SizedBox(height: 25),
        const Divider(),
        const SizedBox(height: 25),

        const Text('SUPPORT', style: sectionStyle),
        const SizedBox(height: 10),
        row('Help Center', '/support/help'),
        row('Feedback', '/support/feedback'),
        const SizedBox(height: 16),
        ReferenceButton(
          label: 'SIGN OUT',
          outlined: true,
          foregroundColor: LearningColors.blue,
          onPressed: () => learningSheet<void>(
            context,
            title: 'Sign out?',
            child: Column(
              children: [
                const Text('You can log in again to continue learning.'),
                const SizedBox(height: 20),
                ReferenceButton(
                  label: 'SIGN OUT',
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
        const SizedBox(height: 35),

        textLink('TERMS'),
        textLink('PRIVACY POLICY'),
        textLink('ACKNOWLEDGEMENTS'),
        const SizedBox(height: 40),
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
  late final TextEditingController first, last, username, email, phone;
  String? error;
  @override
  void initState() {
    super.initState();
    final s = ref.read(profileEditorProvider);
    first = TextEditingController(text: s.first);
    last = TextEditingController(text: s.last);
    username = TextEditingController(text: s.username);
    email = TextEditingController(text: s.email);
    phone = TextEditingController(text: s.phone);
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    username.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ref.watch(avatarControllerProvider);
    Widget field(
      String id,
      String label,
      TextEditingController controller, {
      int limit = 60,
      TextInputType? type,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ReferenceColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('profile-$id'),
            controller: controller,
            maxLength: limit,
            keyboardType: type,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 20, color: ReferenceColors.ink),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              hintText: id == 'phone' ? 'Add phone number' : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E5E5),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1CB0F6),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 49,
        foregroundColor: ReferenceColors.ink,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: Divider(height: 2, thickness: 2, color: Color(0xFFE5E5E5)),
        ),
      ),
      body: ListView(
        key: const ValueKey('profile-editor-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: 'Change avatar',
              child: InkWell(
                onTap: () => context.push('/settings/avatar'),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1CB0F6),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: avatar.hasAvatar
                        ? AvatarMotion(values: avatar.saved, animate: false)
                        : const ReferenceArt(
                            LearningArt.avatar,
                            width: 86,
                            height: 86,
                          ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => context.push('/settings/avatar'),
              child: const Text(
                'CHANGE AVATAR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1CB0F6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          field('first', 'First name', first),
          field('last', 'Last name', last),
          field('username', 'Username', username, limit: 30),
          const Text(
            'Password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: 'Change password',
            child: InkWell(
              key: const ValueKey('profile-password'),
              onTap: () => context.push('/settings/password'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          field(
            'email',
            'Email',
            email,
            limit: 254,
            type: TextInputType.emailAddress,
          ),
          field(
            'phone',
            'Phone number',
            phone,
            limit: 25,
            type: TextInputType.phone,
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
                  .read(profileEditorProvider.notifier)
                  .save(
                    ProfileDetails(
                      first: first.text,
                      last: last.text,
                      username: username.text,
                      email: email.text,
                      phone: phone.text,
                    ),
                  );
              setState(() => error = result);
              if (result == null) {
                if (context.canPop()) context.pop();
              }
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => context.push('/account/delete'),
              child: const Text(
                'DELETE ACCOUNT',
                style: TextStyle(
                  color: LearningColors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _settingsLink(BuildContext context, String title, String route) =>
    ListTile(
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

Widget _settingsSwitch(
  String title,
  bool value,
  ValueChanged<bool> onChanged,
) => SwitchListTile(
  contentPadding: EdgeInsets.zero,
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  value: value,
  onChanged: onChanged,
  activeThumbColor: LearningColors.green,
);

/// Settings > Preferences: lesson experience toggles and the home-screen
/// streak widget.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(previewControllerProvider),
        vm = ref.read(previewControllerProvider.notifier);
    return PreviewPage(
      title: 'Preferences',
      children: [
        const Text('LESSON EXPERIENCE', style: sectionStyle),
        const SizedBox(height: 10),
        _settingsSwitch('Sound effects', s.sound, vm.setSound),
        const Divider(),
        const SizedBox(height: 25),
        const Text('WIDGETS', style: sectionStyle),
        const SizedBox(height: 10),
        _settingsLink(context, 'Streak widgets', '/streak/widgets'),
      ],
    );
  }
}

/// Settings > Notifications: practice reminder schedule.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Notifications',
    children: [
      _settingsLink(context, 'Practice reminders', '/settings/reminders'),
    ],
  );
}

/// Settings > Privacy settings.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(previewControllerProvider),
        vm = ref.read(previewControllerProvider.notifier);
    return PreviewPage(
      title: 'Privacy settings',
      children: [_settingsSwitch('Private profile', s.private, vm.setPrivate)],
    );
  }
}

/// Settings > Help Center: connection recovery and sync status.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Help Center',
    children: [
      _settingsLink(context, 'Connection and recovery', '/recovery'),
      const Divider(),
      _settingsLink(context, 'Sync status', '/sync'),
    ],
  );
}

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({this.permissionDenied = false, super.key});
  final bool permissionDenied;
  @override
  ConsumerState<ReminderScreen> createState() => _ReminderState();
}

class _ReminderState extends ConsumerState<ReminderScreen> {
  bool get denied => widget.permissionDenied;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(previewControllerProvider),
        vm = ref.read(previewControllerProvider.notifier);
    return PreviewPage(
      title: 'Practice reminders',
      children: [
        const SizedBox(height: 24),
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
      ],
    );
  }
}

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({
    this.initialOffline = false,
    this.needsReview = false,
    super.key,
  });
  final bool initialOffline, needsReview;
  @override
  ConsumerState<SyncScreen> createState() => _SyncState();
}

class _SyncState extends ConsumerState<SyncScreen> {
  bool offline = false, conflict = false;
  @override
  void initState() {
    super.initState();
    offline = widget.initialOffline;
    conflict = widget.needsReview;
  }

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
            : 'Your progress is up to date',
        textAlign: TextAlign.center,
        style: headingStyle,
      ),
      const SizedBox(height: 20),
      LearningCard(
        child: Text(
          conflict
              ? 'Your answer is saved. Continue with a current lesson.'
              : 'Keep learning to build your streak and reach your daily goal.',
          style: const TextStyle(fontSize: 18),
        ),
      ),
      const SizedBox(height: 20),
      ReferenceButton(
        label: offline ? 'RECONNECT' : 'REFRESH',
        onPressed: () => setState(() {
          offline = false;
          conflict = false;
        }),
      ),
    ],
  );
}

enum RecoveryFailure { connection, signIn, rateLimited }

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({this.failure = RecoveryFailure.connection, super.key});
  final RecoveryFailure failure;
  @override
  State<RecoveryScreen> createState() => _RecoveryState();
}

class _RecoveryState extends State<RecoveryScreen> {
  bool recovered = false;
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Connection',
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
            : widget.failure == RecoveryFailure.signIn
            ? 'Sign in to continue'
            : widget.failure == RecoveryFailure.rateLimited
            ? 'Let’s take a short break'
            : 'Something went wrong',
        textAlign: TextAlign.center,
        style: headingStyle,
      ),
      const SizedBox(height: 18),
      const Text(
        'Your answers are saved. Try again to continue learning.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: ReferenceColors.muted),
      ),
      const SizedBox(height: 30),
      ReferenceButton(
        label: recovered
            ? 'CONTINUE'
            : widget.failure == RecoveryFailure.signIn
            ? 'LOG IN'
            : 'RETRY',
        onPressed: () => recovered
            ? context.go('/home')
            : widget.failure == RecoveryFailure.signIn
            ? context.push('/login')
            : setState(() => recovered = true),
      ),
    ],
  );
}
