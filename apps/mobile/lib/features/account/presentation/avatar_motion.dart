import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

/// One decoded source file; each mounted avatar owns its artboard/controller.
/// Scrolled-off choices release their controllers and the last user releases
/// the file, so the full catalogue does not become a permanent runtime cache.
final class _AvatarFilePool {
  static Future<rive.File?>? _loading;
  static rive.File? _file;
  static int _users = 0;
  static Future<rive.File?> acquire() {
    _users++;
    return _loading ??=
        rive.File.asset(
          'assets/avatar/avatar_builder_25_sept2025.riv',
          riveFactory: rive.Factory.flutter,
        ).then(
          (file) {
            _file = file;
            if (file == null) _loading = null;
            return file;
          },
          onError: (Object error, StackTrace stack) {
            _loading = null;
            Error.throwWithStackTrace(error, stack);
          },
        );
  }

  static void release() {
    if (--_users != 0) return;
    _file?.dispose();
    _file = null;
    _loading = null;
  }
}

class AvatarMotion extends StatefulWidget {
  const AvatarMotion({
    required this.values,
    this.width,
    this.height,
    this.tile = false,
    this.animate = true,
    super.key,
  });
  final Map<String, double> values;
  final double? width, height;
  final bool tile, animate;
  @override
  State<AvatarMotion> createState() => _AvatarMotionState();
}

class _AvatarMotionState extends State<AvatarMotion>
    with WidgetsBindingObserver {
  rive.RiveWidgetController? _controller;
  final _numbers = <String, rive.NumberInput>{};
  rive.TriggerInput? _bounce;
  bool _foreground = true, _failed = false, _acquired = false;
  bool? _lastMoving;
  bool get _moving =>
      !widget.tile &&
      widget.animate &&
      _foreground &&
      const bool.fromEnvironment('ENABLE_MASCOT_MOTION', defaultValue: true) &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    _acquired = true;
    try {
      final file = await _AvatarFilePool.acquire();
      if (!mounted) {
        _releaseFile();
        return;
      }
      if (file == null) throw StateError('Avatar file unavailable');
      _controller = rive.RiveWidgetController(
        file,
        artboardSelector: rive.ArtboardSelector.byName('MainAvatar'),
        stateMachineSelector: rive.StateMachineSelector.byName('SMAvatar'),
      );
      // Original legacy-input export, not a data-binding view model.
      // ignore: deprecated_member_use
      final inputs = _controller!.stateMachine.inputs;
      for (final input in inputs) {
        if (input is rive.NumberInput) {
          _numbers[input.name] = input;
        } else if (input is rive.TriggerInput && input.name == 'bounce_trig') {
          _bounce = input;
        } else {
          input.dispose();
        }
      }
      _apply(initial: true);
      setState(() {});
    } on Object {
      _disposeController();
      _releaseFile();
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  void _releaseFile() {
    if (!_acquired) return;
    _acquired = false;
    _AvatarFilePool.release();
  }

  void _disposeController() {
    for (final input in _numbers.values) {
      input.dispose();
    }
    _numbers.clear();
    _bounce?.dispose();
    _bounce = null;
    _controller?.dispose();
    _controller = null;
  }

  void _apply({bool initial = false}) {
    final controller = _controller;
    if (controller == null) return;
    for (final entry in widget.values.entries) {
      _numbers[entry.key]?.value = entry.value;
    }
    _numbers['ENG_ONLY_Zoom']?.value = widget.tile
        ? (widget.values['ENG_ONLY_Zoom'] ?? 0)
        : 1;
    _numbers['ENG_ONLY_Animation']?.value = widget.tile || !_moving
        ? 0
        : (widget.values['ENG_ONLY_Animation'] ?? 1);
    // The verified trigger commits number changes as well as the bounce.
    _bounce?.fire();
    if (initial || !_moving) controller.advance(1);
    controller.active = _moving;
    _lastMoving = _moving;
    controller.scheduleRepaint();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null && _lastMoving != _moving) _apply();
  }

  @override
  void didUpdateWidget(AvatarMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.values, widget.values) ||
        oldWidget.tile != widget.tile ||
        _lastMoving != _moving) {
      _apply();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_controller != null && _lastMoving != _moving) _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Loading completion owns release if this widget was disposed in flight.
    if (_controller != null) {
      _disposeController();
      _releaseFile();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.width,
      height: widget.height,
      child: _controller == null
          ? (_failed
                ? const Icon(Icons.person_outline, color: Color(0xFF84D7FF))
                : const SizedBox.shrink())
          : IgnorePointer(
              child: rive.RiveWidget(
                controller: _controller!,
                fit: rive.Fit.cover,
              ),
            ),
    ),
  );
}
