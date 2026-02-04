import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_editor_2/video_editor.dart';
import 'package:video_editor_2/ui/video_viewer.dart';
import 'package:video_editor_2/ui/trim/trim_slider.dart';
import 'package:video_editor_2/ui/trim/trim_timeline.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:kakan/services/ffmpeg_exporter.dart';

class PostVideoEditorScreen extends StatefulWidget {
  final String videoPath;
  final String? mediaId;
  final String? title;

  const PostVideoEditorScreen({
    super.key,
    required this.videoPath,
    this.mediaId,
    this.title,
  });

  @override
  State<PostVideoEditorScreen> createState() => _PostVideoEditorScreenState();
}

class _PostVideoEditorScreenState extends State<PostVideoEditorScreen> {
  late VideoEditorController _controller;

  bool _init = false;
  bool _busy = false;

  final _exporting = ValueNotifier<bool>(false);
  final _exportProgress = ValueNotifier<double>(0.0);

  // Start/End text fields
  late TextEditingController _startTextController;
  late TextEditingController _endTextController;
  late FocusNode _startFocusNode;
  late FocusNode _endFocusNode;

  // ===== Aspect Ratio (DISABLED) =====
  // We’ll keep the preview at the video’s natural aspect.
  // If you want to restore manual aspect selection later,
  // uncomment these and the UI section below.
  //
  // double? _aspectOverride; // null = original/free
  // String _selectedAspect = 'Original';
  // final Map<String, double?> _aspectOptions = const {
  //   'Original': null,
  //   '1:1': 1.0,
  //   '9:16': 9 / 16,
  //   '16:9': 16 / 9,
  //   '4:5': 4 / 5,
  // };
  // Future<void> _setAspect(String label) async {
  //   final ratio = _aspectOptions[label];
  //   setState(() {
  //     _selectedAspect = label;
  //     _aspectOverride = ratio;
  //   });
  //   await Future<void>.delayed(Duration.zero);
  //   if (!mounted) return;
  //   try {
  //     _controller.cropAspectRatio(ratio);
  //   } catch (_) {}
  // }
  // ===================================

  // ----------------- DARK THEME COLORS -----------------
  static const Color _bg       = Color(0xFF0F1115); // page background
  static const Color _card     = Color(0xFF171A20); // cards/strips
  static const Color _muted    = Color(0xFF9AA4B2); // secondary text
  static const Color _text     = Color(0xFFE6EAF2); // primary text
  static const Color _accent   = Color(0xFF00E5A8); // primary accent
  static const Color _accent2  = Color(0xFF4C82FB); // secondary accent
  static const Color _fieldBg  = Color(0xFF141821); // text field fill
  static const Color _trimBg   = Color(0xFF131720); // trim container
  static const Color _overlay  = Color(0x7F000000); // busy overlay
  // -----------------------------------------------------

  void _syncFieldsFromController() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_startFocusNode.hasFocus) {
        final t = _fmt(_controller.startTrim);
        if (_startTextController.text != t) {
          _startTextController.value = TextEditingValue(text: t);
        }
      }
      if (!_endFocusNode.hasFocus) {
        final t = _fmt(_controller.endTrim);
        if (_endTextController.text != t) {
          _endTextController.value = TextEditingValue(text: t);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _controller = VideoEditorController.file(
        XFile(widget.videoPath),
        minDuration: const Duration(seconds: 1),
        maxDuration: const Duration(minutes: 10),
      );
      await _controller.initialize();
      if (!mounted) return;

      _startTextController = TextEditingController(text: _fmt(_controller.startTrim));
      _endTextController = TextEditingController(text: _fmt(_controller.endTrim));
      _startFocusNode = FocusNode();
      _endFocusNode = FocusNode();

      _controller.addListener(_syncFieldsFromController);

      setState(() => _init = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load video: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _exporting.dispose();
    _exportProgress.dispose();
    if (_init) {
      _controller.removeListener(_syncFieldsFromController);
      _startTextController.dispose();
      _endTextController.dispose();
      _startFocusNode.dispose();
      _endFocusNode.dispose();
      _controller.dispose();
    }
    super.dispose();
  }

  // ---------- helpers ----------

  String _fmt(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  Duration _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return Duration.zero;
    final m = int.tryParse(parts[0]) ?? 0;
    final s = int.tryParse(parts[1]) ?? 0;
    if (m < 0 || s < 0 || s >= 60) return Duration.zero;
    return Duration(minutes: m, seconds: s);
  }

  Future<String> _ioOutputPath(String inputPath, {String ext = 'mp4'}) async {
    final dir = await getTemporaryDirectory();
    final name = p.basenameWithoutExtension(inputPath);
    final epoch = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${name}_trim_$epoch.$ext');
  }

  Future<String?> _exportTrimmed() async {
    if (!_controller.initialized || _exporting.value) return null;

    _exporting.value = true;
    _exportProgress.value = 0.0;

    try {
      final cfg = _controller.createVideoFFmpegConfig();
      final input = _controller.file.path;
      final out = await _ioOutputPath(input, ext: 'mp4');

      final cmd = cfg.createExportCommand(
        inputPath: input,
        outputPath: out,
        outputFormat: VideoExportFormat.mp4,
        scale: 1.0,
        isFiltersEnabled: true,
      );

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final log = await session.getAllLogsAsString();
        throw Exception('FFmpeg failed (${rc?.getValue()}): $log');
      }

      if (!await File(out).exists()) {
        throw Exception('Exported file not found.');
      }
      return out;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return null;
    } finally {
      _exporting.value = false;
    }
  }

  Future<void> _onDone() async {
    setState(() => _busy = true);
    try {
      final trimmed = await _exportTrimmed();
      if (trimmed == null) return;

      final safe = await FFmpegExporter.export(
        trimmed,
        copyIfNoEdits: false,
        crf: 21,
        preset: 'veryfast',
      );

      if (!mounted) return;
      context.go('/video-post', extra: {
        'filePath': safe,
        'mediaId': widget.mediaId ?? '',
        'title': widget.title ?? '',
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyStartFromField(String value) {
    final vd = _controller.videoDuration;
    if (vd == Duration.zero) return;

    final newStart = _parseTime(value);
    if (newStart <= Duration.zero ||
        newStart >= _controller.endTrim ||
        newStart >= vd) {
      _startTextController.value =
          TextEditingValue(text: _fmt(_controller.startTrim));
      return;
    }

    final minValue = newStart.inMilliseconds / vd.inMilliseconds;
    final maxValue = _controller.endTrim.inMilliseconds / vd.inMilliseconds;
    _controller.updateTrim(minValue, maxValue);
  }

  void _applyEndFromField(String value) {
    final vd = _controller.videoDuration;
    if (vd == Duration.zero) return;

    final newEnd = _parseTime(value);
    if (newEnd <= _controller.startTrim ||
        newEnd > vd ||
        newEnd <= Duration.zero) {
      _endTextController.value =
          TextEditingValue(text: _fmt(_controller.endTrim));
      return;
    }

    final minValue = _controller.startTrim.inMilliseconds / vd.inMilliseconds;
    final maxValue = newEnd.inMilliseconds / vd.inMilliseconds;
    _controller.updateTrim(minValue, maxValue);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (!_init) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final theme = Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent2,
        surface: _card,
        background: _bg,
        onPrimary: _bg,
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: _text,
            displayColor: _text,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _fieldBg,
        hintStyle: const TextStyle(color: _muted),
        labelStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF30384A)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent2,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF232A36),
        contentTextStyle: TextStyle(color: _text),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Preview aspect = the controller’s natural one (no manual override).
    final double previewAspectRaw =
        _controller.preferredCropAspectRatio ??
        _controller.video.value.aspectRatio;
    final double previewAspect = (previewAspectRaw <= 0) ? 1.0 : previewAspectRaw;

    return Theme(
      data: theme,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              title: const Text('Trim Video'),
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                const double paddingH = 12.0 * 2; // L+R padding around card

                // clamp() returns num -> cast to double.
                final double availableWidth =
                    (constraints.maxWidth - paddingH).clamp(0.0, double.infinity) as double;
                final double maxPreviewHeight =
                    (constraints.maxHeight * 0.55).clamp(120.0, double.infinity) as double;

                // Compute preview size WITHOUT distortion:
                double widthByFull = availableWidth;
                double heightByFull = widthByFull / previewAspect;

                late double previewWidth;
                late double previewHeight;

                if (heightByFull <= maxPreviewHeight) {
                  previewWidth = widthByFull;
                  previewHeight = heightByFull;
                } else {
                  previewHeight = maxPreviewHeight;
                  previewWidth = previewHeight * previewAspect;
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      // Preview card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 14,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: double.infinity,
                            child: Center(
                              child: SizedBox(
                                width: previewWidth,
                                height: previewHeight,
                                child: AspectRatio(
                                  aspectRatio: previewAspect,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRect(child: VideoViewer(controller: _controller)),
                                      AnimatedBuilder(
                                        animation: _controller.video,
                                        builder: (_, __) => AnimatedOpacity(
                                          opacity: _controller.isPlaying ? 0.0 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(.35),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              iconSize: 64,
                                              color: Colors.white,
                                              icon: const Icon(Icons.play_arrow_rounded),
                                              onPressed: _controller.video.play,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== Aspect Ratio UI (DISABLED) =====
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(horizontal: 12),
                      //   child: Align(
                      //     alignment: Alignment.centerLeft,
                      //     child: Text(
                      //       'Aspect Ratio',
                      //       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      //             color: _muted,
                      //             fontWeight: FontWeight.w600,
                      //           ),
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(height: 6),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(horizontal: 12),
                      //   child: Wrap(
                      //     spacing: 8,
                      //     runSpacing: 8,
                      //     children: _aspectOptions.entries.map((e) {
                      //       final selected = _selectedAspect == e.key;
                      //       return ChoiceChip(
                      //         label: Text(
                      //           e.key,
                      //           style: TextStyle(
                      //             color: selected ? _accent : _text,
                      //             fontWeight: FontWeight.w600,
                      //           ),
                      //         ),
                      //         selected: selected,
                      //         backgroundColor: const Color(0xFF141821),
                      //         selectedColor: const Color(0xFF1E2430),
                      //         side: BorderSide(
                      //           color: selected ? _accent : const Color(0xFF2A3242),
                      //           width: selected ? 1.4 : 1.0,
                      //         ),
                      //         onSelected: (_) => _setAspect(e.key),
                      //         shape: RoundedRectangleBorder(
                      //           borderRadius: BorderRadius.circular(10),
                      //         ),
                      //         pressElevation: 0,
                      //         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //       );
                      //     }).toList(),
                      //   ),
                      // ),
                      // =====================================

                      const SizedBox(height: 12),

                      // Playhead + start/end labels
                      AnimatedBuilder(
                        animation: Listenable.merge([_controller, _controller.video]),
                        builder: (_, __) {
                          final durSecs = _controller.videoDuration.inSeconds;
                          final pos = _controller.trimPosition * durSecs;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  pos.isFinite
                                      ? _fmt(Duration(seconds: pos.toInt()))
                                      : '00:00',
                                  style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Text(
                                  '${_fmt(_controller.startTrim)}  —  ${_fmt(_controller.endTrim)}',
                                  style: const TextStyle(color: _muted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Trim bar (slider + timeline)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _trimBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2A3242)),
                          ),
                          child: TrimSlider(
                            controller: _controller,
                            height: 64,
                            horizontalMargin: 16,
                            child: TrimTimeline(
                              controller: _controller,
                              padding: const EdgeInsets.only(top: 6),
                            ),
                          ),
                        ),
                      ),

                      // Start/End fields (mm:ss)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _startTextController,
                                focusNode: _startFocusNode,
                                keyboardType: TextInputType.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  labelText: 'Start',
                                  hintText: 'mm:ss',
                                ),
                                onSubmitted: _applyStartFromField,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _endTextController,
                                focusNode: _endFocusNode,
                                keyboardType: TextInputType.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  labelText: 'End',
                                  hintText: 'mm:ss',
                                ),
                                onSubmitted: _applyEndFromField,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Done button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _onDone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: _bg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded),
                                SizedBox(width: 10),
                                Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: _overlay,
                child: Center(child: CircularProgressIndicator(color: _accent)),
              ),
            ),
        ],
      ),
    );
  }
}
