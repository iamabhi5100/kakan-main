import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/home/data/models/share_models.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/model/usecases/get_users_to_share.dart';
import 'package:kakan/features/home/model/usecases/send_share_message.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

class ShareScreen extends StatefulWidget {
  final String? mediaFile; // Can be a URL or local file path
  final String? mediaType;
  final String? caption;
  /// Post title; included in shared text.
  final String? title;
  /// Post ID for share link; when set, shared link opens this post in app (e.g. appShareUrl/post/{postId}).
  final String? postId;
  /// All media items (carousel or single); image URLs are downloaded and attached when sharing externally.
  final List<FeedMediaItem>? mediaItems;

  const ShareScreen({
    super.key,
    this.mediaFile,
    this.mediaType,
    this.caption,
    this.title,
    this.postId,
    this.mediaItems,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedItems = {};
  List<ShareItem> _shareItems = [];
  List<ShareItem> _filteredItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchShareItems();
    _searchController.addListener(_filterItems);
  }

  void _fetchShareItems() async {
    final getUsersToShare = di.sl<GetUsersToShare>();
    final result = await getUsersToShare(NoParams());
    setState(() {
      result.fold(
        (failure) {
          if (failure is ServerFailure && failure.exception != null) {
            _errorMessage = failure.exception!.message ?? 'Failed to load shareable items';
          } else {
            _errorMessage = 'Failed to load shareable items';
          }
          _isLoading = false;
        },
        (items) {
          _shareItems = items;
          _filteredItems = items;
          _isLoading = false;
          print('DEBUG: Fetched items: ${items.map((item) => {'type': item.type, 'name': item.type == 'user' ? item.data.name : item.name}).toList()}');
        },
      );
    });
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _shareItems.where((item) {
        if (item.type == 'user') {
          return item.data.name.toLowerCase().contains(query) ||
              item.data.username.toLowerCase().contains(query);
        } else {
          return (item.name?.toLowerCase().contains(query) ?? false) ||
              item.data.participantsDetails!.receivers.any((p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.username.toLowerCase().contains(query)) ||
              (item.data.participantsDetails!.sender.name.toLowerCase().contains(query) ||
                  item.data.participantsDetails!.sender.username.toLowerCase().contains(query));
        }
      }).toList();
    });
  }

  void _toggleItemSelection(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
      } else {
        _selectedItems.add(index);
      }
    });
  }

  void _handleSend() async {
    if (_selectedItems.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: SpinKitCircle(
                color: Colors.blue,
                size: 60.0,
              ),
            ),
          ),
        ),
      );

      final selected = _selectedItems.map((index) => _filteredItems[index]).toList();
      final sendMessage = di.sl<SendShareMessage>();
      final messageType = widget.mediaType ?? 'text';
      final content = _buildFullShareMessage();

      bool hasError = false;
      for (final item in selected) {
        if (item.chatId == null) continue;
        print('DEBUG: Sending message to ${item.type == 'user' ? item.data.name : item.name}');
        final result = await sendMessage(SendShareMessageParams(
          chatId: item.chatId!,
          type: item.type,
          content: content,
          messageType: messageType,
          mediaFileUrl: widget.mediaFile,
        ));
        if (!mounted) return;
        result.fold(
          (failure) {
            hasError = true;
            toastification.show(
              context: context,
              title: Text(
                (failure is ServerFailure && failure.exception != null)
                    ? failure.exception!.message ?? 'Failed to send message to ${item.type == 'user' ? item.data.name : item.name}'
                    : 'Failed to send message to ${item.type == 'user' ? item.data.name : item.name}',
              ),
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              autoCloseDuration: const Duration(seconds: 3),
            );
          },
          (_) {
            toastification.show(
              context: context,
              title: Text('Message sent to ${item.type == 'user' ? item.data.name : item.name}'),
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              autoCloseDuration: const Duration(seconds: 3),
            );
          },
        );
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (!hasError) {
          Navigator.pop(context);
        }
      }
    }
  }

  /// Builds share text for external share: "title :- ..." and "caption :- ..." lines.
  String _buildShareMessageForExternal() {
    final parts = <String>[];
    if (widget.title != null && widget.title!.trim().isNotEmpty) {
      parts.add('title :- ${widget.title!.trim()}');
    }
    if (widget.caption != null && widget.caption!.trim().isNotEmpty) {
      parts.add('caption :- ${widget.caption!.trim()}');
    }
    return parts.join('\n');
  }

  /// Full share message: promo + download link + title + caption (used as caption with media when 1 file).
  String _buildFullShareMessage() {
    final lines = <String>[
      ConstantApi.sharePromoMessage,
      'Download: ${ConstantApi.shareDownloadLink}',
      '',
    ];
    final titleCaption = _buildShareMessageForExternal();
    if (titleCaption.trim().isNotEmpty) {
      lines.add(titleCaption);
    }
    return lines.join('\n');
  }

  /// Supported media types for download-and-attach: image, video, audio. Carousel uses [mediaItems] or fallback.
  static const _attachableTypes = ['image', 'video', 'audio'];

  /// Infers media type from URL (e.g. .mp4 -> video, .mp3 -> audio) for carousel fallback.
  static String _inferTypeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp4') || lower.contains('.webm') || lower.contains('.mov')) return 'video';
    if (lower.contains('.mp3') || lower.contains('.m4a') || lower.contains('.ogg') || lower.contains('.wav')) return 'audio';
    return 'image';
  }

  /// Collects (url, type) for all attachable media from [mediaItems] or single [mediaFile].
  /// Carousel: uses all [mediaItems]; if missing, falls back to [mediaFile] with type inferred from URL.
  List<({String url, String type})> _mediaToAttach() {
    final list = <({String url, String type})>[];
    if (widget.mediaItems != null && widget.mediaItems!.isNotEmpty) {
      for (final m in widget.mediaItems!) {
        final type = m.type;
        final resolvedType = type == 'carousel' ? _inferTypeFromUrl(m.mediaFile) : type;
        if ((_attachableTypes.contains(type) || type == 'carousel') && m.mediaFile.isNotEmpty) {
          list.add((url: m.mediaFile, type: resolvedType));
        }
      }
    } else if (widget.mediaFile != null &&
        widget.mediaFile!.trim().isNotEmpty &&
        !File(widget.mediaFile!).existsSync()) {
      final url = widget.mediaFile!.trim();
      if (!url.startsWith('http')) return list;
      final type = widget.mediaType;
      if (type != null && (_attachableTypes.contains(type) || type == 'carousel')) {
        final resolvedType = type == 'carousel' ? _inferTypeFromUrl(url) : type;
        list.add((url: url, type: resolvedType));
      }
    }
    return list;
  }

  /// Picks file extension from URL and media type for saving.
  String _extensionFor(String url, String type) {
    final lower = url.toLowerCase();
    if (type == 'video') {
      if (lower.contains('.mp4')) return 'mp4';
      if (lower.contains('.webm')) return 'webm';
      if (lower.contains('.mov')) return 'mov';
      return 'mp4';
    }
    if (type == 'audio') {
      if (lower.contains('.mp3')) return 'mp3';
      if (lower.contains('.m4a')) return 'm4a';
      if (lower.contains('.ogg')) return 'ogg';
      if (lower.contains('.wav')) return 'wav';
      return 'mp3';
    }
    // image
    if (lower.contains('.png')) return 'png';
    if (lower.contains('.gif')) return 'gif';
    if (lower.contains('.webp')) return 'webp';
    return 'jpg';
  }

  /// Downloads media from [url] to a temp file; returns path or null on failure.
  Future<String?> _downloadMediaToTemp(String url, String type) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      final dir = await getTemporaryDirectory();
      final ext = _extensionFor(url, type);
      final file = File('${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}_${resp.bodyBytes.length}.$ext');
      await file.writeAsBytes(resp.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareExternally() async {
    final shareOrigin = Rect.fromLTWH(
      0,
      0,
      MediaQuery.of(context).size.width,
      MediaQuery.of(context).size.height / 2,
    );

    try {
      // 1) Local file already on device (e.g. from editor) – one file + text = one message in WhatsApp
      final hasLocalFile = widget.mediaFile != null &&
          widget.mediaFile!.isNotEmpty &&
          File(widget.mediaFile!).existsSync();
      if (hasLocalFile) {
        await _shareFilesWithCaptionIfSingle(
          [XFile(widget.mediaFile!)],
          shareOrigin,
        );
        if (mounted) _onShareComplete(hadFiles: true, multipleFiles: false);
        return;
      }

      // 2) Media URLs (image, video, audio): download then attach
      final mediaList = _mediaToAttach();
      if (mediaList.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Preparing media…'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final files = <XFile>[];
        for (final item in mediaList) {
          final path = await _downloadMediaToTemp(item.url, item.type);
          if (path != null) files.add(XFile(path));
        }
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (files.isNotEmpty) {
          await _shareFilesWithCaptionIfSingle(files, shareOrigin);
          if (mounted) _onShareComplete(hadFiles: true, multipleFiles: files.length > 1);
        } else {
          await Share.share(
            _buildFullShareMessage(),
            subject: widget.title?.trim().isNotEmpty == true ? widget.title : 'Shared Post',
            sharePositionOrigin: shareOrigin,
          );
          if (mounted) _onShareComplete(hadFiles: false);
        }
        return;
      }

      // 3) Text only (no media) – include promo + link + title + caption
      await Share.share(
        _buildFullShareMessage(),
        subject: widget.title?.trim().isNotEmpty == true ? widget.title : 'Shared Post',
        sharePositionOrigin: shareOrigin,
      );
      if (mounted) _onShareComplete(hadFiles: false);
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          title: Text('Failed to share: $e'),
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      print('ERROR: Failed to share externally: $e');
    }
  }

  /// Share files. When exactly one file: add caption so WhatsApp shows one message (text + media).
  /// When multiple files: share only files (Android crashes if we add text with multiple streams).
  Future<void> _shareFilesWithCaptionIfSingle(List<XFile> files, Rect shareOrigin) async {
    final message = _buildFullShareMessage();
    if (files.length == 1) {
      await Share.shareXFiles(
        files,
        text: message,
        subject: widget.title?.trim().isNotEmpty == true ? widget.title : 'Shared Post',
        sharePositionOrigin: shareOrigin,
      );
    } else {
      await Share.shareXFiles(
        files,
        sharePositionOrigin: shareOrigin,
      );
      if (message.trim().isNotEmpty) {
        Clipboard.setData(ClipboardData(text: message));
      }
    }
  }

  void _onShareComplete({required bool hadFiles, bool multipleFiles = false}) {
    if (hadFiles && multipleFiles) {
      toastification.show(
        context: context,
        title: const Text('Media shared. Caption copied – paste in chat to add message.'),
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        autoCloseDuration: const Duration(seconds: 4),
      );
    } else {
      toastification.show(
        context: context,
        title: const Text('Post shared externally'),
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
    print('DEBUG: Shared post externally');
  }

  Future<void> _copyLink() async {
    // Copy link to post (opens app if installed), else generic app/website URL
    final String shareLink = widget.postId != null && widget.postId!.isNotEmpty
        ? ConstantApi.shareUrlForPost(widget.postId!)
        : ConstantApi.appShareUrl;
    try {
      await Clipboard.setData(ClipboardData(text: shareLink));
      if (mounted) {
        toastification.show(
          context: context,
          title: const Text('Link copied to clipboard'),
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      print('DEBUG: Copied link to clipboard');
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          title: Text('Failed to copy link: $e'),
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      print('ERROR: Failed to copy link: $e');
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
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
          ),
          const Gap(16),
          const Text(
            'Share to',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = _selectedItems.contains(index);
                          return GestureDetector(
                            onTap: () => _toggleItemSelection(index),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: item.type == 'user' && item.data.profileImage != null
                                          ? NetworkImage(item.data.profileImage!)
                                          : null,
                                      backgroundColor: const Color.fromARGB(179, 231, 231, 231),
                                      child: item.type == 'group' || item.data.profileImage == null
                                          ? Icon(
                                              item.type == 'group' ? Icons.group : Icons.person,
                                              size: 30,
                                              color: Colors.grey,
                                            )
                                          : null,
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.4),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.blue,
                                          size: 30,
                                        ),
                                      ),
                                  ],
                                ),
                                const Gap(4),
                                Text(
                                  item.type == 'user' ? item.data.name : item.name ?? 'Group',
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
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
                    onPressed: _shareExternally,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                    child: const Icon(Icons.share, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 4),
                  const Text('Share to', style: TextStyle(fontSize: 12, color: Colors.black)),
                ],
              ),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _copyLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                    child: const Icon(Icons.link, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 4),
                  const Text('Copy Link', style: TextStyle(fontSize: 12, color: Colors.black)),
                ],
              ),
            ],
          ),
          const Gap(16),
          if (_selectedItems.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
  }
}