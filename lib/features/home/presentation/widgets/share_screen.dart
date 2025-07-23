import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/home/data/models/share_models.dart';
import 'package:kakan/features/home/model/usecases/get_users_to_share.dart';
import 'package:kakan/features/home/model/usecases/send_share_message.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class ShareScreen extends StatefulWidget {
  final String? mediaFile;
  final String? mediaType;
  final String? caption;

  const ShareScreen({
    super.key,
    this.mediaFile,
    this.mediaType,
    this.caption,
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
      // Show full-screen loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false, // Prevent dialog dismissal
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
      final content = widget.caption != null ? 'Shared post: ${widget.caption}' : 'Shared a post';

      bool hasError = false;
      for (final item in selected) {
        if (item.chatId == null) continue; // Skip if no chatId
        print('DEBUG: Sending message to ${item.type == 'user' ? item.data.name : item.name}');
        final result = await sendMessage(SendShareMessageParams(
          chatId: item.chatId!,
          type: item.type,
          content: content,
          messageType: messageType,
          mediaFileUrl: widget.mediaFile,
        ));
        if (!mounted) return; // Check if widget is still mounted
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
        // Dismiss full-screen loading dialog
        Navigator.of(context, rootNavigator: true).pop();
        if (!hasError) {
          Navigator.pop(context); // Close bottom sheet
        }
      }
    }
  }

  // Share to external apps
  Future<void> _shareExternally() async {
    if (widget.mediaFile == null || widget.mediaFile!.isEmpty) {
      if (mounted) {
        toastification.show(
          context: context,
          title: const Text('No media file available to share'),
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      return;
    }

    final String message = 'Check out this post: ${widget.mediaFile}\nCaption: ${widget.caption ?? 'No caption'}';
    try {
      await Share.share(
        message,
        subject: 'Shared Post',
        sharePositionOrigin: Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height / 2),
      );
      if (mounted) {
        toastification.show(
          context: context,
          title: const Text('Post shared externally'),
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      print('DEBUG: Shared post externally');
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

  // Copy link to clipboard
  Future<void> _copyLink() async {
    if (widget.mediaFile == null || widget.mediaFile!.isEmpty) {
      if (mounted) {
        toastification.show(
          context: context,
          title: const Text('No media file available to copy'),
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: widget.mediaFile!));
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