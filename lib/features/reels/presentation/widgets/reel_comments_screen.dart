import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/reels/presentation/bloc/reel_lists/reels_bloc.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';

void showReelCommentsBottomSheet(BuildContext context, {required String reelId}) {
  if (kDebugMode) {
    print('ReelCommentsScreen: Showing bottom sheet for reel $reelId');
  }
  // Use the BLoC from the context where the bottom sheet is shown
  final reelsBloc = context.read<ReelsBloc>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) => BlocProvider.value(
      value: reelsBloc,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return ReelCommentsScreen(scrollController: controller, reelId: reelId);
        },
      ),
    ),
  ).whenComplete(() {
    if (kDebugMode) {
      print('ReelCommentsScreen: Bottom sheet closed for reel $reelId');
    }
  });
}

class ReelCommentsScreen extends StatefulWidget {
  final ScrollController scrollController;
  final String reelId;

  const ReelCommentsScreen({
    super.key,
    required this.scrollController,
    required this.reelId,
  });

  @override
  State<ReelCommentsScreen> createState() => _ReelCommentsScreenState();
}

class _ReelCommentsScreenState extends State<ReelCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  String? _currentUserId;
  String? _userProfileImage;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('ReelCommentsScreen: initState for reel ${widget.reelId}');
    }
    _loadCurrentUser();
    context.read<ReelsBloc>().add(GetReelCommentsEvent(reelId: widget.reelId));
  }

  Future<void> _loadCurrentUser() async {
    final sessionManager = di.sl<SessionManager>();
    final userId = await sessionManager.getUserId();
    final profileImage = await sessionManager.getProfileImage();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
        _userProfileImage = profileImage;
      });
    }
  }

  void _addComment() {
    final content = _commentController.text.trim();
    if (content.isNotEmpty) {
      context.read<ReelsBloc>().add(AddReelCommentEvent(
            reelId: widget.reelId,
            content: content,
          ));
      _commentController.clear();
      FocusScope.of(context).unfocus(); // Dismiss keyboard
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('ReelCommentsScreen: dispose called for reel ${widget.reelId}');
    }
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReelsBloc, ReelsState>(
      listener: (context, state) {
        if (state is ReelCommentsError) {
          toastification.show(
            context: context,
            title: Text(state.message),
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      },
      // Build only for comment-related states to avoid rebuilding on reel swipes
      buildWhen: (previous, current) {
        return current is ReelCommentsLoading ||
            current is ReelCommentsLoaded ||
            current is ReelCommentsError;
      },
      builder: (context, state) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Center(
                  child: Text(
                    state is ReelCommentsLoaded ? '${state.comments.length} Comments' : 'Comments',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Builder(builder: (context) {
                  if (state is ReelCommentsLoaded) {
                    if (state.comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet\nStart the conversation',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      itemCount: state.comments.length,
                      itemBuilder: (context, index) {
                        final comment = state.comments[index];
                        return _CommentItem(
                          comment: comment,
                          reelId: widget.reelId,
                          currentUserId: _currentUserId,
                        );
                      },
                    );
                  }
                  if (state is ReelCommentsError) {
                    return Center(child: Text(state.message));
                  }
                  return const Center(child: CircularProgressIndicator());
                }),
              ),
              _CommentInputField(
                controller: _commentController,
                onSubmit: _addComment,
                profileImage: _userProfileImage,
              ),
            ],
          ),
        );
      },
    );
  }
}

// _CommentItem and _CommentInputField widgets are internal to this file
// They need to be modified to dispatch ReelsBloc events
class _CommentItem extends StatelessWidget {
  final CommentEntity comment;
  final String reelId;
  final String? currentUserId;

  const _CommentItem({
    required this.comment,
    required this.reelId,
    this.currentUserId,
  });

  void _deleteComment(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<ReelsBloc>().add(DeleteReelCommentEvent(
            commentId: comment.id,
            reelId: reelId,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (This widget's build method is identical to the one in your original comments_screen.dart)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.userProfileDetails.profileImage != null
                ? NetworkImage(comment.userProfileDetails.profileImage!)
                : null,
            child: comment.userProfileDetails.profileImage == null
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userProfileDetails.username,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      comment.created,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (currentUserId != null &&
                        comment.userProfileDetails.id == currentUserId) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _deleteComment(context),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _CommentInputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? profileImage;

  const _CommentInputField({
    required this.controller,
    required this.onSubmit,
    this.profileImage,
  });

  @override
  State<_CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<_CommentInputField> {
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateCanSubmit);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateCanSubmit);
    super.dispose();
  }

  void _updateCanSubmit() {
    if (mounted) {
      setState(() {
        _canSubmit = widget.controller.text.trim().isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (This widget's build method is identical to the one in your original comments_screen.dart)
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '🙌', '🔥', '😂', '😍', '😢'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    final currentText = widget.controller.text;
                    final selection = widget.controller.selection;
                    final newText = currentText.replaceRange(selection.start, selection.end, emoji);
                    widget.controller.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: selection.start + emoji.length),
                    );
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.profileImage != null
                      ? NetworkImage(widget.profileImage!)
                      : null,
                  child: widget.profileImage == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) {
                      if (_canSubmit) widget.onSubmit();
                    },
                  ),
                ),
                TextButton(
                  onPressed: _canSubmit ? widget.onSubmit : null,
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}