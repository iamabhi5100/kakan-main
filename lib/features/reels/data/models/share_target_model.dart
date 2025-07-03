import 'package:kakan/features/reels/domain/entities/share_target_entity.dart';

class ShareTargetModel {
  final String type;
  final String? chatId;
  final String? lastMessageTime;
  final ShareTargetDataModel data;
  final String? groupName;

  ShareTargetModel({
    required this.type,
    this.chatId,
    this.lastMessageTime,
    required this.data,
    this.groupName,
  });

  factory ShareTargetModel.fromJson(Map<String, dynamic> json) {
    return ShareTargetModel(
      type: json['type'] as String,
      chatId: json['chat_id'] as String?,
      lastMessageTime: json['last_message_time'] as String?,
      data: ShareTargetDataModel.fromJson(json['data'] as Map<String, dynamic>),
      groupName: json['name'] as String?,
    );
  }

  ShareTargetEntity toEntity() {
    return ShareTargetEntity(
      type: type,
      chatId: chatId,
      lastMessageTime: lastMessageTime,
      groupName: groupName,
      data: data.toEntity(),
    );
  }
}

class ShareTargetDataModel {
  final String id;
  final String? username; // Changed to nullable
  final String? name; // Changed to nullable
  final String? profileImage;
  final List<ShareTargetParticipantModel>? participants;

  ShareTargetDataModel({
    required this.id,
    this.username,
    this.name,
    this.profileImage,
    this.participants,
  });

  factory ShareTargetDataModel.fromJson(Map<String, dynamic> json) {
    return ShareTargetDataModel(
      id: json['id'] as String,
      username: json['username'] as String?,
      name: json['name'] as String?,
      profileImage: json['profile_image'] as String?,
      participants: json['participants_details'] != null
          ? (json['participants_details']['receivers'] as List)
              .map((e) => ShareTargetParticipantModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  ShareTargetDataEntity toEntity() {
    return ShareTargetDataEntity(
      id: id,
      username: username ?? '',
      name: name ?? '',
      profileImage: profileImage,
      participants: participants?.map((p) => p.toEntity()).toList(),
    );
  }
}

class ShareTargetParticipantModel {
  final String id;
  final String? username; // Changed to nullable
  final String? name; // Changed to nullable
  final String? profileImage;

  ShareTargetParticipantModel({
    required this.id,
    this.username,
    this.name,
    this.profileImage,
  });

  factory ShareTargetParticipantModel.fromJson(Map<String, dynamic> json) {
    return ShareTargetParticipantModel(
      id: json['id'] as String,
      username: json['username'] as String?,
      name: json['name'] as String?,
      profileImage: json['profile_image'] as String?,
    );
  }

  ShareTargetParticipantEntity toEntity() {
    return ShareTargetParticipantEntity(
      id: id,
      username: username ?? '',
      name: name ?? '',
      profileImage: profileImage,
    );
  }
}