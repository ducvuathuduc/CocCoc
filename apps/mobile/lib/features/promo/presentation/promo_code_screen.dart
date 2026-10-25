import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/presentation/hub_screens.dart';
import '../application/promo_controller.dart';

/// Android source: Mobbin flow 098f538c, frames 2–4. Native text, field,
/// close control and bottom-pinned Apply; repository failures remain inline.
class PromoCodeScreen extends ConsumerStatefulWidget {
  const PromoCodeScreen({super.key});
  static const route = '/settings/promo';
  @override
  ConsumerState<PromoCodeScreen> createState() => _PromoCodeScreenState();
}

class _PromoCodeScreenState extends ConsumerState<PromoCodeScreen> {
  final _code = TextEditingController();

  // Field colours shared with Edit profile (palette-checked there).
  static const _fieldFill = Color(0xFFF7F7F7);
  static const _fieldBorder = Color(0xFFE5E5E5);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(promoControllerProvider.notifier).redeem(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(promoContentProvider);
    final state = ref.watch(promoControllerProvider);
    final reward = state.reward;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 2),
    );
    if (reward == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 24),
                  color: ReferenceColors.disabled,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(15, 9, 15, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        content.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        content.body,
                        style: const TextStyle(
                          fontSize: 17,
                          color: ReferenceColors.ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const ValueKey('promo-code-field'),
                        controller: _code,
                        enabled: !state.busy,
                        maxLength: 32,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9-]'),
                          ),
                        ],
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          ref.read(promoControllerProvider.notifier).edited();
                          setState(() {});
                        },
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.2,
                          color: ReferenceColors.ink,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: _fieldFill,
                          hintText: content.hint,
                          hintStyle: const TextStyle(
                            color: ReferenceColors.disabled,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: border(_fieldBorder),
                          enabledBorder: border(
                            state.failure == null
                                ? _fieldBorder
                                : LearningColors.red,
                          ),
                          focusedBorder: border(
                            state.failure == null
                                ? _fieldBorder
                                : LearningColors.red,
                          ),
                          disabledBorder: border(_fieldBorder),
                        ),
                      ),
                      if (state.failure != null) ...[
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            content.error(state.failure!),
                            key: const ValueKey('promo-error'),
                            style: const TextStyle(
                              color: LearningColors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
                child: ReferenceButton(
                  key: const ValueKey('promo-redeem'),
                  label: state.busy ? '' : content.action,
                  leading: state.busy ? const _PromoProcessing() : null,
                  backgroundColor: LearningColors.blue,
                  edgeColor: LearningColors.blueDark,
                  minHeight: 44,
                  textStyle: const TextStyle(fontSize: 14),
                  onPressed: state.busy || _code.text.trim().isEmpty
                      ? null
                      : _submit,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PreviewPage(
      title: content.pageTitle,
      children: [
        const SizedBox(height: 24),

        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: LearningColors.correct,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 60,
              color: LearningColors.green,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          content.successTitle,
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 12),
        Text(
          content.reward(reward),
          key: const ValueKey('promo-reward'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: ReferenceColors.muted),
        ),
        const SizedBox(height: 32),
        ReferenceButton(
          key: const ValueKey('promo-continue'),
          label: content.continueAction,
          backgroundColor: LearningColors.blue,
          edgeColor: LearningColors.blueDark,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ],
    );
  }
}

class _PromoProcessing extends StatelessWidget {
  const _PromoProcessing();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Applying promo code',
    liveRegion: true,
    child: const ExcludeSemantics(
      child: Text(
        '•••',
        style: TextStyle(color: Colors.white, letterSpacing: 3, fontSize: 16),
      ),
    ),
  );
}
