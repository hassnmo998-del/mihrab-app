import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/help_videos_data.dart';

/// مشغّل فيديو تعليمي من ملف مضمَّن في التطبيق: صورة غلاف وزر تشغيل، وبلمسة يبدأ فوراً.
///
/// فيديو واحد يعمل في كل مرة: بدء مشغّل يوقف غيره ويحرّر موارده (مشغّل لكل بطاقة كان سيثقل
/// الجهاز). الملفات مضمَّنة لا تُنزَّل، فلا انتظار ولا إنترنت.
class HelpVideoPlayer extends StatefulWidget {
  final HelpVideo video;

  /// يبدأ التشغيل فور ظهوره (من زر فيديو الرتبة في البوابة).
  final bool autoplay;

  const HelpVideoPlayer({super.key, required this.video, this.autoplay = false});

  @override
  State<HelpVideoPlayer> createState() => _HelpVideoPlayerState();
}

/// من يعمل الآن: أي مشغّل آخر يسمع هذا فيتوقف.
final ValueNotifier<Object?> _activePlayer = ValueNotifier<Object?>(null);

class _HelpVideoPlayerState extends State<HelpVideoPlayer> with WidgetsBindingObserver {
  final Object _token = Object();
  VideoPlayerController? _controller;
  bool _starting = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activePlayer.addListener(_onActiveChanged);
    if (widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activePlayer.removeListener(_onActiveChanged);
    if (_activePlayer.value == _token) _activePlayer.value = null;
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  void _onActiveChanged() {
    if (_activePlayer.value != _token && _controller != null) {
      _release();
    }
  }

  void _release() {
    final c = _controller;
    _controller = null;
    c?.removeListener(_onTick);
    c?.dispose();
    if (mounted) setState(() {});
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (_starting || _controller != null) return;
    setState(() {
      _starting = true;
      _failed = false;
    });
    _activePlayer.value = _token;
    final c = VideoPlayerController.asset(widget.video.asset);
    try {
      await c.initialize();
      if (!mounted || _activePlayer.value != _token) {
        await c.dispose();
        return;
      }
      c.addListener(_onTick);
      await c.setLooping(false);
      _controller = c;
      await c.play();
    } catch (_) {
      if (mounted) _failed = true;
      try {
        await c.dispose();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isCompleted) {
      await c.seekTo(Duration.zero);
      await c.play();
    } else if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }

  Future<void> _fullscreen() async {
    final c = _controller;
    if (c == null) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => _FullscreenVideo(controller: c, video: widget.video)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ratio = (c != null && c.value.isInitialized) ? c.value.aspectRatio : widget.video.aspectRatio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: ratio,
          child: c != null && c.value.isInitialized ? _playing(c) : _poster(),
        ),
      ),
    );
  }

  Widget _poster() {
    return GestureDetector(
      key: const ValueKey('helpVideoPoster'),
      behavior: HitTestBehavior.opaque,
      onTap: _start,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            widget.video.poster,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A1810)),
          ),
          const ColoredBox(color: Color(0x33000000)),
          Center(
            child: _starting
                ? const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Container(
                    width: 74,
                    height: 74,
                    decoration: const BoxDecoration(color: Color(0xE6FFFFFF), shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow_rounded, size: 52, color: AppColors.terracottaPrimary),
                  ),
          ),
          if (_failed)
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'تعذّر تشغيل الفيديو على هذا الجهاز. جرّب مرة أخرى.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _playing(VideoPlayerController c) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: const ValueKey('helpVideoSurface'),
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: VideoPlayer(c),
        ),
        if (!c.value.isPlaying)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(color: Color(0xCCFFFFFF), shape: BoxShape.circle),
                child: Icon(c.value.isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 52, color: AppColors.terracottaPrimary),
              ),
            ),
          ),
        Positioned(left: 0, right: 0, bottom: 0, child: _ControlsBar(controller: c, onFullscreen: _fullscreen)),
      ],
    );
  }
}

/// شريط التقدّم (يُسحب للتقديم والتأخير)، الزمن، وزر ملء الشاشة.
class _ControlsBar extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;
  final bool inFullscreen;

  const _ControlsBar({required this.controller, this.onFullscreen, this.inFullscreen = false});

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final v = controller.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Color(0x00000000)]),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Text(_fmt(v.position), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 10),
                colors: VideoProgressColors(
                  playedColor: AppColors.terracottaPrimary,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(_fmt(v.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('helpVideoFullscreen'),
              tooltip: inFullscreen ? 'إغلاق ملء الشاشة' : 'ملء الشاشة',
              visualDensity: VisualDensity.compact,
              icon: Icon(inFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white),
              onPressed: inFullscreen ? () => Navigator.of(context).maybePop() : onFullscreen,
            ),
          ],
        ),
      ),
    );
  }
}

/// ملء الشاشة بالمشغّل نفسه (لا نسخة ثانية): يكمل من حيث كان.
class _FullscreenVideo extends StatefulWidget {
  final VideoPlayerController controller;
  final HelpVideo video;

  const _FullscreenVideo({required this.controller, required this.video});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
    if (_mobile) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    if (_mobile) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    final c = widget.controller;
    if (c.value.isCompleted) {
      await c.seekTo(Duration.zero);
      await c.play();
    } else if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
            ),
            if (!c.value.isPlaying)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(color: Color(0xCCFFFFFF), shape: BoxShape.circle),
                    child: Icon(c.value.isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 60, color: AppColors.terracottaPrimary),
                  ),
                ),
              ),
            Positioned(left: 0, right: 0, bottom: 0, child: _ControlsBar(controller: c, inFullscreen: true)),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                tooltip: 'إغلاق',
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
