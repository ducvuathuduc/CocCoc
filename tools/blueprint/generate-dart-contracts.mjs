// Generates schema-mapped Dart DTOs from docs/api/openapi.yaml components (P1-CONTRACT-001).
// Usage: node tools/blueprint/generate-dart-contracts.mjs [--check]
// --check fails when the committed Dart output differs from a fresh generation (idempotency gate).
// Output: apps/mobile/lib/core/api/generated/{api_schemas.g.dart,api_models.g.dart}. Do not edit generated files.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const openapiPath = path.join(root, 'docs/api/openapi.yaml');
const outDir = path.join(root, 'apps/mobile/lib/core/api/generated');
// Git may have checked out existing files as CRLF before .gitattributes was
// added. Hash and compare their canonical LF form without changing the spec.
const normalizeLines = (text) => text.replace(/\r\n/g, '\n');
const openapiText = normalizeLines(fs.readFileSync(openapiPath, 'utf8'));
const api = JSON.parse(openapiText);
const schemas = api.components.schemas;

// Keywords the Dart runtime validator (apps/mobile/lib/core/api/contract_validator.dart) implements.
// Annotation-only keywords are ignored there exactly as Ajv(strict:false) ignores them.
const SUPPORTED = new Set([
  'type', 'properties', 'required', 'additionalProperties', 'items', 'minItems', 'maxItems',
  'minLength', 'maxLength', 'pattern', 'format', 'minimum', 'maximum', 'enum', 'const',
  '$ref', 'anyOf', 'oneOf', 'allOf', 'if', 'then', 'else',
  'discriminator', 'contentEncoding',
]);
const SUPPORTED_FORMATS = new Set(['uuid', 'date-time']);
function audit(schema, where) {
  if (schema === true || schema === false) return;
  if (!schema || typeof schema !== 'object') throw new Error(`${where}: schema must be an object`);
  for (const [key, value] of Object.entries(schema)) {
    if (!SUPPORTED.has(key)) throw new Error(`${where}: unsupported JSON Schema keyword "${key}"; extend contract_validator.dart first`);
    if (key === 'format' && !SUPPORTED_FORMATS.has(value)) throw new Error(`${where}: unsupported format "${value}"`);
    if (key === 'properties') for (const [p, s] of Object.entries(value)) audit(s, `${where}.${p}`);
    else if (['items', 'additionalProperties', 'if', 'then', 'else'].includes(key)) audit(value, `${where}/${key}`);
    else if (['anyOf', 'oneOf', 'allOf'].includes(key)) value.forEach((s, i) => audit(s, `${where}/${key}/${i}`));
  }
}
for (const [name, schema] of Object.entries(schemas)) audit(schema, name);

const RESERVED = new Set(['assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with', 'hashCode', 'runtimeType', 'toJson', 'toString', 'noSuchMethod']);
const pascal = (text) => text.split(/[^A-Za-z0-9]+/).filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join('');
const refName = (ref) => {
  const prefix = '#/components/schemas/';
  if (!ref.startsWith(prefix)) throw new Error(`unsupported $ref ${ref}`);
  return ref.slice(prefix.length);
};
const dartString = (value) => `'${String(value).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'`;

const classes = new Map(); // name -> {kind, ...}
const isUnion = (schema) => Array.isArray(schema.oneOf);

function nullableInner(schema) {
  if (Array.isArray(schema.anyOf) && schema.anyOf.length === 2) {
    const rest = schema.anyOf.filter((s) => s.type !== 'null');
    if (rest.length === 1) return rest[0];
  }
  return null;
}
function literalType(value) {
  if (typeof value === 'string') return 'String';
  if (typeof value === 'boolean') return 'bool';
  if (Number.isInteger(value)) return 'int';
  if (typeof value === 'number') return 'num';
  throw new Error(`unsupported const/enum literal ${JSON.stringify(value)}`);
}
// Encodes a possibly-null expression whose non-null type is [t].
function nullableEncode(t, e) {
  const enc = t.encode('x');
  if (enc === 'x') return e;
  if (enc === 'x.toJson()') return `${e}?.toJson()`;
  return `${e} == null ? null : ${t.encode(`${e}!`)}`;
}
const primitive = (dart, dec) => ({ dart, nullable: false, decode: dec, encode: (e) => e });

// Maps a property schema to a Dart type with decode/encode expression builders.
function typeOf(schema, ctx) {
  const inner = nullableInner(schema);
  if (inner) {
    const t = typeOf(inner, ctx);
    return {
      dart: `${t.dart}?`,
      base: t,
      nullable: true,
      decode: (e) => `${e} == null ? null : ${t.decode(e)}`,
      encode: (e) => nullableEncode(t, e),
    };
  }
  if (schema.$ref) {
    const name = refName(schema.$ref);
    return { dart: name, nullable: false, decode: (e) => `${name}._decode(${e})`, encode: (e) => `${e}.toJson()` };
  }
  if ('const' in schema) {
    const t = literalType(schema.const);
    return primitive(t, (e) => (t === 'int' ? `(${e} as num).toInt()` : `${e} as ${t}`));
  }
  const type = schema.type ?? (schema.enum ? (schema.enum.every((v) => typeof v === 'string') ? 'string' : undefined) : undefined);
  switch (type) {
    case 'string': return primitive('String', (e) => `${e} as String`);
    case 'integer': return primitive('int', (e) => `(${e} as num).toInt()`);
    case 'number': return primitive('num', (e) => `${e} as num`);
    case 'boolean': return primitive('bool', (e) => `${e} as bool`);
    case 'array': {
      const item = typeOf(schema.items ?? {}, `${ctx}Item`);
      const enc = item.encode('x');
      return {
        dart: `List<${item.dart}>`,
        nullable: false,
        decode: (e) => `List<${item.dart}>.unmodifiable((${e} as List<Object?>).map((Object? x) => ${item.decode('x')}))`,
        encode: (e) => (enc === 'x' ? `List<Object?>.of(${e})` : `${e}.map((${item.dart} x) => ${enc}).toList()`),
      };
    }
    case 'object': {
      if (schema.properties) {
        registerObject(ctx, schema, null);
        return { dart: ctx, nullable: false, decode: (e) => `${ctx}._decode(${e})`, encode: (e) => `${e}.toJson()` };
      }
      return {
        dart: 'Map<String, Object?>',
        nullable: false,
        decode: (e) => `Map<String, Object?>.unmodifiable(${e} as Map<Object?, Object?>)`,
        encode: (e) => `Map<String, Object?>.of(${e})`,
      };
    }
    default:
      return { dart: 'Object?', nullable: true, decode: (e) => e, encode: (e) => e };
  }
}

// Flattens allOf [$ref base, inline override] into one property list (typing only; validation stays schema-exact).
function flatten(schema) {
  if (!schema.allOf || schema.properties) return { properties: schema.properties ?? {}, required: schema.required ?? [] };
  const properties = {};
  const required = new Set();
  for (const part of schema.allOf) {
    const resolved = part.$ref ? flatten(schemas[refName(part.$ref)]) : flatten(part);
    for (const [key, value] of Object.entries(resolved.properties)) {
      const prior = properties[key];
      // An override only re-types a field when it names a schema or a literal; otherwise it only narrows validation.
      if (!prior || value.$ref || 'const' in value) properties[key] = value;
    }
    resolved.required.forEach((r) => required.add(r));
  }
  return { properties, required: [...required] };
}

function registerObject(name, schema, topLevel) {
  if (classes.has(name)) return;
  const entry = { kind: 'object', name, topLevel, implements: [], discriminators: new Set(), fields: [] };
  classes.set(name, entry);
  const { properties, required } = flatten(schema);
  const req = new Set(required);
  for (const [prop, propSchema] of Object.entries(properties)) {
    if (RESERVED.has(prop)) throw new Error(`${name}.${prop}: Dart reserved identifier`);
    const isRequired = req.has(prop);
    if (isRequired && 'const' in propSchema) {
      entry.fields.push({ prop, mode: 'const', literal: propSchema.const, dart: literalType(propSchema.const) });
      continue;
    }
    const type = typeOf(propSchema, `${name}${pascal(prop)}`);
    entry.fields.push({ prop, mode: isRequired ? 'required' : type.nullable && nullableInner(propSchema) ? 'presence' : 'optional', type });
  }
}

function discriminatorOf(name, variants) {
  const declared = schemas[name].discriminator?.propertyName;
  const candidates = declared ? [declared] : Object.keys(variants[0].properties);
  for (const key of candidates) {
    const values = variants.map((v) => v.properties[key] && 'const' in v.properties[key] ? v.properties[key].const : undefined);
    if (values.every((v) => v !== undefined) && new Set(values).size === values.length) return { key, values };
  }
  throw new Error(`${name}: no discriminating const property across oneOf variants`);
}

function registerUnion(name, schema) {
  const variants = schema.oneOf.map((part) => {
    if (part.$ref) {
      const vName = refName(part.$ref);
      return { className: vName, ...flatten(schemas[vName]) };
    }
    return { className: null, schema: part, ...flatten(part) };
  });
  const { key, values } = discriminatorOf(name, variants);
  variants.forEach((v, i) => {
    if (!v.className) {
      v.className = `${name}${pascal(String(values[i]))}`;
      registerObject(v.className, v.schema, null);
    }
  });
  classes.set(name, { kind: 'union', name, key, keyType: literalType(values[0]), variants: variants.map((v, i) => ({ className: v.className, value: values[i] })) });
}

for (const [name, schema] of Object.entries(schemas)) {
  if (isUnion(schema)) registerUnion(name, schema);
  else registerObject(name, schema, name);
}
for (const entry of classes.values()) {
  if (entry.kind !== 'union') continue;
  for (const v of entry.variants) {
    const target = classes.get(v.className);
    if (!target || target.kind !== 'object') throw new Error(`${entry.name}: variant ${v.className} is not an object DTO`);
    target.implements.push(entry.name);
    target.discriminators.add(entry.key);
  }
}

const sha = crypto.createHash('sha256').update(openapiText).digest('hex');
const header = (purpose) => `// GENERATED CODE - DO NOT EDIT BY HAND.\n// dart format off\n// Source: docs/api/openapi.yaml (sha256 ${sha}).\n// Generator: tools/blueprint/generate-dart-contracts.mjs (${purpose}).\n`;

function emitObject(c) {
  const lines = [];
  const doc = c.topLevel ? `/// Wire DTO for \`#/components/schemas/${c.topLevel}\`.` : `/// Inline wire object \`${c.name}\` (nested in a component schema).`;
  lines.push(doc);
  lines.push(`final class ${c.name}${c.implements.length ? ` implements ${c.implements.join(', ')}` : ''} {`);
  const params = c.fields.filter((f) => f.mode !== 'const');
  if (params.length === 0) lines.push(`  const ${c.name}();`);
  else {
    lines.push(`  const ${c.name}({`);
    for (const f of params) {
      if (f.mode === 'required') lines.push(`    required this.${f.prop},`);
      else if (f.mode === 'presence') lines.push(`    this.${f.prop} = const JsonPresence<${f.type.base.dart}>.absent(),`);
      else lines.push(`    this.${f.prop},`);
    }
    lines.push('  });');
  }
  lines.push('');
  if (c.topLevel) {
    lines.push(`  /// Validates [json] against the \`${c.topLevel}\` schema, then decodes it.`);
    lines.push(`  /// Throws [ContractViolation] when the payload does not match the contract.`);
    lines.push(`  factory ${c.name}.fromJson(Object? json) {`);
    lines.push(`    ContractValidator.instance.check('${c.topLevel}', json);`);
    lines.push(`    return ${c.name}._decode(json);`);
    lines.push('  }');
    lines.push('');
  }
  lines.push(`  static ${c.name} _decode(Object? json) {`);
  if (params.length === 0) {
    lines.push(`    json as Map<Object?, Object?>;`);
    lines.push(`    return const ${c.name}();`);
  } else {
    lines.push(`    final Map<Object?, Object?> map = json as Map<Object?, Object?>;`);
    lines.push(`    return ${c.name}(`);
    for (const f of params) {
      const access = `map['${f.prop}']`;
      if (f.mode === 'required') lines.push(`      ${f.prop}: ${f.type.decode(access)},`);
      else if (f.mode === 'presence') lines.push(`      ${f.prop}: map.containsKey('${f.prop}') ? JsonPresence<${f.type.base.dart}>.value(${f.type.decode(access)}) : const JsonPresence<${f.type.base.dart}>.absent(),`);
      else lines.push(`      ${f.prop}: map.containsKey('${f.prop}') ? ${f.type.decode(access)} : null,`);
    }
    lines.push('    );');
  }
  lines.push('  }');
  lines.push('');
  for (const f of c.fields) {
    if (f.mode === 'const') {
      if (c.discriminators.has(f.prop)) lines.push('  @override');
      lines.push(`  ${f.dart} get ${f.prop} => ${typeof f.literal === 'string' ? dartString(f.literal) : JSON.stringify(f.literal)};`);
    } else if (f.mode === 'required') lines.push(`  final ${f.type.dart} ${f.prop};`);
    else if (f.mode === 'presence') lines.push(`  final JsonPresence<${f.type.base.dart}> ${f.prop};`);
    else lines.push(`  final ${f.type.dart.endsWith('?') ? f.type.dart : `${f.type.dart}?`} ${f.prop};`);
  }
  if (c.fields.length) lines.push('');
  if (c.implements.length) lines.push('  @override');
  lines.push('  Map<String, Object?> toJson() => <String, Object?>{');
  for (const f of c.fields) {
    if (f.mode === 'const' || f.mode === 'required') lines.push(`        '${f.prop}': ${f.mode === 'const' ? f.prop : f.type.encode(f.prop)},`);
    else if (f.mode === 'presence') {
      const value = nullableEncode(f.type.base, `${f.prop}.value`);
      lines.push(`        if (${f.prop}.isPresent) '${f.prop}': ${value},`);
    } else {
      const base = f.type.nullable && f.type.base ? f.type.base : f.type;
      if (base.encode('x') === 'x') lines.push(`        '${f.prop}': ?${f.prop},`);
      else lines.push(`        if (${f.prop} != null) '${f.prop}': ${base.encode(`${f.prop}!`)},`);
    }
  }
  lines.push('      };');
  lines.push('}');
  return lines.join('\n');
}

function emitUnion(c) {
  const lines = [];
  lines.push(`/// Wire union for \`#/components/schemas/${c.name}\` (oneOf, discriminated by \`${c.key}\`).`);
  lines.push(`sealed class ${c.name} {`);
  lines.push(`  /// Validates [json] against the \`${c.name}\` schema (exactly one variant), then decodes it.`);
  lines.push(`  /// Throws [ContractViolation] when the payload does not match the contract.`);
  lines.push(`  factory ${c.name}.fromJson(Object? json) {`);
  lines.push(`    ContractValidator.instance.check('${c.name}', json);`);
  lines.push(`    return ${c.name}._decode(json);`);
  lines.push('  }');
  lines.push('');
  lines.push(`  static ${c.name} _decode(Object? json) {`);
  lines.push(`    final Map<Object?, Object?> map = json as Map<Object?, Object?>;`);
  lines.push(`    return switch (map['${c.key}']) {`);
  for (const v of c.variants) lines.push(`      ${typeof v.value === 'string' ? dartString(v.value) : JSON.stringify(v.value)} => ${v.className}._decode(map),`);
  lines.push(`      _ => throw StateError('Unknown ${c.name}.${c.key} after validation'),`);
  lines.push('    };');
  lines.push('  }');
  lines.push('');
  lines.push(`  /// Discriminator value of this variant.`);
  lines.push(`  ${c.keyType} get ${c.key};`);
  lines.push('');
  lines.push('  Map<String, Object?> toJson();');
  lines.push('}');
  return lines.join('\n');
}

const topNames = Object.keys(schemas);
const models = [
  header('models'),
  '// ignore_for_file: prefer_const_constructors',
  '',
  "import '../contract_validator.dart';",
  '',
  ...[...classes.values()].map((c) => (c.kind === 'union' ? emitUnion(c) : emitObject(c)) + '\n'),
  '/// Decoders for every `#/components/schemas` entry, keyed by schema name.',
  'const Map<String, Object Function(Object?)> apiContractDecoders =',
  '    <String, Object Function(Object?)>{',
  ...topNames.map((n) => `  '${n}': ${n}.fromJson,`),
  '};',
  '',
].join('\n');

const schemaJson = '{\n' + topNames.map((n) => `${JSON.stringify(n)}:${JSON.stringify(schemas[n])}`).join(',\n') + '\n}';
if (schemaJson.includes("'''")) throw new Error('schema JSON contains a raw-string terminator');
const schemaFile = [
  header('schemas'),
  '',
  '/// SHA-256 of docs/api/openapi.yaml this output was generated from.',
  `const String apiContractSourceSha256 = '${sha}';`,
  '',
  '/// `components.schemas` from docs/api/openapi.yaml, verbatim, for runtime validation.',
  `const String apiSchemasJson = r'''${schemaJson}''';`,
  '',
].join('\n');

const outputs = { 'api_models.g.dart': models, 'api_schemas.g.dart': schemaFile };
if (process.argv.includes('--check')) {
  const stale = Object.entries(outputs).filter(([file, text]) => {
    const target = path.join(outDir, file);
    return !fs.existsSync(target) || normalizeLines(fs.readFileSync(target, 'utf8')) !== text;
  });
  if (stale.length) {
    console.error(`Dart contracts are stale: ${stale.map(([f]) => f).join(', ')}. Run node tools/blueprint/generate-dart-contracts.mjs`);
    process.exit(1);
  }
  console.log(JSON.stringify({ status: 'PASS', dartContracts: 'up to date', schemas: topNames.length, classes: classes.size, sourceSha256: sha }));
} else {
  fs.mkdirSync(outDir, { recursive: true });
  for (const [file, text] of Object.entries(outputs)) fs.writeFileSync(path.join(outDir, file), text);
  console.log(JSON.stringify({ status: 'GENERATED', schemas: topNames.length, classes: classes.size, outDir: path.relative(root, outDir) }));
}
