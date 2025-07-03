import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:kakan/features/reels/domain/entities/reel_entity.dart';
import 'package:kakan/features/reels/domain/entities/share_target_entity.dart';
import 'package:kakan/features/reels/presentation/bloc/reel_lists/reels_bloc.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/injection_container.dart' as di;

class ReelItem extends StatefulWidget {
  final ReelEntity reel;
  final bool isPlaying;
  final bool isPreload;

  const ReelItem({
    super.key,
    required this.reel,
    required this.isPlaying,
    required this.isPreload,
  });

  @override
  _ReelItemState createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false, _pausedByUser = false;
  bool _likeLoading = false, _repostLoading = false;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPreload) _initMedia();
  }

  bool _isAudioFile(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.mp3') || lowerUrl.endsWith('.aac') || lowerUrl.endsWith('.wav') || lowerUrl.endsWith('.m4a');
  }

  Future<void> _initMedia() async {
    if (_isInitialized || _retryCount >= _maxRetries || _isDisposing) return;

    try {
      if (widget.reel.mediaType == 'video' && !_isAudioFile(widget.reel.mediaFile)) {
        print('DEBUG: Initializing VideoPlayerController for ${widget.reel.mediaFile}');
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.reel.mediaFile),
          httpHeaders: await _getAuthHeaders(),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
        if (_isDisposing) return;
        await _videoController!.initialize();
        if (_isDisposing) return;
        _videoController!.setLooping(true);
        print('DEBUG: VideoPlayerController initialized successfully');
      } else {
        print('DEBUG: Initializing AudioPlayer for ${widget.reel.mediaFile}');
        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setUrl(
          widget.reel.mediaFile,
          headers: await _getAuthHeaders(),
        );
        if (_isDisposing) return;
        print('DEBUG: AudioPlayer initialized successfully');
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
          _retryCount = 0;
        });
        if (widget.isPlaying) _play();
      }
    } catch (e, stackTrace) {
      print('ERROR: Failed to initialize media for ${widget.reel.mediaFile}: $e\nStack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load media. Tap to retry.';
          _retryCount++;
        });
        if (_retryCount < _maxRetries) {
          print('DEBUG: Retrying media initialization (attempt ${_retryCount + 1}/$_maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
          _initMedia();
        }
      }
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final sessionManager = di.sl<SessionManager>();
    final accessToken = await sessionManager.getAccessToken();
    return accessToken != null ? {'Authorization': 'Bearer $accessToken'} : {};
  }

  void _play() {
    if (!_isInitialized || _errorMessage != null || _isDisposing) return;
    if (_videoController != null && !_videoController!.value.isInitialized) return;
    if (_videoController != null) {
      _videoController!.play();
      print('DEBUG: Playing video for ${widget.reel.id}');
    } else if (_audioPlayer != null) {
      _audioPlayer!.play();
      print('DEBUG: Playing audio for ${widget.reel.id}');
    }
  }

  void _pause() {
    if (!_isInitialized || _errorMessage != null || _isDisposing) return;
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.pause();
      print('DEBUG: Pausing video for ${widget.reel.id}');
    } else if (_audioPlayer != null) {
      _audioPlayer!.pause();
      print('DEBUG: Pausing audio for ${widget.reel.id}');
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isPreload && !_isInitialized && !_isDisposing) _initMedia();
    if (_isInitialized && _errorMessage == null && !_isDisposing) {
      widget.isPlaying && !_pausedByUser ? _play() : _pause();
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    _videoController?.pause();
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.dispose();
    }
    _audioPlayer?.dispose();
    print('DEBUG: Disposed media controllers for ${widget.reel.id}');
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized || _errorMessage != null || _isDisposing) return;
    setState(() {
      if (_videoController != null && _videoController!.value.isInitialized && _videoController!.value.isPlaying) {
        _videoController!.pause();
        _pausedByUser = true;
        print('DEBUG: User paused video for ${widget.reel.id}');
      } else if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController!.play();
        _pausedByUser = false;
        print('DEBUG: User played video for ${widget.reel.id}');
      } else if (_audioPlayer != null && _audioPlayer!.playing) {
        _audioPlayer!.pause();
        _pausedByUser = true;
        print('DEBUG: User paused audio for ${widget.reel.id}');
      } else if (_audioPlayer != null) {
        _audioPlayer!.play();
        _pausedByUser = false;
        print('DEBUG: User played audio for ${widget.reel.id}');
      }
    });
  }

  void _showShareDialog(List<ShareTargetEntity> shareTargets) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share Reel'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: shareTargets.length,
            itemBuilder: (context, index) {
              final target = shareTargets[index];
              final displayName = target.type == 'group' ? target.groupName ?? 'Group' : target.data.username;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: target.data.profileImage != null
                      ? NetworkImage(target.data.profileImage!)
                      : const AssetImage('assets/images/avatar1.png') as ImageProvider,
                ),
                title: Text(displayName.isNotEmpty ? displayName : 'Unknown'),
                subtitle: Text(target.type == 'group' ? 'Group' : 'User'),
                onTap: target.chatId != null
                    ? () {
                        // Use the parent context to access ReelsBloc
                        this.context.read<ReelsBloc>().add(
                              ShareReelToChatEvent(
                                reelId: widget.reel.id,
                                chatId: target.chatId!,
                              ),
                            );
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reel shared with $displayName')),
                        );
                      }
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReelsBloc, ReelsState>(
      listener: (context, state) {
        if (state is ReelsLikeError && state.reels.any((r) => r.id == widget.reel.id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          setState(() => _likeLoading = _repostLoading = false);
        } else if (state is ReelsLoaded && state.reels.any((r) => r.id == widget.reel.id)) {
          setState(() => _likeLoading = _repostLoading = false);
        } else if (state is ReelsShareTargetsLoaded && state.reelId == widget.reel.id) {
          _showShareDialog(state.shareTargets);
        } else if (state is ReelsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: GestureDetector(
        onTap: _errorMessage != null
            ? () {
                setState(() {
                  _errorMessage = null;
                  _retryCount = 0;
                });
                _initMedia();
              }
            : _togglePlayPause,
        child: Stack(
          children: [
            Center(
              child: _errorMessage != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                              _retryCount = 0;
                            });
                            _initMedia();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : (_isInitialized && _videoController != null && _videoController!.value.isInitialized)
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : (_isInitialized && _audioPlayer != null)
                          ? Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(Icons.music_note, color: Colors.white, size: 50),
                              ),
                            )
                          : (widget.reel.thumbnail != null && widget.reel.thumbnail!.isNotEmpty)
                              ? Image.network(widget.reel.thumbnail!, fit: BoxFit.cover)
                              : const CircularProgressIndicator(color: Colors.white),
            ),
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Reels',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: widget.reel.userProfileDetails.profileImage.isNotEmpty
                            ? NetworkImage(widget.reel.userProfileDetails.profileImage)
                            : const AssetImage('assets/images/avatar1.png') as ImageProvider,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.reel.userProfileDetails.username,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.reel.caption.isNotEmpty ? widget.reel.caption : 'No caption',
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 40,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      widget.reel.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: widget.reel.isLiked ? Colors.red : Colors.white,
                    ),
                    onPressed: _likeLoading
                        ? null
                        : () {
                            setState(() => _likeLoading = true);
                            context.read<ReelsBloc>().add(
                                  LikeReelEvent(
                                    reelId: widget.reel.id,
                                    like: !widget.reel.isLiked,
                                  ),
                                );
                          },
                  ),
                  Text('${widget.reel.likesCount}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(Icons.repeat, color: Colors.white),
                    onPressed: _repostLoading
                        ? null
                        : () {
                            setState(() => _repostLoading = true);
                            context.read<ReelsBloc>().add(
                                  RepostReelEvent(
                                    reelId: widget.reel.id,
                                    mediaType: widget.reel.mediaType,
                                    title: widget.reel.title,
                                    caption: widget.reel.caption,
                                  ),
                                );
                          },
                  ),
                  Text('${widget.reel.repostCount}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      context.read<ReelsBloc>().add(
                            ShareReelEvent(reelId: widget.reel.id),
                          );
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<String?>(
                    future: di.sl<SessionManager>().getUserId(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data == widget.reel.userProfileDetails.id) {
                        return IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _likeLoading || _repostLoading
                              ? null
                              : () {
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Delete Reel'),
                                      content: const Text('Are you sure you want to delete this reel?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogContext),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            context.read<ReelsBloc>().add(
                                                  DeleteReelEvent(reelId: widget.reel.id),
                                                );
                                            Navigator.pop(dialogContext);
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}