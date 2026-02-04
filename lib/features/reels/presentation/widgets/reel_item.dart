import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:kakan/features/reels/domain/entities/reel_entity.dart';
import 'package:kakan/features/reels/domain/entities/share_target_entity.dart';
import 'package:kakan/features/reels/presentation/bloc/reel_lists/reels_bloc.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:kakan/features/reels/presentation/widgets/reel_comments_screen.dart';
import 'package:kakan/config/theme.dart';

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
  bool _useSoftwareDecoding = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPreload) _initMedia();
  }

  bool _isAudioFile(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.mp3') ||
        lowerUrl.endsWith('.aac') ||
        lowerUrl.endsWith('.wav') ||
        lowerUrl.endsWith('.m4a');
  }

  Future<void> _initMedia() async {
    if (_isInitialized ||
        _retryCount >= _maxRetries ||
        _isDisposing ||
        widget.reel.mediaFile.isEmpty) {
      if (widget.reel.mediaFile.isEmpty) {
        setState(() {
          _errorMessage = 'Invalid media URL';
        });
      }
      return;
    }

    try {
      if (widget.reel.mediaType == 'video' &&
          !_isAudioFile(widget.reel.mediaFile)) {
        print(
          'DEBUG: Initializing VideoPlayerController for ${widget.reel.mediaFile} (software decoding: $_useSoftwareDecoding)',
        );
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.reel.mediaFile),
          httpHeaders: await _getAuthHeaders(),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
            webOptions:
                _useSoftwareDecoding ? const VideoPlayerWebOptions() : null,
          ),
        );
        if (_isDisposing) return;
        await _videoController!.initialize();
        if (_isDisposing) return;
        _videoController!.setLooping(true);
        print(
          'DEBUG: VideoPlayerController initialized successfully for ${widget.reel.id}',
        );
      } else {
        print('DEBUG: Initializing AudioPlayer for ${widget.reel.mediaFile}');
        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setUrl(
          widget.reel.mediaFile,
          headers: await _getAuthHeaders(),
        );
        if (_isDisposing) return;
        print(
          'DEBUG: AudioPlayer initialized successfully for ${widget.reel.id}',
        );
      }
      if (mounted && !_isDisposing) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
          _retryCount = 0;
          _useSoftwareDecoding = false;
        });
        if (widget.isPlaying) _play();
      }
    } catch (e, stackTrace) {
      print(
        'ERROR: Failed to initialize media for ${widget.reel.mediaFile}: $e\nStack trace: $stackTrace',
      );
      if (mounted && !_isDisposing) {
        setState(() {
          _errorMessage =
              _retryCount == 0
                  ? 'Failed to load media (hardware decoding error). Tap to retry with software decoding.'
                  : 'Failed to load media. Tap to retry.';
          _retryCount++;
          _useSoftwareDecoding = _retryCount > 1;
        });
        if (_retryCount < _maxRetries) {
          print(
            'DEBUG: Retrying media initialization (attempt ${_retryCount + 1}/$_maxRetries, software decoding: $_useSoftwareDecoding)',
          );
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
    if (_videoController != null && _videoController!.value.isInitialized) {
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
      _videoController = null;
    }
    _audioPlayer?.dispose();
    print('DEBUG: Disposed media controllers for ${widget.reel.id}');
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized || _errorMessage != null || _isDisposing) return;
    setState(() {
      if (_videoController != null &&
          _videoController!.value.isInitialized &&
          _videoController!.value.isPlaying) {
        _videoController!.pause();
        _pausedByUser = true;
        print('DEBUG: User paused video for ${widget.reel.id}');
      } else if (_videoController != null &&
          _videoController!.value.isInitialized) {
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

  void _showShareDialog(
    ReelsBloc reelsBloc,
    List<ShareTargetEntity> shareTargets,
  ) {
    final TextEditingController searchController = TextEditingController();
    final Set<String> selectedChatIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext dialogContext) {
        return Builder(
          builder: (BuildContext innerContext) {
            return StatefulBuilder(
              builder: (context, setState) {
                final query = searchController.text.toLowerCase();
                final filteredTargets =
                    shareTargets.where((target) {
                      final displayName =
                          target.type == 'group'
                              ? (target.groupName ?? 'Group').toLowerCase()
                              : target.data.username.toLowerCase();
                      return displayName.contains(query);
                    }).toList();

                return Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search users or groups...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                      const Gap(16),
                      const Text(
                        'Share to',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: filteredTargets.length,
                          itemBuilder: (context, index) {
                            final target = filteredTargets[index];
                            final displayName =
                                target.type == 'group'
                                    ? target.groupName ?? 'Group'
                                    : target.data.username;
                            final isSelected = selectedChatIds.contains(
                              target.chatId,
                            );
                            return GestureDetector(
                              onTap:
                                  target.chatId != null
                                      ? () {
                                          setState(() {
                                            if (isSelected) {
                                              selectedChatIds.remove(
                                                target.chatId,
                                              );
                                            } else {
                                              selectedChatIds.add(target.chatId!);
                                            }
                                          });
                                        }
                                      : null,
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: isSelected
                                              ? Border.all(
                                                  color: appTheme.primaryColor,
                                                  width: 2,
                                                )
                                              : null,
                                          image: DecorationImage(
                                            image: target.data.profileImage != null
                                                ? NetworkImage(
                                                    target.data.profileImage!,
                                                  )
                                                : const AssetImage(
                                                    'assets/images/avatar1.png',
                                                  ) as ImageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                          color: const Color.fromARGB(
                                            179,
                                            231,
                                            231,
                                            231,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.black.withOpacity(0.4),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.blue,
                                            size: 30,
                                          ),
                                        ),
                                      if (target.data.username == 'SJ')
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const CircleAvatar(
                                              radius: 10,
                                              backgroundColor: Colors.purple,
                                              child: Icon(
                                                Icons.sunny,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Gap(4),
                                  Text(
                                    displayName.isNotEmpty
                                        ? displayName
                                        : 'Unknown',
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Gap(16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () => _shareExternally(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(10),
                                ),
                                child: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Share to',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () => _copyLink(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(10),
                                ),
                                child: const Icon(
                                  Icons.link,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Copy Link',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Gap(16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              selectedChatIds.isNotEmpty
                                  ? () {
                                      for (final chatId in selectedChatIds) {
                                        reelsBloc.add(
                                          ShareReelToChatEvent(
                                            reelId: widget.reel.id,
                                            chatId: chatId,
                                          ),
                                        );
                                      }
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(
                                        innerContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Reel shared with ${selectedChatIds.length} recipient(s)',
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selectedChatIds.isNotEmpty
                                    ? Colors.blue
                                    : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Send',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      const Gap(16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      searchController.dispose();
    });
  }

  Future<void> _shareExternally() async {
    final String message =
        'Check out this reel: ${widget.reel.mediaFile}\nTitle: ${widget.reel.title}\nCaption: ${widget.reel.caption}';
    try {
      await Share.share(
        message,
        subject: 'Shared Reel',
        sharePositionOrigin: Rect.fromLTWH(
          0,
          0,
          MediaQuery.of(context).size.width,
          MediaQuery.of(context).size.height / 2,
        ),
      );
      print('DEBUG: Shared reel externally');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      print('ERROR: Failed to share externally: $e');
    }
  }

  Future<void> _copyLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.reel.mediaFile));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
      print('DEBUG: Copied link to clipboard');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to copy link: $e')));
      print('ERROR: Failed to copy link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reelsBloc = context.read<ReelsBloc>();
    return BlocListener<ReelsBloc, ReelsState>(
      listener: (context, state) {
        if (state is ReelsLikeError &&
            state.reels.any((r) => r.id == widget.reel.id)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          setState(() => _likeLoading = _repostLoading = false);
        } else if (state is ReelsLoaded &&
            state.reels.any((r) => r.id == widget.reel.id)) {
          setState(() => _likeLoading = _repostLoading = false);
        } else if (state is ReelsShareTargetsLoaded &&
            state.reelId == widget.reel.id) {
          _showShareDialog(reelsBloc, state.shareTargets);
        } else if (state is ReelsError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: GestureDetector(
        onTap:
            _errorMessage != null
                ? () {
                    setState(() {
                      _errorMessage = null;
                      _retryCount = 0;
                      _useSoftwareDecoding = true;
                    });
                    _initMedia();
                  }
                : _togglePlayPause,
        child: Stack(
          children: [
            Center(
              child:
                  _errorMessage != null
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
                                  _useSoftwareDecoding = true;
                                });
                                _initMedia();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      : (_isInitialized &&
                              _videoController != null &&
                              _videoController!.value.isInitialized)
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : (_isInitialized && _audioPlayer != null)
                              ? Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                )
                              : (widget.reel.thumbnail != null &&
                                      widget.reel.thumbnail!.isNotEmpty)
                                  ? Image.network(widget.reel.thumbnail!, fit: BoxFit.cover)
                                  : const CircularProgressIndicator(color: Colors.white),
            ),
            Positioned(
              left: 12,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: widget.reel.userProfileDetails.profileImage.isNotEmpty
                                ? NetworkImage(widget.reel.userProfileDetails.profileImage)
                                : const AssetImage('assets/images/avataruser.png') as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.reel.userProfileDetails.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.reel.title.isNotEmpty
                        ? widget.reel.title
                        : 'No title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.reel.caption.isNotEmpty
                        ? widget.reel.caption
                        : 'No caption',
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 80,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      widget.reel.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: widget.reel.isLiked ? Colors.red : Colors.white,
                    ),
                    onPressed:
                        _likeLoading
                            ? null
                            : () {
                                setState(() => _likeLoading = true);
                                reelsBloc.add(
                                  LikeReelEvent(
                                    reelId: widget.reel.id,
                                    like: !widget.reel.isLiked,
                                  ),
                                );
                              },
                  ),
                  Text(
                    '${widget.reel.likesCount}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: Image.asset(
                      'assets/images/comment.png',
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      showReelCommentsBottomSheet(
                        context,
                        reelId: widget.reel.id,
                      );
                    },
                  ),
                  Text(
                    '${widget.reel.commentsCount}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: Image.asset(
                      'assets/images/send.png',
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      reelsBloc.add(ShareReelEvent(reelId: widget.reel.id));
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<String?>(
                    future: di.sl<SessionManager>().getUserId(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data == widget.reel.userProfileDetails.id) {
                        return IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed:
                              _likeLoading || _repostLoading
                                  ? null
                                  : () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (dialogContext) => AlertDialog(
                                              title: const Text('Delete Reel'),
                                              content: const Text(
                                                'Are you sure you want to delete this reel?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        dialogContext,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    reelsBloc.add(
                                                      DeleteReelEvent(
                                                        reelId: widget.reel.id,
                                                      ),
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
