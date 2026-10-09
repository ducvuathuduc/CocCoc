import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/application/preview_controller.dart';

class ProfileDetails {
  const ProfileDetails({
    required this.first,
    required this.last,
    required this.username,
    required this.email,
    this.phone = '',
  });
  final String first, last, username, email, phone;
}

final profileEditorProvider =
    NotifierProvider<ProfileEditorController, ProfileDetails>(
      ProfileEditorController.new,
    );

class ProfileEditorController extends Notifier<ProfileDetails> {
  @override
  ProfileDetails build() {
    final p = ref.read(previewControllerProvider);
    final names = p.name.split(' ');
    return ProfileDetails(
      first: names.first,
      last: names.skip(1).join(' '),
      username: p.email.split('@').first,
      email: p.email,
    );
  }

  String? save(ProfileDetails draft) {
    final first = draft.first.trim(),
        last = draft.last.trim(),
        username = draft.username.trim(),
        phone = draft.phone.trim();
    if (first.isEmpty || first.length > 60 || last.length > 60) {
      return 'Enter a first and last name of up to 60 characters.';
    }
    final fullName = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (fullName.length > 60) return 'Use a full name of up to 60 characters.';
    if (!RegExp(r'^[A-Za-z0-9._]{3,30}$').hasMatch(username)) {
      return 'Use 3–30 letters, numbers, periods or underscores for your username.';
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (phone.isNotEmpty &&
        (digits < 6 ||
            digits > 15 ||
            !RegExp(r'^\+?[0-9 ()-]{6,25}$').hasMatch(phone))) {
      return 'Enter a valid phone number.';
    }
    final error = ref
        .read(previewControllerProvider.notifier)
        .saveProfile(fullName, draft.email);
    if (error != null) return error;
    state = ProfileDetails(
      first: first,
      last: last,
      username: username,
      email: draft.email.trim(),
      phone: phone,
    );
    return null;
  }
}
