import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/api/client/access_token.dart';

void main() {
  test(
    'invalidating during a mint discards its late token and permits fresh mint',
    () async {
      final first = Completer<String?>();
      var calls = 0;
      final tokens = CachingTokenProvider(
        () => ++calls == 1 ? first.future : Future.value('new-account-token'),
      );
      final old = tokens.token();
      tokens.invalidate();
      final currentRequest = tokens.token();
      expect(identical(currentRequest, old), false);
      final current = await currentRequest;
      expect(current, 'new-account-token');
      first.complete('old-account-token');
      expect(await old, isNull);
      expect(await tokens.token(), 'new-account-token');
    },
  );
}
