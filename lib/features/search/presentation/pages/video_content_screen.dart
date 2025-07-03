import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';

class VideoContentScreen extends StatefulWidget {
  final SearchResult video;
  const VideoContentScreen({Key? key, required this.video}) : super(key: key);

  @override
  _VideoContentScreenState createState() => _VideoContentScreenState();
}

class _VideoContentScreenState extends State<VideoContentScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    final url = widget.video.mediaFile ?? '';
    _controller = VideoPlayerController.network(url);
    // capture the Future for .initialize()
    _initFuture = _controller.initialize().then((_) {
      // once ready, start playing
      _controller.play();
      // and loop for good measure
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.video;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: Text(meta.name ?? '', style: const TextStyle(color: Colors.black)),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // — user header —
            ListTile(
              leading: meta.profileImage != null
                  ? CircleAvatar(backgroundImage: NetworkImage(meta.profileImage!))
                  : const CircleAvatar(child: Icon(Icons.person)),
              title: Text(meta.username ?? ''),
              subtitle: Text(meta.name ?? ''),
              trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
            ),

            const SizedBox(height: 12),

            // — video player or placeholder —
            FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // initialized → show the video
                  return AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      children: [
                        VideoPlayer(_controller),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: IconButton(
                            icon: Icon(
                              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () {
                              setState(() {
                                _controller.value.isPlaying
                                    ? _controller.pause()
                                    : _controller.play();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  // failed to load → show thumbnail or an “unavailable” widget
                  if (meta.thumbnail != null) {
                    return Image.network(
                      meta.thumbnail!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    height: 200,
                    color: Colors.black12,
                    child: const Center(
                      child: Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                    ),
                  );
                } else {
                  // still loading
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // — actions row —
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_border),
                      const SizedBox(width: 4),
                      Text('${meta.likesCount ?? 0} Likes'),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Icon(Icons.repeat),
                      const SizedBox(width: 4),
                      Text('${meta.repostCount ?? 0} Reposts'),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.send),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // — description —
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(meta.description ?? ''),
            ),

            const SizedBox(height: 8),

            // — timestamp —
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                meta.created ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
