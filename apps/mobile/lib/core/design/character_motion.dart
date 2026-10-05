import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

enum LessonCharacter {
  bea,
  eddy,
  falstaff,
  junior,
  lily,
  lin,
  lucy,
  oscar,
  vikram,
  zari,
}

extension LessonCharacterAsset on LessonCharacter {
  String get asset => 'assets/motion/character-$name.riv';
}

enum CharacterReaction { reset, correct, incorrect }

extension CharacterReactionInput on CharacterReaction {
  String get input => switch (this) {
    CharacterReaction.reset => 'reset_trig',
    CharacterReaction.correct => 'correct_trig',
    CharacterReaction.incorrect => 'incorrect_trig',
  };
}

class CharacterMotion extends StatefulWidget {
  const CharacterMotion({
    required this.character,
    required this.width,
    required this.height,
    required this.fallback,
    this.reaction = CharacterReaction.reset,
    this.epoch = '',
    this.enabled = const bool.fromEnvironment(
      'ENABLE_MASCOT_MOTION',
      defaultValue: true,
    ),
    super.key,
  });
  final LessonCharacter character;
  final CharacterReaction reaction;
  final String epoch;
  final double width, height;
  final Widget fallback;
  final bool enabled;
  @override
  State<CharacterMotion> createState() => _CharacterMotionState();
}

class _CharacterMotionState extends State<CharacterMotion>
    with WidgetsBindingObserver {
  rive.File? _file;
  rive.RiveWidgetController? _controller;
  final _triggers = <CharacterReaction, rive.TriggerInput>{};
  rive.BooleanInput? _dark, _rtl;
  bool _loading = false, _failed = false, _foreground = true;
  int _revision = 0;
  bool get _allowed =>
      widget.enabled &&
      _foreground &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CharacterMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) {
      _revision++;
      _release();
      _failed = false;
      _loading = false;
    }
    if (oldWidget.reaction != widget.reaction ||
        oldWidget.epoch != widget.epoch) {
      _react();
    }
    _sync();
  }

  void _sync() {
    _controller?.active = _allowed;
    if (_allowed && _controller == null && !_loading && !_failed) {
      unawaited(_load());
    }
  }

  void _react() => _triggers[widget.reaction]?.fire();
  Future<void> _load() async {
    _loading = true;
    final revision = ++_revision;
    rive.File? loaded;
    try {
      loaded = await rive.File.asset(
        widget.character.asset,
        riveFactory: rive.Factory.flutter,
      );
      if (!mounted || revision != _revision) {
        loaded?.dispose();
        return;
      }
      if (loaded == null) throw StateError('Character file unavailable');
      _file = loaded;
      _controller = rive.RiveWidgetController(
        loaded,
        artboardSelector: rive.ArtboardSelector.byName('character'),
        stateMachineSelector: rive.StateMachineSelector.byName(
          'character_statemachine',
        ),
      );
      for (final reaction in CharacterReaction.values) {
        // Original Duolingo exports use named legacy inputs, not a view model.
        // ignore: deprecated_member_use
        final trigger = _controller!.stateMachine.trigger(reaction.input);
        if (trigger == null) {
          throw StateError('Missing character input ${reaction.input}');
        }
        _triggers[reaction] = trigger;
      }
      // Preserve the original file's verified input contract.
      // ignore: deprecated_member_use
      _dark = _controller!.stateMachine.boolean('darkmode_bool')
        ?..value = false;
      // ignore: deprecated_member_use
      _rtl = _controller!.stateMachine.boolean('rtl_bool')?..value = false;
      _react();
      _controller!.active = _allowed;
      setState(() => _loading = false);
    } on Object {
      if (!mounted || revision != _revision) return;
      _release();
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) {
      _sync();
      setState(() {});
    }
  }

  void _release() {
    for (final input in _triggers.values) {
      input.dispose();
    }
    _triggers.clear();
    _dark?.dispose();
    _dark = null;
    _rtl?.dispose();
    _rtl = null;
    _controller?.dispose();
    _controller = null;
    _file?.dispose();
    _file = null;
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.width,
      height: widget.height,
      child: !_allowed || _controller == null
          ? widget.fallback
          : rive.RiveWidget(controller: _controller!, fit: rive.Fit.contain),
    ),
  );
}
