class ConstantApi {
  static const String baseUrl = 'https://kakan.backend.xade.in';
  static const String apiVersion = '1';

  // Login Feature
  static const String getOtp = '/v$apiVersion/user/auth/get-otp/';
  static const String verifyOtp = '/v$apiVersion/user/auth/verify/';
  static const String refreshToken = '/v$apiVersion/user/auth/refresh/';
  static const String userProfile = '/v$apiVersion/user/{{user_id}}/';

  // FollowSuggestions Feature
  static const String followSuggestions = '/v$apiVersion/user/';
  static const String followUser = '/v$apiVersion/user/%s/follow/';
  static const String unfollowUser = '/v$apiVersion/user/%s/unfollow/';

  // Post Feature
  static const String createPost = '/v$apiVersion/posts/';

  // Profile Image Feature
  static const String uploadProfileimage = '/v$apiVersion/user/%s/upload-profile-picture/';

  // Profile Submit Feature
  static const String submitProfile = '/v$apiVersion/user/%s/update-profile/';

  // Chat Feature
  static const String getFollowingUsers = '/v$apiVersion/user/%s/following/';
  static const String createChat = '/v$apiVersion/chat/individual/get_chat_id/';
  static const String sendMessage = '/v$apiVersion/chat/individual/%s/send/';
  static const String getInbox = '/v$apiVersion/chat/individual/inbox/';
  static const String getMessageHistory = '/v$apiVersion/chat/individual/%s/messages/';
  static const String deleteMessage = '/v$apiVersion/chat/messages/%s/delete/';

  // Group Chat Feature
  static const String createGroupChat = '/v$apiVersion/chat/group/get_chat_id/';
  static const String sendGroupMessage = '/v$apiVersion/chat/group/%s/send/';
  static const String deleteGroupChat = '/v$apiVersion/chat/group/%s/delete-chat/';

  // Downloads Feature
  static const String downloads = '/v$apiVersion/downloads/';
  static const String deleteDownload = '/v$apiVersion/downloads/%s/';

  // Search Feature
  static const String searchUsers = '/v$apiVersion/user/?search=%s';
  static const String searchPosts = '/v$apiVersion/posts/?search=%s';
}