import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';
import 'package:dio/dio.dart';

class AudioPostScreen extends StatefulWidget {
  final String? filePath;

  const AudioPostScreen({super.key, this.filePath});

  @override
  State<AudioPostScreen> createState() => _AudioPostScreenState();
}

class _AudioPostScreenState extends State<AudioPostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  String _shareTo = 'All';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.filePath != null) {
      _titleController.text = widget.filePath!.split('/').last.split('.').first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _shareAudio() async {
    if (widget.filePath == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file and provide a title')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final apiService = di.sl<ApiService>();
      final formDataMap = {
        'media_type': 'audio',
        'media_file': await MultipartFile.fromFile(widget.filePath!),
        'title': _titleController.text,
        'caption': _captionController.text,
        'share_to': _shareTo.toLowerCase(),
      };

      final formData = FormData.fromMap(formDataMap);

      final response = await apiService.post(
        ConstantApi.downloads,
        formData,
        includeAuth: true,
      );

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Success'),
          description: const Text('Audio uploaded successfully!'),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
          icon: const Icon(Icons.check_circle),
          boxShadow: lowModeShadow,
          showProgressBar: true,
        );
        context.go('/home');
      }
    } on ServerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload audio: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error during upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              color: Colors.grey[300],
              child: widget.filePath != null
                  ? Center(
                      child: Text(
                        'Selected Audio: ${widget.filePath!.split('/').last}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.audiotrack, size: 50, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Title*',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter Title (Max 50 Letters)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            const Text(
              'Caption (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Share to'),
                const Spacer(),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _shareTo == 'All',
                  onSelected: (selected) {
                    if (selected) setState(() => _shareTo = 'All');
                  },
                  selectedColor: appTheme.primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: appTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('My Followers'),
                  selected: _shareTo == 'My Followers',
                  onSelected: (selected) {
                    if (selected) setState(() => _shareTo = 'My Followers');
                  },
                  selectedColor: appTheme.primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: appTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _shareAudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Share',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}