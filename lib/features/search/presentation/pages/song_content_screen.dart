import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';

class SongContentScreen extends StatefulWidget {
  final SearchResult song;
  const SongContentScreen({Key? key, required this.song}) : super(key: key);

  @override
  _SongContentScreenState createState() => _SongContentScreenState();
}

class _SongContentScreenState extends State<SongContentScreen> {
  late AudioPlayer _player;
  late Stream<Duration> _positionStream;
  late Stream<Duration?> _durationStream;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    final url = widget.song.mediaFile;
    assert(url != null, 'Audio URL is null');
    _player.setUrl(url!);
    _positionStream = _player.positionStream;
    _durationStream = _player.durationStream;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.song;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: Text(meta.name ?? '', style: const TextStyle(color: Colors.black)),
        elevation: 1,
      ),
      body: Column(
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

          const SizedBox(height: 24),

          // — audio slider + controls —
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                StreamBuilder<bool>(
                  stream: _player.playingStream,
                  builder: (_, snap) {
                    final playing = snap.data ?? false;
                    return IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 30,
                      ),
                      onPressed: () {
                        playing ? _player.pause() : _player.play();
                      },
                    );
                  },
                ),
                Expanded(
                  child: StreamBuilder<Duration?>(
                    stream: _durationStream,
                    builder: (_, dSnap) {
                      final total = dSnap.data ?? Duration.zero;
                      return StreamBuilder<Duration>(
                        stream: _positionStream,
                        builder: (_, pSnap) {
                          var pos = pSnap.data ?? Duration.zero;
                          if (pos > total) pos = total;
                          return Slider(
                            min: 0,
                            max: total.inMilliseconds.toDouble(),
                            value: pos.inMilliseconds.toDouble(),
                            onChanged: (ms) {
                              _player.seek(Duration(milliseconds: ms.round()));
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                IconButton(icon: const Icon(Icons.volume_up), onPressed: () {}),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // — actions row —
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Row(
                  children: const [
                    Icon(Icons.favorite_border),
                    SizedBox(width: 4),
                    Text('100 Likes'),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: const [
                    Icon(Icons.repeat),
                    SizedBox(width: 4),
                    Text('5 Reposts'),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.send),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // — description —
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(meta.description ?? ''),
          ),

          const SizedBox(height: 4),

          // — timestamp —
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              meta.created ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
