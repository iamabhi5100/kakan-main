import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_state.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_event.dart';
import 'package:kakan/features/share/presentation/share_screen.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';

class VideoFeedWidget extends StatefulWidget {
  final ProfilePostEntity? post;

  const VideoFeedWidget({super.key, this.post});

  @override
  State<VideoFeedWidget> createState() => _VideoFeedWidgetState();
}

class _VideoFeedWidgetState extends State<VideoFeedWidget> {
  late VideoPlayerController _controller;
  int _likes = 1200;
  int _reposts = 5;
  int _comments = 10;
  bool _isMuted = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.post?.mediaFile ?? '')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      }).catchError((error) {
        print("Error initializing video: $error");
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleLike() {
    if (_isDeleting) return;
    setState(() {
      _likes = _likes == 1200 ? 1201 : 1200;
    });
  }

  void _toggleRepost() {
    if (_isDeleting) return;
    setState(() {
      _reposts = _reposts == 5 ? 6 : 5;
    });
  }

  void _toggleShare() {
    if (_isDeleting) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ShareScreen(),
    );
  }

  void _toggleMute() {
    if (_isDeleting) return;
    setState(() {
      _isMuted = !_isMuted;
      _isMuted ? _controller.setVolume(0) : _controller.setVolume(1);
    });
  }

  void _toggleFullScreen() {
    if (_isDeleting) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPage(controller: _controller),
        fullscreenDialog: true,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    if (_isDeleting) return;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDelete(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.report, color: Colors.grey),
                title: Text('Report'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report functionality not implemented')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) async {
    if (_isDeleting) return;
    final deleteBloc = context.read<DeletePostBloc>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Post'),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.post?.id != null && mounted) {
      setState(() {
        _isDeleting = true;
      });
      deleteBloc.add(DeletePostRequested(postId: widget.post!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<DeletePostBloc>(),
      child: Builder(
        builder: (providerContext) => BlocListener<DeletePostBloc, DeletePostState>(
          listener: (context, state) {
            if (state is DeletePostSuccess) {
              if (mounted) {
                setState(() {
                  _isDeleting = false;
                });
                toastification.show(
                  context: context,
                  title: Text('Post deleted successfully'),
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  autoCloseDuration: Duration(seconds: 3),
                );
                // Refresh the post list
                context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(
                    mediaType: widget.post?.mediaType ?? 'video'));
              }
            } else if (state is DeletePostError) {
              if (mounted) {
                setState(() {
                  _isDeleting = false;
                });
                toastification.show(
                  context: context,
                  title: Text(state.message),
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  autoCloseDuration: Duration(seconds: 3),
                );
              }
            }
          },
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: appTheme.primaryColor, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(
                                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQyRhSPTCYGo76ZTjyt2mRqnTPtmz5rWAavFmqn9Wkm54-5detlTZkO_8o&usqp=CAE&s'),
                              backgroundColor: Colors.grey,
                              onBackgroundImageError: (exception, stackTrace) {
                                print("Error loading profile image: $exception");
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Himanshi Khanna',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '@Himanshi5611',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.more_horiz),
                            onPressed: _isDeleting ? null : () => _showMoreOptions(providerContext),
                          ),
                        ],
                      ),
                    ),
                    _controller.value.isInitialized
                        ? SizedBox(
                            height: 200,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                VideoPlayer(_controller),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _isMuted ? Icons.volume_off : Icons.volume_up,
                                          color: Colors.white,
                                        ),
                                        onPressed: _isDeleting ? null : _toggleMute,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.fullscreen, color: Colors.white),
                                        onPressed: _isDeleting ? null : _toggleFullScreen,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            height: 200,
                            color: Colors.grey,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.favorite, color: Colors.red, size: 16),
                                onPressed: _isDeleting ? null : _toggleLike,
                              ),
                              SizedBox(width: 4),
                              Text('$_likes Likes'),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.repeat, color: Colors.green, size: 16),
                                onPressed: _isDeleting ? null : _toggleRepost,
                              ),
                              SizedBox(width: 4),
                              Text('$_reposts Reposts'),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.send, color: Colors.grey, size: 16),
                            onPressed: _isDeleting ? null : _toggleShare,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        widget.post?.caption ?? 'No caption available',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        widget.post?.created ?? 'Unknown time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isDeleting)
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;

  const FullScreenVideoPage({required this.controller, super.key});

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Center(
          child: widget.controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: widget.controller.value.size.width,
                    height: widget.controller.value.size.height,
                    child: VideoPlayer(widget.controller),
                  ),
                )
              : Center(child: CircularProgressIndicator()),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Icon(Icons.close),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}