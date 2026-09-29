import 'dart:async';
import 'dart:ui' show VoidCallback, Offset;
import 'package:flutter/gestures.dart';

/// A specialized TapGestureRecognizer subclass that cleanly disambiguates
/// between a normal tap (for audio playback & highlight) and a long-press (for verse Tafsir).
/// Because it extends TapGestureRecognizer, it fully conforms to Flutter's
/// RenderParagraph semantics requirements while providing rich long-press capability.
class AyahTapAndLongPressGestureRecognizer extends TapGestureRecognizer {
  VoidCallback? onLongPress;
  final Duration longPressDuration;

  Timer? _longPressTimer;
  bool _longPressFired = false;
  Offset? _downPosition;

  AyahTapAndLongPressGestureRecognizer({
    super.debugOwner,
    this.longPressDuration = const Duration(milliseconds: 400),
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _downPosition = event.position;
    _longPressFired = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(longPressDuration, () {
      _longPressFired = true;
      onLongPress?.call();
    });
  }

  // A finger that travels is scrolling, not pressing. Checked in handleEvent rather than
  // handleTapMove: once the move passes the slop the tap recognizer rejects itself
  // without ever calling handleTapMove.
  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent &&
        _downPosition != null &&
        (event.position - _downPosition!).distance > kTouchSlop) {
      _longPressTimer?.cancel();
    }
    super.handleEvent(event);
  }

  // The page's scroll (or the mushaf's page swipe) won this touch. A quick scroll wins
  // before the tap-down deadline, and then handleTapCancel is never called, so the
  // timer must stop here or the Tafsir opens by itself mid-scroll.
  @override
  void rejectGesture(int pointer) {
    _longPressTimer?.cancel();
    _longPressFired = false;
    super.rejectGesture(pointer);
  }

  @override
  void handleTapUp({required PointerDownEvent down, required PointerUpEvent up}) {
    _longPressTimer?.cancel();
    if (!_longPressFired) {
      super.handleTapUp(down: down, up: up);
    }
    _longPressFired = false;
  }

  @override
  void handleTapCancel({
    required PointerDownEvent down,
    PointerCancelEvent? cancel,
    required String reason,
  }) {
    _longPressTimer?.cancel();
    _longPressFired = false;
    super.handleTapCancel(down: down, cancel: cancel, reason: reason);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
}
