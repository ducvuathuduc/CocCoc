import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/password_change_controller.dart';

class PasswordChangeScreen extends ConsumerWidget {
  const PasswordChangeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(passwordChangeProvider);
    final message = state.error ?? state.validationMessage;
    final vm = ref.read(passwordChangeProvider.notifier);
    const labels = ['Old password', 'New password', 'Confirm password'];
    const ids = ['old', 'new', 'confirm'];
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 49,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Positioned(
                      left: 6,
                      child: IconButton(
                        tooltip: 'Close password',
                        onPressed: state.busy
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close,
                          size: 30,
                          color: ReferenceColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 2,
                thickness: 2,
                color: ReferenceColors.border,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        Text(
                          labels[i],
                          style: const TextStyle(
                            color: ReferenceColors.disabled,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey('password-${ids[i]}'),
                          initialValue: state.values[i],
                          enabled: !state.busy,
                          onChanged: (value) => vm.edit(i, value),
                          obscureText: state.hidden[i],
                          enableSuggestions: false,
                          autocorrect: false,
                          maxLength: 128,
                          textInputAction: i == 2
                              ? TextInputAction.done
                              : TextInputAction.next,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFF7F7F7),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: ReferenceColors.border,
                                width: 2,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: ReferenceColors.border,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: LearningColors.blue,
                                width: 2,
                              ),
                            ),
                            suffixIcon: IconButton(
                              tooltip:
                                  '${state.hidden[i] ? 'Show' : 'Hide'} ${ids[i]} password',
                              onPressed: state.busy
                                  ? null
                                  : () => vm.toggleHidden(i),
                              icon: Icon(
                                state.hidden[i]
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: LearningColors.blue,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                        if (i < 2) const SizedBox(height: 28),
                      ],
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: const TextStyle(
                                fontSize: 17,
                                color: LearningColors.red,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: ReferenceButton(
                  label: state.busy ? 'SAVING…' : 'SAVE',
                  backgroundColor: LearningColors.blue,
                  edgeColor: const Color(0xFF1899D6),
                  onPressed: !state.canSave
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          if (await vm.save() && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
