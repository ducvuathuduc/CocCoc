import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/presentation/hub_screens.dart';
import '../application/profile_editor_controller.dart';
import '../application/avatar_controller.dart';
import '../application/settings_extras_controller.dart';
import '../data/settings_repository.dart';
import '../../notifications/presentation/notification_screens.dart';
import '../../phone/application/phone_verification_controller.dart';
import '../../phone/presentation/phone_verification_screens.dart';
import '../application/account_preferences_controller.dart';
import '../application/email_verification_controller.dart';
import '../application/account_sync_controller.dart';
import '../../notifications/application/notification_settings_controller.dart';
import '../../notifications/domain/notification_models.dart';
import '../../reminders/application/reminder_coordinator.dart';
import 'avatar_motion.dart';
import '../../billing/presentation/billing_checkout.dart';
import '../../appearance/presentation/dark_mode_setting.dart';

export 'delete_account_screen.dart';
export 'signup_flow.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key, this.userId, this.secret});
  final String? userId, secret;
  @override
  ConsumerState<VerificationScreen> createState() => _VerificationState();
}

class _VerificationState extends ConsumerState<VerificationScreen> {
  bool sent = false;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null || widget.secret != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !ref.read(appConfigProvider).isApi) return;
        ref
            .read(emailVerificationProvider.notifier)
            .completeLink(widget.userId ?? '', widget.secret ?? '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.referencePalette;
    final api = ref.watch(appConfigProvider).isApi;
    final preview = api ? null : ref.watch(previewControllerProvider);
    final real = api ? ref.watch(emailVerificationProvider) : null;
    final verified = api ? real!.verified : preview!.verified;
    final email = api ? real!.email : preview!.email;
    final waiting = api && (real!.loading || real.busy);
    final linkSent = api ? real!.sent : sent;
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
          verified ? 'Email verified!' : 'Check your email',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 18),
        Text(
          verified
              ? 'Your email is verified.'
              : '$email\nVerify your email to keep your account up to date.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: palette.muted),
        ),
        const SizedBox(height: 30),
        ReferenceButton(
          label: 'CONTINUE',
          onPressed: waiting
              ? null
              : () {
                  if (verified) {
                    context.go('/home');
                  } else if (api) {
                    ref.read(emailVerificationProvider.notifier).refresh();
                  } else {
                    ref.read(previewControllerProvider.notifier).verify();
                  }
                },
        ),
        const SizedBox(height: 20),
        if (!verified)
          ReferenceButton(
            label: linkSent ? 'LINK READY' : 'RESEND LINK',
            outlined: true,
            onPressed: linkSent || waiting || (api && !real!.ready)
                ? null
                : api
                ? () => ref.read(emailVerificationProvider.notifier).resend()
                : () => setState(() => sent = true),
          ),
        if (real?.error != null) ...[
          const SizedBox(height: 12),
          Text(
            real!.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: LearningColors.red),
          ),
        ],
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
    final palette = context.referencePalette;
    Widget row(String title, String route, {String? subtitle}) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 16, color: palette.disabled),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: palette.disabled),
      onTap: () => context.push(route),
    );

    Widget textLink(String text, String route) => InkWell(
      key: ValueKey('settings-link-${route.split('/').last}'),
      onTap: () => context.push(route),
      child: Padding(
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
        const BillingManagement(),
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
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (!context.mounted) return;
                    final auth = ref.read(authControllerProvider);
                    if (auth.user != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            auth.error ?? 'Could not sign out. Please retry.',
                          ),
                        ),
                      );
                      return;
                    }
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

        textLink('TERMS', '/settings/legal/terms'),
        textLink('PRIVACY POLICY', '/settings/legal/privacy'),
        textLink('ACKNOWLEDGEMENTS', '/settings/legal/acknowledgements'),
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

// Editing profile geometry, measured on the Duolingo "Editing profile" flow
// (catalog sc_198760c7…, 393 pt wide): 49 pt fields on a 95 pt row pitch,
// 12 pt from label glyphs to the field, a 94 pt avatar ring and 18 pt
// CHANGE AVATAR label; the phone placeholder uses the disabled grey #B0B0B0.
const double _profileFieldHeight = 49;
const double _profileFieldInset = 17;
const double _profileLabelGap = 5;
const double _profileRowGap = 14;

class _EditProfileState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController first, last, username, email, phone;
  late final ProviderSubscription<ProfileDetails> _profileSubscription;
  late int _appliedDataVersion;
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
    _appliedDataVersion = s.dataVersion;
    _profileSubscription = ref.listenManual(profileEditorProvider, (
      previous,
      next,
    ) {
      if (!mounted || next.dataVersion == _appliedDataVersion) return;
      _apply(next);
    });
  }

  void _apply(ProfileDetails details) {
    _appliedDataVersion = details.dataVersion;
    first.text = details.first;
    last.text = details.last;
    username.text = details.username;
    email.text = details.email;
    phone.text = details.phone;
    if (mounted) setState(() => error = null);
  }

  @override
  void dispose() {
    _profileSubscription.close();
    first.dispose();
    last.dispose();
    username.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.referencePalette;
    final avatar = ref.watch(avatarControllerProvider);
    final editor = ref.watch(profileEditorProvider);
    Widget field(
      String id,
      String label,
      TextEditingController controller, {
      int limit = 60,
      TextInputType? type,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: _profileRowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: _profileLabelGap),
          TextField(
            key: ValueKey('profile-$id'),
            controller: controller,
            maxLength: limit,
            keyboardType: type,
            textInputAction: TextInputAction.next,
            enabled: !editor.loading && !editor.busy,
            style: TextStyle(fontSize: 20, color: palette.ink),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: palette.raisedSurface,
              hintText: id == 'phone' ? 'Add phone number' : null,
              hintStyle: TextStyle(fontSize: 20, color: palette.disabled),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _profileFieldInset,
                vertical: 9.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.border, width: 2),
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
      backgroundColor: palette.surface,
      appBar: AppBar(
        toolbarHeight: 49,
        foregroundColor: palette.ink,
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Divider(height: 2, thickness: 2, color: palette.border),
        ),
      ),
      body: ListView(
        key: const ValueKey('profile-editor-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
        children: [
          if (editor.loading)
            Semantics(
              liveRegion: true,
              label: 'Loading profile',
              child: const LinearProgressIndicator(minHeight: 2),
            ),
          Center(
            child: Semantics(
              button: true,
              label: 'Change avatar',
              child: InkWell(
                onTap: () => context.push('/settings/avatar'),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 94,
                  height: 94,
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
                            width: 84,
                            height: 84,
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
                  fontSize: 18,
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
          const SizedBox(height: _profileLabelGap),
          Semantics(
            button: true,
            label: 'Change password',
            child: InkWell(
              key: const ValueKey('profile-password'),
              onTap: () => context.push('/settings/password'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: _profileFieldHeight,
                decoration: BoxDecoration(
                  color: palette.raisedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: _profileRowGap),
          field(
            'email',
            'Email',
            email,
            limit: 254,
            type: TextInputType.emailAddress,
          ),
          _PhoneRow(fallback: phone.text),
          if (error ?? editor.error case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    message,
                    style: const TextStyle(color: LearningColors.red),
                  ),
                  if (!editor.loaded && !editor.loading)
                    TextButton(
                      key: const ValueKey('profile-retry'),
                      onPressed: () =>
                          ref.read(profileEditorProvider.notifier).retry(),
                      child: const Text('RETRY'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 25),
          ReferenceButton(
            label: 'SAVE CHANGES',
            onPressed: !editor.loaded || editor.loading || editor.busy
                ? null
                : () async {
                    setState(() => error = null);
                    final result = await ref
                        .read(profileEditorProvider.notifier)
                        .save(
                          ProfileDetails(
                            first: first.text,
                            last: last.text,
                            username: username.text,
                            email: email.text,
                            phone:
                                ref
                                    .read(phoneVerificationControllerProvider)
                                    .verified
                                    ?.e164 ??
                                phone.text,
                          ),
                        );
                    if (!context.mounted) return;
                    setState(() => error = result);
                    if (result == null && context.canPop()) context.pop();
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

/// Profile "Phone number" row: opens the SMS verification flow and shows the
/// verified number masked, as in Duolingo.
class _PhoneRow extends ConsumerWidget {
  const _PhoneRow({required this.fallback});
  final String fallback;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.referencePalette;
    final verified = ref.watch(phoneVerificationControllerProvider).verified;
    final value = verified?.masked ?? fallback;
    return Padding(
      padding: const EdgeInsets.only(bottom: _profileRowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone number',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: _profileLabelGap),
          Semantics(
            button: true,
            label: value.isEmpty ? 'Add phone number' : 'Phone number $value',
            child: InkWell(
              key: const ValueKey('profile-phone'),
              onTap: () {
                ref.read(phoneVerificationControllerProvider.notifier).begin();
                context.push(phoneRoute);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: _profileFieldHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: _profileFieldInset,
                ),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: palette.raisedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border, width: 2),
                ),
                child: Text(
                  value.isEmpty ? 'Add phone number' : value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    color: value.isEmpty ? palette.disabled : palette.ink,
                  ),
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
      trailing: Icon(
        Icons.chevron_right,
        color: context.referencePalette.disabled,
      ),
      onTap: () => context.push(route),
    );

Widget _settingsSwitch(
  String title,
  bool value,
  ValueChanged<bool>? onChanged,
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
    if (ref.watch(appConfigProvider).isApi) {
      final state = ref.watch(accountPreferencesProvider);
      final vm = ref.read(accountPreferencesProvider.notifier);
      return PreviewPage(
        title: 'Preferences',
        children: [
          const Text('LESSON EXPERIENCE', style: sectionStyle),
          const SizedBox(height: 10),
          _settingsSwitch(
            'Sound effects',
            state.preferences?.soundEffects ?? false,
            state.ready && !state.busy ? vm.setSoundEffects : null,
          ),
          const Divider(),
          const DarkModeSetting(),
          const Divider(),
          if (state.error != null) ...[
            Text(
              state.error!,
              style: const TextStyle(color: LearningColors.red),
            ),
            TextButton(
              onPressed: state.busy ? null : vm.retry,
              child: const Text('RETRY'),
            ),
          ],
          const SizedBox(height: 25),
          const Text('WIDGETS', style: sectionStyle),
          const SizedBox(height: 10),
          _settingsLink(context, 'Streak widgets', '/streak/widgets'),
        ],
      );
    }
    final s = ref.watch(previewControllerProvider),
        vm = ref.read(previewControllerProvider.notifier);
    return PreviewPage(
      title: 'Preferences',
      children: [
        const Text('LESSON EXPERIENCE', style: sectionStyle),
        const SizedBox(height: 10),
        _settingsSwitch('Sound effects', s.sound, vm.setSound),
        const Divider(),
        const DarkModeSetting(),
        const Divider(),
        const SizedBox(height: 25),
        const Text('WIDGETS', style: sectionStyle),
        const SizedBox(height: 10),
        _settingsLink(context, 'Streak widgets', '/streak/widgets'),
      ],
    );
  }
}

/// Settings > Notifications: Reminders / Friends / Leaderboards /
/// Announcements / Friend Nudges, each with Push / Email toggles.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const NotificationsHubScreen();
}

/// Settings > Privacy settings.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appConfigProvider).isApi) {
      final state = ref.watch(accountPreferencesProvider);
      final vm = ref.read(accountPreferencesProvider.notifier);
      return PreviewPage(
        title: 'Privacy settings',
        children: [
          _settingsSwitch(
            'Private profile',
            state.profile?.publicOptIn == false,
            state.ready && !state.busy ? vm.setPrivate : null,
          ),
          if (state.error != null) ...[
            Text(
              state.error!,
              style: const TextStyle(color: LearningColors.red),
            ),
            TextButton(
              onPressed: state.busy ? null : vm.retry,
              child: const Text('RETRY'),
            ),
          ],
        ],
      );
    }
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

InputDecoration _settingsFieldDecoration(
  BuildContext context, {
  String? hint,
  String? error,
}) => InputDecoration(
  counterText: '',
  filled: true,
  fillColor: context.referencePalette.raisedSurface,
  hintText: hint,
  errorText: error,
  errorMaxLines: 3,
  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: context.referencePalette.border, width: 2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: LearningColors.blue, width: 2),
  ),
);

TextStyle _fieldLabelStyle(BuildContext context) => TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: context.referencePalette.ink,
);

/// Settings > Duolingo for Schools: join a teacher's classroom by code.
class SchoolsSettingsScreen extends ConsumerStatefulWidget {
  const SchoolsSettingsScreen({super.key});
  @override
  ConsumerState<SchoolsSettingsScreen> createState() => _SchoolsState();
}

class _SchoolsState extends ConsumerState<SchoolsSettingsScreen> {
  final code = TextEditingController();
  @override
  void initState() {
    super.initState();
    code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.referencePalette;
    final copy = ref.watch(settingsRepositoryProvider).schools,
        s = ref.watch(settingsExtrasControllerProvider),
        vm = ref.read(settingsExtrasControllerProvider.notifier);
    return PreviewPage(
      title: 'Duolingo for Schools',
      children: [
        Text(copy.heading, style: headingStyle),
        const SizedBox(height: 12),
        Text(copy.body, style: TextStyle(fontSize: 17, color: palette.muted)),
        const SizedBox(height: 24),
        if (s.classroom != null) ...[
          Text(
            '${copy.joinedPrefix} ${s.classroom}',
            key: const ValueKey('schools-joined'),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: LearningColors.greenDark,
            ),
          ),
          const SizedBox(height: 20),
          ReferenceButton(
            label: copy.leaveLabel,
            outlined: true,
            foregroundColor: LearningColors.red,
            onPressed: vm.leaveClassroom,
          ),
        ] else ...[
          Text(copy.codeLabel, style: _fieldLabelStyle(context)),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('schools-code'),
            controller: code,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(fontSize: 20, color: palette.ink),
            decoration: _settingsFieldDecoration(
              context,
              hint: copy.codeHint,
              error: s.joinError,
            ),
          ),
          const SizedBox(height: 20),
          ReferenceButton(
            label: copy.joinLabel,
            backgroundColor: LearningColors.blue,
            edgeColor: LearningColors.blueDark,
            onPressed: code.text.trim().isEmpty || s.joining
                ? null
                : () => vm.joinClassroom(code.text),
          ),
        ],
      ],
    );
  }
}

/// Settings > Social accounts: link or unlink sign-in providers.
class SocialAccountsScreen extends ConsumerWidget {
  const SocialAccountsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(settingsRepositoryProvider).socialAccounts,
        s = ref.watch(settingsExtrasControllerProvider),
        vm = ref.read(settingsExtrasControllerProvider.notifier);
    return PreviewPage(
      title: 'Social accounts',
      children: [
        for (var i = 0; i < accounts.length; i++) ...[
          if (i > 0) const Divider(),
          _settingsSwitch(
            accounts[i].name,
            s.connected.contains(accounts[i].id),
            (on) => vm.setSocial(accounts[i].id, on),
          ),
        ],
        if (s.error case final error?)
          Text(error, style: const TextStyle(color: LearningColors.red)),
      ],
    );
  }
}

/// Settings > Feedback: pick a topic, describe it, submit.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<FeedbackScreen> {
  final message = TextEditingController();
  int topic = 0;
  @override
  void initState() {
    super.initState();
    message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _submit(FeedbackContent copy) async {
    final sent = await ref
        .read(settingsExtrasControllerProvider.notifier)
        .sendFeedback(copy.topics[topic], message.text);
    if (!mounted) return;
    if (!sent) {
      final error = ref.read(settingsExtrasControllerProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    await showLearningNotice(context, copy.thanksTitle, copy.thanksBody);
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.referencePalette;
    final copy = ref.watch(settingsRepositoryProvider).feedback,
        sending = ref.watch(settingsExtrasControllerProvider).sending;
    return PreviewPage(
      title: 'Feedback',
      children: [
        Text(copy.topicLabel, style: _fieldLabelStyle(context)),
        const SizedBox(height: 12),
        for (var i = 0; i < copy.topics.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              selected: i == topic,
              button: true,
              child: InkWell(
                key: ValueKey('feedback-topic-$i'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => topic = i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: i == topic ? palette.blueFill : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i == topic
                          ? ReferenceColors.blueBorder
                          : palette.border,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    copy.topics[i],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: i == topic ? LearningColors.blue : palette.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(copy.messageLabel, style: _fieldLabelStyle(context)),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('feedback-message'),
          controller: message,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          style: TextStyle(fontSize: 18, color: context.referencePalette.ink),
          decoration: _settingsFieldDecoration(context, hint: copy.messageHint),
        ),
        const SizedBox(height: 20),
        ReferenceButton(
          label: copy.submitLabel,
          backgroundColor: LearningColors.blue,
          edgeColor: LearningColors.blueDark,
          onPressed: message.text.trim().isEmpty || sending
              ? null
              : () => _submit(copy),
        ),
      ],
    );
  }
}

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({this.permissionDenied = false, super.key});
  final bool permissionDenied;
  @override
  ConsumerState<ReminderScreen> createState() => _ReminderState();
}

class _ReminderState extends ConsumerState<ReminderScreen> {
  bool permissionRefused = false;
  bool permissionBusy = false;
  bool get denied => widget.permissionDenied || permissionRefused;
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(appConfigProvider).isApi;
    final preview = api ? null : ref.watch(previewControllerProvider);
    final real = api ? ref.watch(notificationSettingsControllerProvider) : null;
    final enabled = api
        ? real!.isOn('practice', NotificationChannel.push)
        : preview!.reminder;
    final time = api
        ? real!.ready
              ? '${real.reminderTime.hour.toString().padLeft(2, '0')}:${real.reminderTime.minute.toString().padLeft(2, '0')}'
              : '—'
        : preview!.reminderTime;
    final canEdit =
        !permissionBusy &&
        (!api || (real!.ready && !real.busy && real.error == null));
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
          value: enabled,
          onChanged: !canEdit
              ? null
              : (value) async {
                  if (!api) {
                    ref
                        .read(previewControllerProvider.notifier)
                        .reminder(enabled: value);
                    return;
                  }
                  final vm = ref.read(
                    notificationSettingsControllerProvider.notifier,
                  );
                  final generation = vm.generation;
                  if (value) {
                    setState(() => permissionBusy = true);
                    final granted = await ref
                        .read(reminderCoordinatorProvider)
                        .acceptPermissionOffer();
                    if (mounted) setState(() => permissionBusy = false);
                    if (!mounted || generation != vm.generation) return;
                    if (!granted) {
                      setState(() => permissionRefused = true);
                      return;
                    }
                  }
                  await vm.toggle('practice', NotificationChannel.push);
                },
          title: const Text(
            'Daily reminder',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reminder time'),
          trailing: Text(time, style: headingStyle),
          onTap: !canEdit
              ? null
              : () async {
                  final vm = api
                      ? ref.read(
                          notificationSettingsControllerProvider.notifier,
                        )
                      : null;
                  final generation = vm?.generation;
                  final t = await showTimePicker(
                    context: context,
                    initialTime: api
                        ? TimeOfDay(
                            hour: real!.reminderTime.hour,
                            minute: real.reminderTime.minute,
                          )
                        : const TimeOfDay(hour: 19, minute: 0),
                  );
                  if (t != null && mounted) {
                    if (api) {
                      if (generation == vm!.generation) {
                        await vm.setReminderTime(
                          ReminderTime(t.hour, t.minute),
                        );
                      }
                      return;
                    }
                    ref
                        .read(previewControllerProvider.notifier)
                        .reminder(
                          enabled: enabled,
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
                : enabled
                ? 'Reminder preference saved for $time.'
                : 'Turn reminders on whenever you’re ready.',
            style: const TextStyle(fontSize: 17),
          ),
        ),
        if (real?.error != null) ...[
          Text(real!.error!, style: const TextStyle(color: LearningColors.red)),
          TextButton(
            onPressed: () => ref
                .read(notificationSettingsControllerProvider.notifier)
                .retry(),
            child: const Text('RETRY'),
          ),
        ],
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
  Widget build(BuildContext context) {
    final api = ref.watch(appConfigProvider).isApi;
    final real = api ? ref.watch(accountSyncProvider) : null;
    final offline = api ? real!.error != null : this.offline;
    final conflict = api ? real!.rejected > 0 : this.conflict;
    final busy = real?.busy == true;
    final title = busy
        ? 'Checking sync'
        : conflict
        ? 'Review needed'
        : offline
        ? 'Sync unavailable'
        : api && !real!.current
        ? 'Waiting to sync'
        : 'Your progress is up to date';
    return PreviewPage(
      title: 'Sync status',
      children: [
        const SizedBox(height: 35),
        Icon(
          offline || busy || (api && !real!.current)
              ? Icons.cloud_off_rounded
              : Icons.cloud_done_rounded,
          size: 90,
          color: LearningColors.blue,
        ),
        const SizedBox(height: 25),
        Text(
          api
              ? title
              : conflict
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
            conflict ? 'Your answer is saved. Continue with a current lesson.' : 'Keep learning to build your streak and reach your daily goal.',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 20),
        ReferenceButton(
          label: api && conflict
              ? 'CONTINUE'
              : offline
              ? 'RECONNECT'
              : 'REFRESH',
          onPressed: busy
              ? null
              : () {
                  if (api) {
                    if (conflict) {
                      context.go('/home');
                    } else {
                      ref.read(accountSyncProvider.notifier).refresh();
                    }
                    return;
                  }
                  setState(() {
                    this.offline = false;
                    this.conflict = false;
                  });
                },
        ),
      ],
    );
  }
}

enum RecoveryFailure { connection, signIn, rateLimited }

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({this.failure = RecoveryFailure.connection, super.key});
  final RecoveryFailure failure;
  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryState();
}

class _RecoveryState extends ConsumerState<RecoveryScreen> {
  bool recovered = false;
  bool checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !ref.read(appConfigProvider).isApi) return;
      await ref.read(accountSyncProvider.notifier).refresh();
      if (mounted) setState(() => checked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(appConfigProvider).isApi;
    final sync = api ? ref.watch(accountSyncProvider) : null;
    final recovered = api ? checked && sync!.current : this.recovered;
    final busy = api && (!checked || sync!.busy);
    return PreviewPage(
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
        Text(
          'Your answers are saved. Try again to continue learning.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: context.referencePalette.muted),
        ),
        const SizedBox(height: 30),
        ReferenceButton(
          label: recovered
              ? 'CONTINUE'
              : widget.failure == RecoveryFailure.signIn
              ? 'LOG IN'
              : 'RETRY',
          onPressed: busy
              ? null
              : () {
                  if (recovered) {
                    context.go('/home');
                  } else if (widget.failure == RecoveryFailure.signIn) {
                    context.push('/login');
                  } else if (api) {
                    ref.read(accountSyncProvider.notifier).refresh();
                  } else {
                    setState(() => this.recovered = true);
                  }
                },
        ),
      ],
    );
  }
}
