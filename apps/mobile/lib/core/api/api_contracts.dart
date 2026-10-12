/// Schema-mapped wire DTOs for docs/api/openapi.yaml (P1-CONTRACT-001).
///
/// `fromJson` validates against the exact component schema before decoding
/// and throws [ContractViolation] on malformed payloads or wrong union
/// variants. Regenerate with `node tools/blueprint/generate-dart-contracts.mjs`;
/// `pnpm contracts:check` fails when the generated files drift.
library;

export 'contract_validator.dart'
    show ContractValidator, ContractViolation, JsonPresence;
export 'generated/api_models.g.dart';
export 'generated/api_schemas.g.dart' show apiContractSourceSha256;
