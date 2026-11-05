import 'dart:convert';

import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/config/local_tls.dart';
import 'package:cocenglish/core/config/local_tls_stub.dart' as web_stub;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validPem =
      '-----BEGIN CERTIFICATE-----\nAQID\n-----END CERTIFICATE-----\n';
  final validDefine = base64Encode(utf8.encode(validPem));
  var installed = <List<int>>[];

  setUp(() => installed = <List<int>>[]);

  AppConfig config({
    DataSource dataSource = DataSource.api,
    String appwriteEndpoint = 'https://10.0.2.2:8443/v1',
    Map<ApiService, String> serviceUrls = const <ApiService, String>{
      ApiService.learning: 'https://10.0.2.2:4101',
      ApiService.progress: 'https://localhost:4102',
      ApiService.ai: 'https://local-tls:4103',
    },
  }) => AppConfig(
    dataSource: dataSource,
    appwriteEndpoint: appwriteEndpoint,
    appwriteProjectId: 'local-project',
    serviceUrls: serviceUrls,
    mockAuthOverride: false,
  );

  void install(List<int> bytes) => installed.add(List<int>.from(bytes));

  test(
    'empty define and mock data source do not change trusted certificates',
    () {
      configureLocalDevelopmentTls(
        config: config(),
        caBase64: '',
        isDebugMode: true,
        installCertificate: install,
      );
      configureLocalDevelopmentTls(
        config: config(dataSource: DataSource.mock),
        caBase64: validDefine,
        isDebugMode: true,
        installCertificate: install,
      );

      expect(installed, isEmpty);
    },
  );

  test('nonempty local CA is rejected outside debug builds', () {
    expect(
      () => configureLocalDevelopmentTls(
        config: config(),
        caBase64: validDefine,
        isDebugMode: false,
        installCertificate: install,
      ),
      throwsA(isA<StateError>()),
    );
    expect(installed, isEmpty);
  });

  test('external and insecure endpoints reject local CA configuration', () {
    for (final invalid in <AppConfig>[
      config(appwriteEndpoint: 'https://cloud.appwrite.io/v1'),
      config(
        serviceUrls: const <ApiService, String>{
          ApiService.learning: 'http://10.0.2.2:4101',
          ApiService.progress: 'https://localhost:4102',
          ApiService.ai: 'https://local-tls:4103',
        },
      ),
    ]) {
      expect(
        () => configureLocalDevelopmentTls(
          config: invalid,
          caBase64: validDefine,
          isDebugMode: true,
          installCertificate: install,
        ),
        throwsA(isA<StateError>()),
      );
    }
    expect(installed, isEmpty);
  });

  test(
    'malformed base64 and malformed PEM are rejected before installation',
    () {
      for (final malformed in <String>[
        'not-base64%',
        base64Encode(utf8.encode('not a certificate')),
        base64Encode(
          utf8.encode(
            '-----BEGIN CERTIFICATE-----\n%%%\n-----END CERTIFICATE-----\n',
          ),
        ),
      ]) {
        expect(
          () => configureLocalDevelopmentTls(
            config: config(),
            caBase64: malformed,
            isDebugMode: true,
            installCertificate: install,
          ),
          throwsA(isA<FormatException>()),
        );
      }
      expect(installed, isEmpty);
    },
  );

  test('valid local API profile installs decoded PEM bytes once', () {
    configureLocalDevelopmentTls(
      config: config(),
      caBase64: validDefine,
      isDebugMode: true,
      installCertificate: install,
    );

    expect(installed, hasLength(1));
    expect(utf8.decode(installed.single), validPem);
  });

  test('web stub refuses certificate installation explicitly', () {
    expect(
      () => web_stub.installTrustedCertificate(utf8.encode(validPem)),
      throwsUnsupportedError,
    );
  });
}
