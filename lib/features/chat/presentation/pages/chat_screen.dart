// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:kakan/features/chat/presentation/widgets/video_player_widget.dart';
// import 'package:video_player/video_player.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:kakan/config/theme.dart';
// import 'package:kakan/core/utils/session_manager.dart';
// import 'package:kakan/features/chat/data/models/following_user_model.dart';
// import 'package:kakan/features/chat/data/models/chat_models.dart';
// import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_bloc.dart';
// import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_event.dart';
// import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_state.dart';
// import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
// import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
// import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
// import 'package:kakan/injection_container.dart' as di;
// import 'dart:developer' as developer;
// import 'dart:async';

// class ChatScreen extends StatefulWidget {
//   final String chatId;
//   final FollowingUserModel receiver;
//   final bool isGroup;
//   final String? groupName;

//   const ChatScreen({
//     Key? key,
//     required this.chatId,
//     required this.receiver,
//     required this.isGroup,
//     this.groupName,
//   }) : super(key: key);

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final ScrollController _scrollController = ScrollController();
//   final TextEditingController _textController = TextEditingController();
//   List<MessageModel> _messages = [];
//   String? _currentUserId;
//   final ImagePicker _picker = ImagePicker();
//   final String _baseUrl = 'https://kakan.backend.xade.in';
//   Timer? _pollingTimer;
//   bool _isFetchingMessages = false;

//   // Keys to pause all media
//   final List<GlobalKey<VideoPlayerWidgetState>> _videoKeys = [];
//   final List<GlobalKey<AudioPlayerWidgetState>> _audioKeys = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadCurrentUserId();
//     context.read<ChatBloc>().add(FetchMessageHistoryEvent(widget.chatId));
//     WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
//     // Start polling every 5 seconds
//     _startPolling();
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _textController.dispose();
//     _pollingTimer?.cancel(); // Cancel the polling timer to prevent memory leaks
//     super.dispose();
//   }

//   void _startPolling() {
//     _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//       if (!mounted || _isFetchingMessages) return; // Skip if widget is disposed or fetching
//       _isFetchingMessages = true;
//       try {
//         context.read<ChatBloc>().add(FetchMessageHistoryEvent(widget.chatId));
//       } catch (e) {
//         developer.log('Error during polling: $e');
//       } finally {
//         _isFetchingMessages = false;
//       }
//     });
//   }

//   Future<void> _loadCurrentUserId() async {
//     _currentUserId = await di.sl<SessionManager>().getUserId();
//     setState(() {});
//   }

//   void _scrollToBottom() {
//     if (_scrollController.hasClients) {
//       _scrollController.animateTo(
//         0.0,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     }
//   }

//   void _pauseAllMedia() {
//     for (var k in _videoKeys) k.currentState?.pause();
//     for (var k in _audioKeys) k.currentState?.pause();
//   }

//   void _sendMessage() {
//     final text = _textController.text.trim();
//     if (text.isEmpty) return;
//     final event = widget.isGroup
//         ? SendGroupMessageEvent(widget.chatId, text)
//         : SendMessageEvent(widget.chatId, text);
//     context.read<ChatBloc>().add(event);
//     _textController.clear();
//     _scrollToBottom();
//   }

//   void _showMediaTypeModal() {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (_) => Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: const Icon(Icons.photo, color: Colors.purple),
//               title: const Text('Photo'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _pickFromGallery('image');
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.video_library, color: Colors.blue),
//               title: const Text('Video'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showMediaSourceModal('video');
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.audiotrack, color: Colors.green),
//               title: const Text('Audio'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showMediaSourceModal('audio');
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showMediaSourceModal(String mediaType) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (_) => Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: Icon(
//                 mediaType == 'video' ? Icons.photo_library : Icons.library_music,
//                 size: 30,
//                 color: mediaType == 'video' ? Colors.blue : Colors.teal,
//               ),
//               title: const Text('From Gallery'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _pickFromGallery(mediaType);
//               },
//             ),
//             ListTile(
//               leading: Icon(
//                 mediaType == 'video' ? Icons.video_collection : Icons.headphones,
//                 size: 30,
//                 color: mediaType == 'video' ? Colors.pink : Colors.orange,
//               ),
//               title: const Text('From Library'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showLibraryModal(mediaType);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickFromGallery(String type) async {
//     try {
//       XFile? file;
//       if (type == 'image') {
//         file = await _picker.pickImage(source: ImageSource.gallery);
//       } else if (type == 'video') {
//         file = await _picker.pickVideo(source: ImageSource.gallery);
//       } else {
//         final res = await FilePicker.platform.pickFiles(type: FileType.audio);
//         if (res != null && res.files.single.path != null) {
//           file = XFile(res.files.single.path!);
//         }
//       }
//       if (file != null && mounted) {
//         final evt = widget.isGroup
//             ? SendMediaGroupMessageEvent(
//                 groupChatId: widget.chatId,
//                 content: '',
//                 mediaFilePath: file.path,
//                 messageType: type,
//               )
//             : SendMediaMessageEvent(
//                 chatId: widget.chatId,
//                 content: '',
//                 mediaFilePath: file.path,
//                 messageType: type,
//               );
//         context.read<ChatBloc>().add(evt);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error picking $type: $e')),
//         );
//       }
//     }
//   }

//   void _showLibraryModal(String mediaType) {
//     context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: mediaType));
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (_) => DraggableScrollableSheet(
//         initialChildSize: 0.8,
//         minChildSize: 0.4,
//         maxChildSize: 0.9,
//         expand: false,
//         builder: (__, controller) => Scaffold(
//           appBar: AppBar(
//             title: Text(
//               mediaType == 'video' ? 'Video Library' : 'Audio Library',
//               style: const TextStyle(color: Colors.black),
//             ),
//             backgroundColor: Colors.white,
//             elevation: 1,
//             leading: IconButton(
//               icon: const Icon(Icons.close, color: Colors.black),
//               onPressed: () => Navigator.pop(context),
//             ),
//           ),
//           body: BlocBuilder<DownloadsBloc, DownloadsState>(
//             builder: (ctx, state) {
//               if (state is DownloadsLoading) {
//                 return const Center(child: CircularProgressIndicator());
//               }
//               if (state is DownloadsError) {
//                 return Center(child: Text('Error: ${state.message}'));
//               }
//               if (state is DownloadsLoaded && state.downloads.isEmpty) {
//                 return Center(child: Text('No ${mediaType}s found'));
//               }
//               return ListView.builder(
//                 controller: controller,
//                 itemCount: (state as DownloadsLoaded).downloads.length,
//                 itemBuilder: (_, i) {
//                   final d = state.downloads[i];
//                   return ListTile(
//                     leading: mediaType == 'video' && d.thumbnail != null
//                         ? Image.network(
//                             d.thumbnail!.startsWith('http')
//                                 ? d.thumbnail!
//                                 : '$_baseUrl${d.thumbnail}',
//                             width: 60,
//                             fit: BoxFit.cover,
//                           )
//                         : const Icon(Icons.audiotrack, size: 40),
//                     title: Text(d.title ?? 'Untitled'),
//                     subtitle: Text(d.duration ?? ''),
//                     onTap: () {
//                       Navigator.pop(context);
//                       final evt = widget.isGroup
//                           ? SendMediaGroupMessageEvent(
//                               groupChatId: widget.chatId,
//                               content: '',
//                               mediaFilePath: d.mediaFile!,
//                               messageType: mediaType,
//                             )
//                           : SendMediaMessageEvent(
//                               chatId: widget.chatId,
//                               content: '',
//                               mediaFilePath: d.mediaFile!,
//                               messageType: mediaType,
//                             );
//                       context.read<ChatBloc>().add(evt);
//                     },
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBubble(MessageModel m, bool sent) {
//     final parts = m.timestamp.split(',');
//     final timeStr = parts.length > 1 ? parts[1].trim() : m.timestamp;
//     const r = Radius.circular(20);

//     final decoration = BoxDecoration(
//       color: sent ? const Color.fromRGBO(88, 86, 214, 0.2) : null,
//       gradient: sent
//           ? null
//           : const LinearGradient(
//               colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//       borderRadius: BorderRadius.only(
//         topLeft: r,
//         topRight: r,
//         bottomLeft: sent ? r : Radius.zero,
//         bottomRight: sent ? Radius.zero : r,
//       ),
//       boxShadow: [
//         BoxShadow(
//           color: sent ? Colors.black12 : Colors.grey.withOpacity(0.2),
//           blurRadius: 5,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     );

//     Widget content;
//     switch (m.messageType) {
//       case 'text':
//         content = Text(
//           m.content,
//           style: const TextStyle(color: Colors.black, fontSize: 16),
//         );
//         break;
//       case 'image':
//         final imageUrl = m.mediaFile!.startsWith('http')
//             ? m.mediaFile!
//             : '$_baseUrl${m.mediaFile}';
//         developer.log('Building image bubble with URL: $imageUrl');
//         content = ImagePreviewWidget(
//           imageUrl: imageUrl,
//           pauseAll: _pauseAllMedia,
//         );
//         break;
//       case 'video':
//         final videoUrl = m.mediaFile!.startsWith('http')
//             ? m.mediaFile!
//             : '$_baseUrl${m.mediaFile}';
//         developer.log('Building video bubble with URL: $videoUrl');
//         final key = GlobalKey<VideoPlayerWidgetState>();
//         _videoKeys.add(key);
//         content = VideoPlayerWidget(
//           key: key,
//           url: videoUrl,
//           pauseAll: _pauseAllMedia,
//           onKeyRemoved: (k) => _videoKeys.remove(k),
//         );
//         break;
//       case 'audio':
//         final audioUrl = m.mediaFile!.startsWith('http')
//             ? m.mediaFile!
//             : '$_baseUrl${m.mediaFile}';
//         developer.log('Building audio bubble with URL: $audioUrl');
//         final key = GlobalKey<AudioPlayerWidgetState>();
//         _audioKeys.add(key);
//         content = AudioPlayerWidget(
//           key: key,
//           url: audioUrl,
//           pauseAll: _pauseAllMedia,
//           onKeyRemoved: (k) => _audioKeys.remove(k),
//         );
//         break;
//       default:
//         content = const SizedBox.shrink();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         mainAxisAlignment: sent ? MainAxisAlignment.end : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           if (!sent)
//             CircleAvatar(
//               radius: 16,
//               backgroundImage: m.senderDetails.profileImage != null
//                   ? NetworkImage(
//                       m.senderDetails.profileImage!.startsWith('http')
//                           ? m.senderDetails.profileImage!
//                           : '$_baseUrl${m.senderDetails.profileImage}',
//                     )
//                   : const AssetImage('assets/images/avatar1.png') as ImageProvider,
//             ),
//           if (!sent) const SizedBox(width: 8),
//           Flexible(
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: decoration,
//               child: Column(
//                 crossAxisAlignment: sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//                 children: [
//                   content,
//                   const SizedBox(height: 6),
//                   Text(
//                     timeStr,
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: sent ? Colors.black54 : Colors.grey[600],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           if (sent) const SizedBox(width: 8),
//           if (sent)
//             CircleAvatar(
//               radius: 16,
//               backgroundImage: const AssetImage('assets/images/avatar1.png'),
//               backgroundColor: Colors.grey[300],
//             ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Row(
//           children: [
//             CircleAvatar(
//               radius: 20,
//               backgroundImage: widget.receiver.followedToDetails.profileImage != null
//                   ? NetworkImage(
//                       widget.receiver.followedToDetails.profileImage!.startsWith('http')
//                           ? widget.receiver.followedToDetails.profileImage!
//                           : '$_baseUrl${widget.receiver.followedToDetails.profileImage}',
//                     )
//                   : const AssetImage('assets/images/avatar1.png') as ImageProvider,
//             ),
//             const SizedBox(width: 12),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.isGroup
//                       ? (widget.groupName ?? 'Group Chat')
//                       : widget.receiver.followedToDetails.name,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 18,
//                     color: Colors.black,
//                   ),
//                 ),
//                 if (!widget.isGroup)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 4),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 8,
//                           height: 8,
//                           decoration: const BoxDecoration(
//                             color: Colors.green,
//                             shape: BoxShape.circle,
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         const Text(
//                           'Online',
//                           style: TextStyle(fontSize: 12, color: Colors.black38),
//                         ),
//                       ],
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//       body: BlocConsumer<ChatBloc, ChatState>(
//         listener: (ctx, st) {
//           if (st is ChatMessagesLoaded) {
//             // Only update if there are new messages
//             if (st.messages.length != _messages.length ||
//                 !st.messages.every((msg) => _messages.any((m) => m.id == msg.id))) {
//               setState(() {
//                 _messages = List.from(st.messages);
//               });
//               _scrollToBottom();
//             }
//           } else if (st is MessageSent) {
//             setState(() {
//               _messages.insert(0, st.message);
//             });
//             _scrollToBottom();
//           } else if (st is ChatError) {
//             ScaffoldMessenger.of(ctx).showSnackBar(
//               SnackBar(content: Text(st.message)),
//             );
//           }
//         },
//         builder: (ctx, st) => Column(
//           children: [
//             Expanded(
//               child: ListView.builder(
//                 controller: _scrollController,
//                 reverse: true,
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 itemCount: _messages.length,
//                 itemBuilder: (_, i) {
//                   final msg = _messages[i];
//                   final sent = _currentUserId != null && msg.sender == _currentUserId;
//                   return GestureDetector(
//                     onLongPress: sent
//                         ? () => showDialog(
//                               context: context,
//                               builder: (_) => AlertDialog(
//                                 title: const Text('Delete Message'),
//                                 content: const Text('Are you sure you want to delete this message?'),
//                                 actions: [
//                                   TextButton(
//                                     onPressed: () => Navigator.pop(context),
//                                     child: const Text('Cancel'),
//                                   ),
//                                   TextButton(
//                                     onPressed: () {
//                                       ctx.read<ChatBloc>().add(DeleteMessageEvent(msg.id));
//                                       Navigator.pop(context);
//                                     },
//                                     child: const Text('Delete'),
//                                   ),
//                                 ],
//                               ),
//                             )
//                         : null,
//                     child: _buildBubble(msg, sent),
//                   );
//                 },
//               ),
//             ),
//             SafeArea(
//               top: false,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: Row(
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.attach_file),
//                       color: appTheme.primaryColor,
//                       onPressed: _showMediaTypeModal,
//                     ),
//                     Expanded(
//                       child: TextField(
//                         controller: _textController,
//                         decoration: InputDecoration(
//                           hintText: 'Type a message...',
//                           filled: true,
//                           fillColor: Colors.white,
//                           contentPadding: const EdgeInsets.symmetric(horizontal: 16),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(30),
//                             borderSide: BorderSide.none,
//                           ),
//                         ),
//                         onSubmitted: (_) => _sendMessage(),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     CircleAvatar(
//                       backgroundColor: appTheme.primaryColor,
//                       child: IconButton(
//                         icon: const Icon(Icons.send, color: Colors.white),
//                         onPressed: _sendMessage,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class ImagePreviewWidget extends StatelessWidget {
//   final String imageUrl;
//   final VoidCallback pauseAll;

//   const ImagePreviewWidget({
//     Key? key,
//     required this.imageUrl,
//     required this.pauseAll,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         pauseAll();
//         showDialog(
//           context: context,
//           builder: (_) => Dialog(
//             backgroundColor: Colors.black,
//             insetPadding: EdgeInsets.zero,
//             child: Stack(
//               children: [
//                 Center(child: InteractiveViewer(child: Image.network(imageUrl))),
//                 Positioned(
//                   top: 40,
//                   left: 20,
//                   child: IconButton(
//                     icon: const Icon(Icons.close, color: Colors.white, size: 30),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(12),
//         child: Image.network(
//           imageUrl,
//           width: 150,
//           height: 100,
//           fit: BoxFit.cover,
//           errorBuilder: (_, __, ___) =>
//               const Icon(Icons.broken_image, size: 50, color: Colors.red),
//         ),
//       ),
//     );
//   }
// }

// class AudioPlayerWidget extends StatefulWidget {
//   final String url;
//   final VoidCallback pauseAll;
//   final Function(GlobalKey<AudioPlayerWidgetState>) onKeyRemoved;

//   const AudioPlayerWidget({
//     Key? key,
//     required this.url,
//     required this.pauseAll,
//     required this.onKeyRemoved,
//   }) : super(key: key);

//   @override
//   AudioPlayerWidgetState createState() => AudioPlayerWidgetState();
// }

// class AudioPlayerWidgetState extends State<AudioPlayerWidget> {
//   late AudioPlayer _player;
//   Duration _duration = Duration.zero;
//   Duration _position = Duration.zero;
//   bool _isMuted = false;

//   @override
//   void initState() {
//     super.initState();
//     _player = AudioPlayer();
//     _player.setUrl(widget.url).catchError((error) {
//       developer.log('Audio initialization failed: $error');
//     });
//     _player.durationStream.listen((d) {
//       if (mounted) setState(() => _duration = d ?? Duration.zero);
//     });
//     _player.positionStream.listen((p) {
//       if (mounted) setState(() => _position = p);
//     });
//   }

//   @override
//   void dispose() {
//     _player.dispose();
//     widget.onKeyRemoved(widget.key as GlobalKey<AudioPlayerWidgetState>);
//     super.dispose();
//   }

//   void play() {
//     widget.pauseAll();
//     _player.play();
//   }

//   void pause() => _player.pause();

//   void toggleMute() {
//     setState(() {
//       _isMuted = !_isMuted;
//       _player.setVolume(_isMuted ? 0 : 1);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 4),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(8),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               children: [
//                 StreamBuilder<PlayerState>(
//                   stream: _player.playerStateStream,
//                   builder: (ctx, snap) {
//                     final isPlaying = snap.data?.playing ?? false;
//                     return IconButton(
//                       icon: Icon(
//                         isPlaying ? Icons.pause : Icons.play_arrow,
//                         color: appTheme.primaryColor,
//                       ),
//                       onPressed: isPlaying ? pause : play,
//                     );
//                   },
//                 ),
//                 Expanded(
//                   child: Slider(
//                     value: _position.inSeconds.toDouble(),
//                     max: (_duration.inSeconds.toDouble() > 0
//                         ? _duration.inSeconds.toDouble()
//                         : 1.0),
//                     onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
//                   onPressed: toggleMute,
//                 ),
//               ],
//             ),
//             Text(
//               widget.url.split('/').last,
//               style: const TextStyle(fontSize: 12, color: Colors.black54),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class FullScreenVideoPage extends StatefulWidget {
//   final VideoPlayerController controller;

//   const FullScreenVideoPage({Key? key, required this.controller}) : super(key: key);

//   @override
//   State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
// }

// class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
//   @override
//   void initState() {
//     super.initState();
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//   }

//   @override
//   void dispose() {
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: widget.controller.value.isInitialized
//             ? FittedBox(
//                 fit: BoxFit.contain,
//                 child: SizedBox(
//                   width: widget.controller.value.size.width,
//                   height: widget.controller.value.size.height,
//                   child: VideoPlayer(widget.controller),
//                 ),
//               )
//             : const CircularProgressIndicator(),
//       ),
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: appTheme.primaryColor,
//         child: const Icon(Icons.close, color: Colors.white),
//         onPressed: () => Navigator.pop(context),
//       ),
//     );
//   }
// }


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kakan/features/chat/presentation/widgets/video_player_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_bloc.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_event.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_state.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
import 'package:kakan/injection_container.dart' as di;
import 'dart:developer' as developer;

class ChatScreen extends StatefulWidget {
  final String chatId;
  final FollowingUserModel receiver;
  final bool isGroup;
  final String? groupName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.receiver,
    required this.isGroup,
    this.groupName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  List<MessageModel> _messages = [];
  String? _currentUserId;
  final ImagePicker _picker = ImagePicker();
  final String _baseUrl = 'https://kakan.backend.xade.in';

  // Keys to pause all media
  final List<GlobalKey<VideoPlayerWidgetState>> _videoKeys = [];
  final List<GlobalKey<AudioPlayerWidgetState>> _audioKeys = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    context.read<ChatBloc>().add(FetchMessageHistoryEvent(widget.chatId));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = await di.sl<SessionManager>().getUserId();
    setState(() {});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _pauseAllMedia() {
    for (var k in _videoKeys) k.currentState?.pause();
    for (var k in _audioKeys) k.currentState?.pause();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final event = widget.isGroup
        ? SendGroupMessageEvent(widget.chatId, text)
        : SendMessageEvent(widget.chatId, text);
    context.read<ChatBloc>().add(event);
    _textController.clear();
    _scrollToBottom();
  }

  void _showMediaTypeModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.purple),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery('image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.blue),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _showMediaSourceModal('video');
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.green),
              title: const Text('Audio'),
              onTap: () {
                Navigator.pop(context);
                _showMediaSourceModal('audio');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaSourceModal(String mediaType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                mediaType == 'video' ? Icons.photo_library : Icons.library_music,
                size: 30,
                color: mediaType == 'video' ? Colors.blue : Colors.teal,
              ),
              title: const Text('From Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery(mediaType);
              },
            ),
            ListTile(
              leading: Icon(
                mediaType == 'video' ? Icons.video_collection : Icons.headphones,
                size: 30,
                color: mediaType == 'video' ? Colors.pink : Colors.orange,
              ),
              title: const Text('From Library'),
              onTap: () {
                Navigator.pop(context);
                _showLibraryModal(mediaType);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery(String type) async {
    try {
      XFile? file;
      if (type == 'image') {
        file = await _picker.pickImage(source: ImageSource.gallery);
      } else if (type == 'video') {
        file = await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        final res = await FilePicker.platform.pickFiles(type: FileType.audio);
        if (res != null && res.files.single.path != null) {
          file = XFile(res.files.single.path!);
        }
      }
      if (file != null && mounted) {
        final evt = widget.isGroup
            ? SendMediaGroupMessageEvent(
                groupChatId: widget.chatId,
                content: '',
                mediaFilePath: file.path,
                messageType: type,
              )
            : SendMediaMessageEvent(
                chatId: widget.chatId,
                content: '',
                mediaFilePath: file.path,
                messageType: type,
              );
        context.read<ChatBloc>().add(evt);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking $type: $e')),
        );
      }
    }
  }

  void _showLibraryModal(String mediaType) {
    context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: mediaType));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (__, controller) => Scaffold(
          appBar: AppBar(
            title: Text(
              mediaType == 'video' ? 'Video Library' : 'Audio Library',
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: BlocBuilder<DownloadsBloc, DownloadsState>(
            builder: (ctx, state) {
              if (state is DownloadsLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is DownloadsError) {
                return Center(child: Text('Error: ${state.message}'));
              }
              if (state is DownloadsLoaded && state.downloads.isEmpty) {
                return Center(child: Text('No ${mediaType}s found'));
              }
              return ListView.builder(
                controller: controller,
                itemCount: (state as DownloadsLoaded).downloads.length,
                itemBuilder: (_, i) {
                  final d = state.downloads[i];
                  return ListTile(
                    leading: mediaType == 'video' && d.thumbnail != null
                        ? Image.network(
                            d.thumbnail!.startsWith('http')
                                ? d.thumbnail!
                                : '$_baseUrl${d.thumbnail}',
                            width: 60,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.audiotrack, size: 40),
                    title: Text(d.title ?? 'Untitled'),
                    subtitle: Text(d.duration ?? ''),
                    onTap: () {
                      Navigator.pop(context);
                      final evt = widget.isGroup
                          ? SendMediaGroupMessageEvent(
                              groupChatId: widget.chatId,
                              content: '',
                              mediaFilePath: d.mediaFile!,
                              messageType: mediaType,
                            )
                          : SendMediaMessageEvent(
                              chatId: widget.chatId,
                              content: '',
                              mediaFilePath: d.mediaFile!,
                              messageType: mediaType,
                            );
                      context.read<ChatBloc>().add(evt);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(MessageModel m, bool sent) {
    final parts = m.timestamp.split(',');
    final timeStr = parts.length > 1 ? parts[1].trim() : m.timestamp;
    const r = Radius.circular(20);

    final decoration = BoxDecoration(
      color: sent ? const Color.fromRGBO(88, 86, 214, 0.2) : null,
      gradient: sent
          ? null
          : const LinearGradient(
              colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      borderRadius: BorderRadius.only(
        topLeft: r,
        topRight: r,
        bottomLeft: sent ? r : Radius.zero,
        bottomRight: sent ? Radius.zero : r,
      ),
      boxShadow: [
        BoxShadow(
          color: sent ? Colors.black12 : Colors.grey.withOpacity(0.2),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );

    Widget content;
    switch (m.messageType) {
      case 'text':
        content = Text(
          m.content,
          style: const TextStyle(color: Colors.black, fontSize: 16),
        );
        break;
      case 'image':
        final imageUrl = m.mediaFile!.startsWith('http')
            ? m.mediaFile!
            : '$_baseUrl${m.mediaFile}';
        developer.log('Building image bubble with URL: $imageUrl');
        content = ImagePreviewWidget(
          imageUrl: imageUrl,
          pauseAll: _pauseAllMedia,
        );
        break;
      case 'video':
        final videoUrl = m.mediaFile!.startsWith('http')
            ? m.mediaFile!
            : '$_baseUrl${m.mediaFile}';
        developer.log('Building video bubble with URL: $videoUrl');
        final key = GlobalKey<VideoPlayerWidgetState>();
        _videoKeys.add(key);
        content = VideoPlayerWidget(
          key: key,
          url: videoUrl,
          pauseAll: _pauseAllMedia,
          onKeyRemoved: (k) => _videoKeys.remove(k),
        );
        break;
      case 'audio':
        final audioUrl = m.mediaFile!.startsWith('http')
            ? m.mediaFile!
            : '$_baseUrl${m.mediaFile}';
        developer.log('Building audio bubble with URL: $audioUrl');
        final key = GlobalKey<AudioPlayerWidgetState>();
        _audioKeys.add(key);
        content = AudioPlayerWidget(
          key: key,
          url: audioUrl,
          pauseAll: _pauseAllMedia,
          onKeyRemoved: (k) => _audioKeys.remove(k),
        );
        break;
      default:
        content = const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: sent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!sent)
            CircleAvatar(
              radius: 16,
              backgroundImage: m.senderDetails.profileImage != null
                  ? NetworkImage(
                      m.senderDetails.profileImage!.startsWith('http')
                          ? m.senderDetails.profileImage!
                          : '$_baseUrl${m.senderDetails.profileImage}',
                    )
                  : const AssetImage('assets/images/avataruser.png') as ImageProvider,
            ),
          if (!sent) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: decoration,
              child: Column(
                crossAxisAlignment: sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: 6),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: sent ? Colors.black54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sent) const SizedBox(width: 8),
          if (sent)
            CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/images/avataruser.png'),
              backgroundColor: Colors.grey[300],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.receiver.followedToDetails.profileImage != null
                  ? NetworkImage(
                      widget.receiver.followedToDetails.profileImage!.startsWith('http')
                          ? widget.receiver.followedToDetails.profileImage!
                          : '$_baseUrl${widget.receiver.followedToDetails.profileImage}',
                    )
                  : const AssetImage('assets/images/avataruser.png') as ImageProvider,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isGroup
                      ? (widget.groupName ?? 'Group Chat')
                      : widget.receiver.followedToDetails.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                if (!widget.isGroup)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Online',
                          style: TextStyle(fontSize: 12, color: Colors.black38),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (ctx, st) {
          if (st is ChatMessagesLoaded) {
            // Only update if there are new messages
            if (st.messages.length != _messages.length ||
                !st.messages.every((msg) => _messages.any((m) => m.id == msg.id))) {
              setState(() {
                _messages = List.from(st.messages);
              });
              _scrollToBottom();
            }
          } else if (st is MessageSent) {
            setState(() {
              _messages.insert(0, st.message);
            });
            _scrollToBottom();
          } else if (st is ChatError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(st.message)),
            );
          }
        },
        builder: (ctx, st) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[i];
                  final sent = _currentUserId != null && msg.sender == _currentUserId;
                  return GestureDetector(
                    onLongPress: sent
                        ? () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete Message'),
                                content: const Text('Are you sure you want to delete this message?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ctx.read<ChatBloc>().add(DeleteMessageEvent(msg.id));
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            )
                        : null,
                    child: _buildBubble(msg, sent),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: appTheme.primaryColor,
                      onPressed: _showMediaTypeModal,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: appTheme.primaryColor,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImagePreviewWidget extends StatelessWidget {
  final String imageUrl;
  final VoidCallback pauseAll;

  const ImagePreviewWidget({
    Key? key,
    required this.imageUrl,
    required this.pauseAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        pauseAll();
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(child: InteractiveViewer(child: Image.network(imageUrl))),
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 150,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 50, color: Colors.red),
        ),
      ),
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final VoidCallback pauseAll;
  final Function(GlobalKey<AudioPlayerWidgetState>) onKeyRemoved;

  const AudioPlayerWidget({
    Key? key,
    required this.url,
    required this.pauseAll,
    required this.onKeyRemoved,
  }) : super(key: key);

  @override
  AudioPlayerWidgetState createState() => AudioPlayerWidgetState();
}

class AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setUrl(widget.url).catchError((error) {
      developer.log('Audio initialization failed: $error');
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    widget.onKeyRemoved(widget.key as GlobalKey<AudioPlayerWidgetState>);
    super.dispose();
  }

  void play() {
    widget.pauseAll();
    _player.play();
  }

  void pause() => _player.pause();

  void toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _player.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (ctx, snap) {
                    final isPlaying = snap.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: appTheme.primaryColor,
                      ),
                      onPressed: isPlaying ? pause : play,
                    );
                  },
                ),
                Expanded(
                  child: Slider(
                    value: _position.inSeconds.toDouble(),
                    max: (_duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0),
                    onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                IconButton(
                  icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                  onPressed: toggleMute,
                ),
              ],
            ),
            Text(
              widget.url.split('/').last,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;

  const FullScreenVideoPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: widget.controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: widget.controller.value.size.width,
                  height: widget.controller.value.size.height,
                  child: VideoPlayer(widget.controller),
                ),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appTheme.primaryColor,
        child: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}