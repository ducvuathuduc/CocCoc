import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_theme.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/legal_controller.dart';
import '../domain/legal_models.dart';

/// In-app document reader for Terms, Privacy Policy and Acknowledgements:
/// top bar with close, title, scrollable headed sections.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({required this.kind, super.key});
  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(legalDocumentProvider(kind));
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
              title: doc.title,
              onClose: () =>
                  context.canPop() ? context.pop() : context.go('/settings'),
            ),
            Expanded(
              child: Scrollbar(
                child: ListView(
                  key: ValueKey('legal-${kind.name}-list'),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  children: [
                    Text(
                      doc.updated.toUpperCase(),
                      style: sectionStyle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Text(doc.intro, style: _bodyStyle),
                    const SizedBox(height: 10),
                    for (final s in doc.sections) ...[
                      const SizedBox(height: 18),
                      Text(s.heading, style: _headingStyle),
                      const SizedBox(height: 6),
                      Text(s.body, style: _bodyStyle),
                    ],
                    if (kind == LegalDocumentKind.acknowledgements) ...[
                      const SizedBox(height: 28),
                      const Divider(
                        color: ReferenceColors.border,
                        thickness: 2,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        key: const ValueKey('legal-all-licenses'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: 'COC English',
                        ),
                        child: const Text(
                          'VIEW ALL LICENSES',
                          style: TextStyle(
                            color: LearningColors.blue,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _headingStyle = TextStyle(
  fontSize: 19,
  fontWeight: FontWeight.w700,
  color: ReferenceColors.ink,
);

const _bodyStyle = TextStyle(
  fontSize: 16,
  height: 1.45,
  color: ReferenceColors.muted,
);
