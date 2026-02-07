import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crop_image/crop_image.dart';

/// In-Flutter image editor: crop & rotate with SafeArea and consistent UI.
/// Uses crop_image (pure Dart) so the toolbar is always visible above the nav bar.
class PostImageEditorScreen extends StatefulWidget {
  final String filePath;

  const PostImageEditorScreen({super.key, required this.filePath});

  @override
  State<PostImageEditorScreen> createState() => _PostImageEditorScreenState();
}

class _PostImageEditorScreenState extends State<PostImageEditorScreen> {
  static const Color _bg = Color(0xFF0D0E12);
  static const Color _surface = Color(0xFF16181D);
  static const Color _accent = Color(0xFF00D9A5);
  static const Color _muted = Color(0xFF8B92A0);
  static const Color _text = Color(0xFFE8EAEF);

  String? _currentPath;
  bool _loading = true;
  String? _error;
  late CropController _cropController;
  double? _aspectRatio; // null = original

  @override
  void initState() {
    super.initState();
    _cropController = CropController(aspectRatio: _aspectRatio);
    _ensureLocalPath();
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _ensureLocalPath() async {
    final path = widget.filePath;
    if (path.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No image path provided';
      });
      return;
    }
    if (path.startsWith('http')) {
      try {
        final tempPath = await _downloadToTemp(path);
        if (!mounted) return;
        setState(() {
          _currentPath = tempPath;
          _loading = false;
          _error = null;
        });
      } catch (e) {
        if (kDebugMode) debugPrint('Download image error: $e');
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not load image';
        });
      }
    } else {
      final file = File(path);
      if (await file.exists()) {
        setState(() {
          _currentPath = path;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Image file not found';
        });
      }
    }
  }

  Future<String> _downloadToTemp(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final dir = await getTemporaryDirectory();
    final uriPath = Uri.parse(url).path;
    final ext = uriPath.contains('.') ? '.${uriPath.split('.').last}' : '.jpg';
    final name = 'img_${DateTime.now().millisecondsSinceEpoch}${ext.length > 1 ? ext : '.jpg'}';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  void _setAspectRatio(double? ratio) {
    setState(() {
      _aspectRatio = ratio;
      _cropController.aspectRatio = ratio;
    });
  }

  Future<void> _applyCrop() async {
    if (_currentPath == null) return;
    try {
      final bitmap = await _cropController.croppedBitmap();
      final byteData = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      setState(() => _currentPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crop applied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Crop error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply crop: $e')),
      );
    }
  }

  void _onUse() {
    final path = _currentPath ?? widget.filePath;
    context.pop(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
        title: const Text('Crop & rotate'),
        actions: [
          TextButton(
            onPressed: (_loading || _error != null) ? null : _onUse,
            child: const Text('Use'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: _muted),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: _muted)),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _ensureLocalPath,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final path = _currentPath!;
    return Column(
      children: [
        // Crop area (fills space above toolbar)
        Expanded(
          child: CropImage(
            controller: _cropController,
            image: path.startsWith('http')
                ? Image.network(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _errorWidget(),
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _errorWidget(),
                  ),
            gridColor: Colors.white.withValues(alpha: 0.7),
            gridInnerColor: Colors.white.withValues(alpha: 0.5),
            scrimColor: Colors.black54,
            alwaysShowThirdLines: true,
          ),
        ),
        // Bottom toolbar: SafeArea so it's always above nav bar
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Aspect ratio row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ratioChip('Original', null),
                      const SizedBox(width: 8),
                      _ratioChip('Square', 1),
                      const SizedBox(width: 8),
                      _ratioChip('3:2', 3 / 2),
                      const SizedBox(width: 8),
                      _ratioChip('4:3', 4 / 3),
                      const SizedBox(width: 8),
                      _ratioChip('16:9', 16 / 9),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Rotate + Apply row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _toolButton(
                      icon: Icons.rotate_left_rounded,
                      label: 'Rotate L',
                      onTap: () {
                        _cropController.rotateLeft();
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 24),
                    _toolButton(
                      icon: Icons.rotate_right_rounded,
                      label: 'Rotate R',
                      onTap: () {
                        _cropController.rotateRight();
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 32),
                    FilledButton.icon(
                      onPressed: _applyCrop,
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Apply crop'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _bg,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ratioChip(String label, double? ratio) {
    final selected = _aspectRatio == ratio;
    return GestureDetector(
      onTap: () => _setAspectRatio(ratio),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _accent : _muted.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? _accent : _text,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _accent, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorWidget() {
    return const Icon(Icons.broken_image_rounded, size: 64, color: _muted);
  }
}
