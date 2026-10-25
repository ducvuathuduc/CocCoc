import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/config/app_config.dart';

/// Complete public configuration; requests still use overridden fake transport.
const realTestConfig = AppConfig(
  dataSource: DataSource.api,
  serviceUrls: {
    ApiService.learning: 'https://learning.test',
    ApiService.progress: 'https://progress.test',
    ApiService.ai: 'https://ai.test',
  },
);
