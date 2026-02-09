// Reusable video player controls: play/pause, timeline (seek bar), time labels, mute, fullscreen, rotate.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SearchVideoPlayerControls extends StatefulWidget {
  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onMute;
  final VoidCallback? onFullscreen;
  final VoidCallback? onRotate;
  final bool showFullscreen;
  final bool showRotate;
  final bool compact;

  const SearchVideoPlayerControls({
    super.key,
    required this.controller,
    required this.muted,
    required this.onMute,
    this.onFullscreen,
    this.onRotate,
    this.showFullscreen = true,
    this.showRotate = true,
    this.compact = false,
  });

  @override
  State<SearchVideoPlayerControls> createState() => _SearchVideoPlayerControlsState();
}

class _SearchVideoPlayerControlsState extends State<SearchVideoPlayerControls> {
  /// Defer setState to avoid "setState() called during build" when controller notifies during build.
  void _listener() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(covariant SearchVideoPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_listener);
      widget.controller.addListener(_listener);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final position = c.value.position;
    final duration = c.value.duration;
    final totalMs = duration.inMilliseconds.toDouble();
    final posMs = totalMs > 0 ? position.inMilliseconds.toDouble().clamp(0.0, totalMs) : 0.0;
    final isPlaying = c.value.isPlaying;
    final padding = widget.compact ? 8.0 : 14.0;
    final iconSize = widget.compact ? 20.0 : 26.0;
    final barHeight = widget.compact ? 44.0 : 52.0;

    return Container(
      height: barHeight,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.82),
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Play / Pause
            Material(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () {
                  if (isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: iconSize + 6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Current time (fixed width so "00:00" stays on one line)
            SizedBox(
              width: 44,
              child: Text(
                _formatDuration(position),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Seek bar
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: widget.compact ? 3 : 4,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: widget.compact ? 6 : 8),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: widget.compact ? 14 : 18),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.35),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: posMs,
                  max: totalMs > 0 ? totalMs : 1,
                  onChanged: (v) => c.seekTo(Duration(milliseconds: v.round())),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Duration (fixed width so "00:00" stays on one line)
            SizedBox(
              width: 44,
              child: Text(
                _formatDuration(duration),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: widget.compact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Mute
            _ControlButton(
              icon: widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: iconSize,
              onPressed: widget.onMute,
            ),
            if (widget.showRotate && widget.onRotate != null) ...[
              const SizedBox(width: 2),
              _ControlButton(icon: Icons.rotate_right_rounded, size: iconSize, onPressed: widget.onRotate!),
            ],
            if (widget.showFullscreen && widget.onFullscreen != null) ...[
              const SizedBox(width: 2),
              _ControlButton(icon: Icons.fullscreen_rounded, size: iconSize, onPressed: widget.onFullscreen!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _ControlButton({required this.icon, required this.size, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
