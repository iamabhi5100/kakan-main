import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';

/// ------------ DATE HELPERS ------------

DateTime? _tryParseWithPatterns(String raw) {
  // Try ISO first
  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {}

  // Common backend/UI formats we saw (e.g. "13/08/2025, 11:58 PM")
  const patterns = <String>[
    'dd/MM/yyyy, hh:mm a',
    'dd/MM/yyyy, HH:mm',
    'dd/MM/yyyy HH:mm',
    'dd-MM-yyyy HH:mm',
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
  ];

  for (final p in patterns) {
    try {
      return DateFormat(p).parseLoose(raw).toLocal();
    } catch (_) {}
  }
  return null;
}

String _formatDisplayDate(String raw) {
  final dt = _tryParseWithPatterns(raw);
  if (dt == null) return raw; // fallback if parsing fails
  // Required format: "10 Aug 2025, 12:01 PM"
  return DateFormat('d MMM yyyy, h:mm a').format(dt);
}

/// ------------ PUBLIC ENTRY ------------

void showCommentsBottomSheet(BuildContext context, {required String postId}) {
  if (kDebugMode) {
    print('CommentsScreen: Showing bottom sheet for post $postId');
  }
  final feedBloc = context.read<FeedBloc>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) => BlocProvider.value(
      value: feedBloc,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return CommentsScreen(scrollController: controller, postId: postId);
        },
      ),
    ),
  ).whenComplete(() {
    if (kDebugMode) {
      print('CommentsScreen: Bottom sheet closed for post $postId');
    }
  });
}

/// ------------ WIDGETS ------------

class CommentsScreen extends StatefulWidget {
  final ScrollController scrollController;
  final String postId;

  const CommentsScreen({
    super.key,
    required this.scrollController,
    required this.postId,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();

  /// IMPORTANT: Use **profile** id (not user id) for ownership checks.
  String? _currentProfileId;
  String? _userProfileImage;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('CommentsScreen: initState for post ${widget.postId}');
    }
    _loadCurrentUser();
    context.read<FeedBloc>().add(GetCommentsEvent(postId: widget.postId));
  }

  Future<void> _loadCurrentUser() async {
    final sessionManager = di.sl<SessionManager>();
    // ✅ Use profile id for comparing with `comment.userProfileId`
    final profileId = await sessionManager.getProfileId();
    final profileImage = await sessionManager.getProfileImage();
    if (mounted) {
      setState(() {
        _currentProfileId = profileId;
        _userProfileImage = profileImage ?? 'https://i.pravatar.cc/150?img=10';
      });
    }
  }

  void _addComment() {
    final content = _commentController.text.trim();
    if (content.isNotEmpty) {
      context.read<FeedBloc>().add(
            AddCommentEvent(postId: widget.postId, content: content),
          );
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('CommentsScreen: dispose called for post ${widget.postId}');
    }
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedBloc, FeedState>(
      listener: (context, state) {
        if (state is FeedActionSuccess && state.newPostId == null) {
          toastification.show(
            context: context,
            title: const Text('Comment action successful'),
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        } else if (state is FeedActionError) {
          toastification.show(
            context: context,
            title: Text(state.message),
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        } else if (state is CommentsError) {
          toastification.show(
            context: context,
            title: Text(state.message),
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
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
                    state is CommentsLoaded ? '${state.comments.length} Comments' : 'Comments',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state is CommentsLoaded) {
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
                            postId: widget.postId,
                            currentProfileId: _currentProfileId,
                          );
                        },
                      );
                    }

                    if (state is CommentsError) {
                      return Center(child: Text(state.message));
                    }

                    return const Center(child: CircularProgressIndicator());
                  },
                ),
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

class _CommentItem extends StatelessWidget {
  final CommentEntity comment;
  final String postId;

  /// We compare **profile ids** (comment.userProfileId vs currentProfileId).
  final String? currentProfileId;

  const _CommentItem({
    required this.comment,
    required this.postId,
    this.currentProfileId,
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
      context.read<FeedBloc>().add(
            DeleteCommentEvent(commentId: comment.id, postId: postId),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMine = currentProfileId != null &&
        (comment.userProfileId == currentProfileId ||
            comment.userProfileDetails.id == currentProfileId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.userProfileDetails.profileImage != null
                ? NetworkImage(comment.userProfileDetails.profileImage!)
                : const NetworkImage('https://i.pravatar.cc/150?img=10'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Text(
                      comment.userProfileDetails.username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // You could add a “• You” badge if you want
                    if (isMine)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Content
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                // const SizedBox(height: 8),
                // Time + Delete icon all in one row to ensure visibility
                Row(
                  children: [
                    Text(
                      _formatDisplayDate(comment.created),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    if (isMine)
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, size: 22, color: Colors.redAccent),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _deleteComment(context),
                      ),
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
    const emojis = ['❤️', '🙌', '🔥', '😂', '😍', '😢'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick emoji row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: emojis
                  .map((emoji) => GestureDetector(
                        onTap: () {
                          final t = widget.controller.text;
                          var i = widget.controller.selection.baseOffset;
                          if (i < 0) i = t.length;
                          final next = t.substring(0, i) + emoji + t.substring(i);
                          widget.controller.value = widget.controller.value.copyWith(
                            text: next,
                            selection:
                                TextSelection.collapsed(offset: i + emoji.length),
                          );
                        },
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8.0),
            // Input row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.profileImage != null
                      ? NetworkImage(widget.profileImage!)
                      : const NetworkImage('https://i.pravatar.cc/150?img=10'),
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
