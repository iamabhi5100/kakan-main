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

  factory ShareTargetModel.fromJsonSafe(Map<String, dynamic> json) {
    return ShareTargetModel(
      type: (json['type'] ?? '').toString(),
      chatId: json['chat_id']?.toString(),
      lastMessageTime: json['last_message_time']?.toString(),
      data: ShareTargetDataModel.fromJsonSafe(
        (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      groupName: json['name']?.toString(),
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
  final String? username;
  final String? name;
  final String? profileImage;
  final List<ShareTargetParticipantModel>? participants;

  ShareTargetDataModel({
    required this.id,
    this.username,
    this.name,
    this.profileImage,
    this.participants,
  });

  factory ShareTargetDataModel.fromJsonSafe(Map<String, dynamic> json) {
    final participantsRoot = (json['participants_details'] as Map?)?.cast<String, dynamic>();
    final receivers = (participantsRoot?['receivers'] as List?) ?? const [];
    return ShareTargetDataModel(
      id: (json['id'] ?? '').toString(),
      username: json['username']?.toString(),
      name: json['name']?.toString(),
      profileImage: json['profile_image']?.toString(),
      participants: receivers
          .whereType<Map<String, dynamic>>()
          .map(ShareTargetParticipantModel.fromJsonSafe)
          .toList(),
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
  final String? username;
  final String? name;
  final String? profileImage;

  ShareTargetParticipantModel({
    required this.id,
    this.username,
    this.name,
    this.profileImage,
  });

  factory ShareTargetParticipantModel.fromJsonSafe(Map<String, dynamic> json) {
    return ShareTargetParticipantModel(
      id: (json['id'] ?? '').toString(),
      username: json['username']?.toString(),
      name: json['name']?.toString(),
      profileImage: json['profile_image']?.toString(),
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
