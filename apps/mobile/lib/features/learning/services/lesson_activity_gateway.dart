import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/lesson_activity.dart';

abstract interface class LessonActivityGateway {
  Future<bool> sync(LessonActivitySnapshot snapshot);
  Future<bool> end();
}

class NoopLessonActivityGateway implements LessonActivityGateway {
  @override
  Future<bool> sync(LessonActivitySnapshot snapshot) async => false;

  @override
  Future<bool> end() async => false;
}

class MethodChannelLessonActivityGateway implements LessonActivityGateway {
  MethodChannelLessonActivityGateway({
    this._channel = const MethodChannel('cocenglish/lesson_activity'),
    bool? supported,
  }) : _supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  final MethodChannel _channel;
  final bool _supported;

  @override
  Future<bool> sync(LessonActivitySnapshot snapshot) =>
      _invoke('sync', snapshot.toChannelArguments());

  @override
  Future<bool> end() => _invoke('end');

  Future<bool> _invoke(String method, [Map<String, Object>? arguments]) async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
