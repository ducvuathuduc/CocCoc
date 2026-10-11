import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/legal_repository.dart';
import '../domain/legal_models.dart';

final legalRepositoryProvider = Provider<LegalRepository>(
  (ref) => const MockLegalRepository(),
);

/// The document shown by a legal reader page.
final legalDocumentProvider = Provider.family<LegalDocument, LegalDocumentKind>(
  (ref, kind) => ref.watch(legalRepositoryProvider).document(kind),
);
