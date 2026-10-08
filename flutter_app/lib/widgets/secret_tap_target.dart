import 'package:flutter/material.dart';

/// مدخل مخفي: [onTriggered] بعد [taps] نقرات متتالية على [child]، كل نقرة خلال [gap] من
/// سابقتها. لا أثر ظاهر قبلها، فلا يعرفه إلا من أُخبر به.
class SecretTapTarget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTriggered;
  final int taps;
  final Duration gap;

  /// الساعة (الاختبارات تتحكم بها).
  final DateTime Function() clock;

  const SecretTapTarget({
    super.key,
    required this.child,
    required this.onTriggered,
    this.taps = 7,
    this.gap = const Duration(milliseconds: 1200),
    this.clock = DateTime.now,
  });

  @override
  State<SecretTapTarget> createState() => _SecretTapTargetState();
}

class _SecretTapTargetState extends State<SecretTapTarget> {
  int _count = 0;
  DateTime? _last;

  void _onTap() {
    final now = widget.clock();
    final last = _last;
    if (last == null || now.difference(last) > widget.gap || now.isBefore(last)) _count = 0;
    _count++;
    _last = now;
    if (_count >= widget.taps) {
      _count = 0;
      _last = null;
      widget.onTriggered();
    }
  }

  @override
  Widget build(BuildContext context) =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: _onTap, child: widget.child);
}
