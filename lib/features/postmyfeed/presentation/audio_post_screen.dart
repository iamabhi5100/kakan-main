import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_event.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_state.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:just_audio/just_audio.dart';

class AudioPostScreen extends StatefulWidget {
  final String? filePath;
  final String? mediaId;
  final String? title;

  const AudioPostScreen({
    super.key,
    this.filePath,
    this.mediaId,
    this.title,
  });

  @override
  State<AudioPostScreen> createState() => _AudioPostScreenState();
}

class _AudioPostScreenState extends State<AudioPostScreen> {
  // ---- Dark palette (UI only) ----
  static const _bg      = Color(0xFF0F1115);
  static const _card    = Color(0xFF171A20);
  static const _muted   = Color(0xFF9AA4B2);
  static const _text    = Color(0xFFE6EAF2);
  static const _accent  = Color(0xFF00E5A8);
  static const _accent2 = Color(0xFF4C82FB);
  static const _field   = Color(0xFF141821);
  static const _border  = Color(0xFF2A3242);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  String _privacy = '';

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _canShare = false;

  // NEW: once true, we never show loading again on this screen
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    if (widget.title != null) {
      _titleController.text = widget.title!;
    }
    if (widget.filePath != null) {
      _initAudioPlayer();
    }
    _updateCanShare();
  }

  void _updateCanShare() {
    setState(() {
      _canShare = widget.filePath != null &&
          _titleController.text.trim().isNotEmpty &&
          _privacy.isNotEmpty;
    });
  }

  void _initAudioPlayer() async {
    if (widget.filePath != null) {
      try {
        await _audioPlayer.setUrl(widget.filePath!);
        _audioPlayer.durationStream.listen((d) {
          if (mounted) setState(() => _duration = d ?? Duration.zero);
        });
        _audioPlayer.positionStream.listen((p) {
          if (mounted) setState(() => _position = p);
        });
        _audioPlayer.playingStream.listen((playing) {
          if (mounted) setState(() => _isPlaying = playing);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load audio: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  ThemeData _theme(BuildContext context) {
    return Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent2,
        surface: _card,
        background: _bg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: _text,
            displayColor: _text,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _field,
        labelStyle: const TextStyle(color: _muted),
        hintStyle: const TextStyle(color: _muted),
        counterStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _border),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: _bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
        ),
      ),
      sliderTheme: SliderTheme.of(context).copyWith(
        activeTrackColor: _accent,
        inactiveTrackColor: const Color(0xFF253046),
        thumbColor: _accent,
        overlayColor: _accent.withOpacity(.2),
        trackHeight: 4,
      ),
      chipTheme: ChipTheme.of(context).copyWith(
        backgroundColor: _field,
        selectedColor: const Color(0xFF1E2430),
        labelStyle: const TextStyle(color: _text, fontWeight: FontWeight.w600),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF232A36),
        contentTextStyle: TextStyle(color: _text),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme(context),
      child: BlocProvider(
        create: (_) => di.sl<PostBloc>(),
        child: BlocConsumer<PostBloc, PostState>(
          listenWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
          listener: (context, state) {
            if (state is PostCreated) {
              // mark posted to suppress any loaders
              _posted = true;

              toastification.show(
                context: context,
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                title: const Text('Success'),
                description: const Text('Audio uploaded successfully!'),
                alignment: Alignment.topCenter,
                autoCloseDuration: const Duration(seconds: 2),
                icon: const Icon(Icons.check_circle),
                boxShadow: lowModeShadow,
                showProgressBar: true,
              );

              // Navigate right away (video screen also navigates immediately)
              context.go('/home');
            } else if (state is PostError) {
              String errorMessage = state.message;
              if (state.message.contains('Media file is required')) {
                errorMessage = 'Media file is required. Please ensure a valid audio is selected.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to upload audio: $errorMessage')),
              );
            }
          },
          builder: (context, state) {
            // <- IMPORTANT: once _posted is true, never show loaders again
            final isLoading = !_posted && state is PostLoading;

            return Scaffold(
              appBar: AppBar(
                title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w800)),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: _text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Audio card
                    Container(
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 8)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: widget.filePath != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _titleController,
                                  builder: (_, value, __) {
                                    final displayTitle = value.text.isNotEmpty
                                        ? value.text
                                        : (widget.filePath?.split('/').last ?? 'Audio');
                                    return Text(
                                      displayTitle,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 18),
                                Slider(
                                  min: 0.0,
                                  max: _duration.inSeconds > 0
                                      ? _duration.inSeconds.toDouble()
                                      : 1.0,
                                  value: _position.inSeconds
                                      .toDouble()
                                      .clamp(0.0, _duration.inSeconds.toDouble()),
                                  onChanged: (value) async {
                                    final position = Duration(seconds: value.toInt());
                                    await _audioPlayer.seek(position);
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(_position), style: const TextStyle(color: _muted, fontSize: 12)),
                                      Text(_formatDuration(_duration), style: const TextStyle(color: _muted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.replay_10_rounded, color: _text, size: 26),
                                      onPressed: () {
                                        final newPos = _audioPlayer.position - const Duration(seconds: 10);
                                        _audioPlayer.seek(newPos < Duration.zero ? Duration.zero : newPos);
                                      },
                                    ),
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                                      child: IconButton(
                                        icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: _bg, size: 36),
                                        onPressed: () async {
                                          if (_isPlaying) {
                                            await _audioPlayer.pause();
                                          } else {
                                            await _audioPlayer.play();
                                          }
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.forward_10_rounded, color: _text, size: 26),
                                      onPressed: () {
                                        final newPos = _audioPlayer.position + const Duration(seconds: 10);
                                        _audioPlayer.seek(newPos > _duration ? _duration : newPos);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : const ListTile(
                              leading: Icon(Icons.audiotrack_rounded, size: 36, color: _muted),
                              title: Text('No audio selected', style: TextStyle(color: _text)),
                              subtitle: Text('Please select an audio file', style: TextStyle(color: _muted)),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Title*', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      maxLength: 50,
                      style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Enter Title (Max 50 Letters)',
                      ),
                      onChanged: (_) => _updateCanShare(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Caption (Optional)', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _captionController,
                      maxLength: 500,
                      maxLines: 5,
                      style: const TextStyle(color: _text),
                      decoration: const InputDecoration(
                        hintText: 'Add a caption...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Privacy', style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('Public'),
                          selected: _privacy == 'Public',
                          onSelected: (selected) {
                            setState(() {
                              _privacy = selected ? 'Public' : '';
                              _updateCanShare();
                            });
                          },
                          selectedColor: const Color(0xFF1E2430),
                          side: BorderSide(color: _privacy == 'Public' ? _accent : _border, width: _privacy == 'Public' ? 1.4 : 1.0),
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('Followers'),
                          selected: _privacy == 'Followers',
                          onSelected: (selected) {
                            setState(() {
                              _privacy = selected ? 'Followers' : '';
                              _updateCanShare();
                            });
                          },
                          selectedColor: const Color(0xFF1E2430),
                          side: BorderSide(color: _privacy == 'Followers' ? _accent : _border, width: _privacy == 'Followers' ? 1.4 : 1.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    BlocBuilder<PostBloc, PostState>(
                      builder: (context, state) {
                        final isLoadingBtn = !_posted && state is PostLoading;
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoadingBtn || !_canShare
                                ? null
                                : () {
                                    context.read<PostBloc>().add(
                                          CreatePostEvent(
                                            mediaType: 'audio',
                                            title: _titleController.text.trim(),
                                            caption: _captionController.text.isEmpty ? null : _captionController.text,
                                            mediaFilePath: widget.filePath,
                                            mediaId: widget.mediaId,
                                            thumbnailPath: null,
                                            shareTo: _privacy.toLowerCase(),
                                          ),
                                        );
                                  },
                            child: isLoadingBtn
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.6, color: _bg),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded),
                                      SizedBox(width: 10),
                                      Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
