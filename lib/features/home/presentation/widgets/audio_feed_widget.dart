import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/share/presentation/share_screen.dart';

class AudioFeedWidget extends StatefulWidget {
  final ProfilePostEntity? post;

  const AudioFeedWidget({super.key, this.post});

  @override
  State<AudioFeedWidget> createState() => _AudioFeedWidgetState();
}

class _AudioFeedWidgetState extends State<AudioFeedWidget> {
  late AudioPlayer _audioPlayer;
  int _likes = 100;
  int _reposts = 5;
  bool _isMuted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
    _audioPlayer.durationStream.listen((d) {
      setState(() {
        _duration = d ?? Duration.zero;
      });
    });
    _audioPlayer.positionStream.listen((p) {
      setState(() {
        _position = p;
      });
    });
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setUrl(widget.post?.mediaFile ?? '');
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _audioPlayer.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _toggleLike() {
    setState(() {
      _likes = _likes == 100 ? 101 : 100;
    });
  }

  void _toggleRepost() {
    setState(() {
      _reposts = _reposts == 5 ? 6 : 5;
    });
  }

  void _toggleShare() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ShareScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.blue,
                    size: 30,
                  ),
                  onPressed: _togglePlayPause,
                ),
                Expanded(
                  child: Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0,
                    activeColor: appTheme.primaryColor,
                    inactiveColor: Colors.grey,
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.grey,
                    size: 24,
                  ),
                  onPressed: _toggleMute,
                ),
              ],
            ),
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
                      onPressed: _toggleLike,
                    ),
                    SizedBox(width: 4),
                    Text('$_likes Likes'),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.repeat, color: Colors.green, size: 16),
                      onPressed: _toggleRepost,
                    ),
                    SizedBox(width: 4),
                    Text('$_reposts Reposts'),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.grey, size: 16),
                  onPressed: _toggleShare,
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
    );
  }
}