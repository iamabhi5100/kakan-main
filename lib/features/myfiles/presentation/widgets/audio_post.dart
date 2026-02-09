import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';

/// Standalone audio post widget for My Files. Plays a single audio with
/// play/pause, mute, seek bar, and title. No feed blocs, like, comment, or share.
class AudioPost extends StatefulWidget {
  final DownloadEntity download;

  const AudioPost({super.key, required this.download});

  @override
  State<AudioPost> createState() => _AudioPostState();
}

class _AudioPostState extends State<AudioPost> {
  AudioPlayer? _audioPlayer;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _error;
  bool _isMuted = false;

  static String _normalizeMediaUrl(String url) {
    if (url.isEmpty) return url;
    final t = url.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (t.startsWith('/') && !t.startsWith('//')) return '${ConstantApi.baseUrl}$t';
    return t;
  }

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    if (widget.download.mediaFile == null || widget.download.mediaFile!.isEmpty) {
      if (mounted) setState(() => _error = 'No audio file available');
      return;
    }
    _audioPlayer = AudioPlayer();
    try {
      final url = _normalizeMediaUrl(widget.download.mediaFile!);
      await _audioPlayer!.setUrl(url);
      if (mounted) {
        setState(() => _error = null);
        _audioPlayer!.durationStream.listen((d) {
          if (mounted) setState(() => _duration = d ?? Duration.zero);
        });
        _audioPlayer!.positionStream.listen((p) {
          if (mounted) setState(() => _position = p);
        });
      }
    } catch (e) {
      if (kDebugMode) print('AudioPost: Error initializing audio: $e');
      if (mounted) setState(() => _error = 'Failed to load audio');
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_error != null || _audioPlayer == null) return;
    if (_audioPlayer!.playing) {
      _audioPlayer!.pause();
    } else {
      _audioPlayer!.play();
    }
    setState(() {});
  }

  Future<void> _toggleMute() async {
    if (_audioPlayer == null) return;
    _isMuted = !_isMuted;
    await _audioPlayer!.setVolume(_isMuted ? 0 : 1);
    if (mounted) setState(() {});
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            _buildErrorCard()
          else
            Column(
              children: [
                _buildCoverCard(),
                const Gap(24),
                _buildPlayerCard(),
              ],
            ),
          const Gap(20),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[400]),
          const Gap(12),
          Text(
            _error!,
            style: appTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: appTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1,
          child: widget.download.thumbnail != null &&
                  widget.download.thumbnail!.isNotEmpty
              ? Image.network(
                  widget.download.thumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                )
              : _buildPlaceholderCover(),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: appTheme.primaryColor.withValues(alpha: 0.15),
      child: Icon(
        Icons.music_note_rounded,
        size: 80,
        color: appTheme.primaryColor.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildPlayerCard() {
    final isPlaying = _audioPlayer?.playing ?? false;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play / Pause
              Material(
                color: appTheme.primaryColor,
                borderRadius: BorderRadius.circular(28),
                elevation: 2,
                child: InkWell(
                  onTap: _togglePlayPause,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const Gap(20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: appTheme.primaryColor,
                        inactiveTrackColor: Colors.grey[300],
                        thumbColor: appTheme.primaryColor,
                        overlayColor: appTheme.primaryColor.withValues(alpha: 0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (v) {
                          final ms = (v * _duration.inMilliseconds).round();
                          _audioPlayer?.seek(Duration(milliseconds: ms));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: appTheme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: appTheme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.grey[700],
                  size: 26,
                ),
                onPressed: _toggleMute,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: appTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Audio',
                  style: appTheme.textTheme.bodySmall?.copyWith(
                    color: appTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Gap(12),
              if (widget.download.duration != null &&
                  widget.download.duration!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const Gap(4),
                    Text(
                      widget.download.duration!,
                      style: appTheme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Gap(12),
          Text(
            widget.download.title ?? 'Untitled Audio',
            style: appTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
