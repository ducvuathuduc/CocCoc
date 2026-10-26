import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/client/api_operation.dart';
import 'app_config.dart';
import 'local_tls_stub.dart'
    if (dart.library.io) 'local_tls_io.dart'
    as platform_tls;

typedef TrustedCertificateInstaller = void Function(List<int> pemBytes);

const _localHosts = <String>{'localhost', '127.0.0.1', '10.0.2.2', 'local-tls'};

/// Adds one generated local CA to the process trust store for debug API builds.
///
/// This never disables certificate validation. Release and profile builds reject
/// a nonempty [caBase64] instead of silently accepting a development trust root.
void configureLocalDevelopmentTls({
  AppConfig? config,
  String caBase64 = const String.fromEnvironment('LOCAL_DEV_CA_BASE64'),
  bool isDebugMode = kDebugMode,
  TrustedCertificateInstaller? installCertificate,
}) {
  if (caBase64.isEmpty) return;
  if (!isDebugMode) {
    throw StateError('LOCAL_DEV_CA_BASE64 is allowed only in debug builds.');
  }

  final resolvedConfig = config ?? AppConfig.current;
  if (!resolvedConfig.isApi) return;
  _validateLocalHttpsEndpoints(resolvedConfig);
  final pemBytes = _decodeCertificatePem(caBase64);
  (installCertificate ?? platform_tls.installTrustedCertificate)(pemBytes);
}

void _validateLocalHttpsEndpoints(AppConfig config) {
  final endpoints = <String>[config.appwriteEndpoint];
  for (final service in ApiService.values) {
    final endpoint = config.serviceUrls[service];
    if (endpoint == null || endpoint.isEmpty) {
      throw StateError('Local TLS requires every API endpoint.');
    }
    endpoints.add(endpoint);
  }

  for (final endpoint in endpoints) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        endpoint != endpoint.trim() ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !_localHosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('Local TLS requires strict HTTPS local endpoints.');
    }
  }
}

List<int> _decodeCertificatePem(String encoded) {
  late final List<int> pemBytes;
  late final String pem;
  try {
    pemBytes = base64Decode(encoded);
    pem = utf8.decode(pemBytes);
  } on FormatException {
    throw const FormatException(
      'LOCAL_DEV_CA_BASE64 must contain a PEM certificate.',
    );
  }

  final lines = pem.replaceAll('\r\n', '\n').trim().split('\n');
  if (lines.length < 3 ||
      lines.first != '-----BEGIN CERTIFICATE-----' ||
      lines.last != '-----END CERTIFICATE-----') {
    throw const FormatException(
      'LOCAL_DEV_CA_BASE64 must contain a PEM certificate.',
    );
  }
  final bodyLines = lines.sublist(1, lines.length - 1);
  final base64Line = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
  if (bodyLines.any(
    (line) => line.isEmpty || line.length > 64 || !base64Line.hasMatch(line),
  )) {
    throw const FormatException(
      'LOCAL_DEV_CA_BASE64 must contain a PEM certificate.',
    );
  }
  try {
    if (base64Decode(bodyLines.join()).isEmpty) {
      throw const FormatException('Empty certificate.');
    }
  } on FormatException {
    throw const FormatException(
      'LOCAL_DEV_CA_BASE64 must contain a PEM certificate.',
    );
  }
  return pemBytes;
}
