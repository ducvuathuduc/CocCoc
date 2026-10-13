import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/presentation/hub_screens.dart';
import '../application/promo_controller.dart';

/// Redeem a promo code (audit row 32). No Gummble screens exist for this
/// flow; it follows the app's settings pages (PreviewPage header, grey field
/// with blue focus ring as in Edit profile, blue CTA).
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
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 2),
    );
    return PreviewPage(
      title: content.pageTitle,
      children: [
        const SizedBox(height: 24),
        if (reward == null) ...[
          Text(content.title, style: headingStyle),
          const SizedBox(height: 8),
          Text(
            content.body,
            style: const TextStyle(fontSize: 17, color: ReferenceColors.muted),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('promo-code-field'),
            controller: _code,
            enabled: !state.busy,
            maxLength: 32,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            ],
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              ref.read(promoControllerProvider.notifier).edited();
              setState(() {});
            },
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              fontSize: 20,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: ReferenceColors.ink,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: _fieldFill,
              hintText: content.hint,
              hintStyle: const TextStyle(
                letterSpacing: 0,
                fontWeight: FontWeight.w400,
                color: ReferenceColors.disabled,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              border: border(_fieldBorder),
              enabledBorder: border(
                state.failure != null ? LearningColors.red : _fieldBorder,
              ),
              focusedBorder: border(
                state.failure != null
                    ? LearningColors.red
                    : LearningColors.blue,
              ),
            ),
          ),
          if (state.failure != null) ...[
            const SizedBox(height: 10),
            Text(
              content.error(state.failure!),
              key: const ValueKey('promo-error'),
              style: const TextStyle(
                color: LearningColors.red,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ReferenceButton(
            key: const ValueKey('promo-redeem'),
            label: content.action,
            backgroundColor: LearningColors.blue,
            edgeColor: LearningColors.blueDark,
            onPressed: state.busy || _code.text.trim().isEmpty ? null : _submit,
          ),
        ] else ...[
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
      ],
    );
  }
}
