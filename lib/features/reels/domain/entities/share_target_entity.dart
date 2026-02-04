import 'package:equatable/equatable.dart';

class ShareTargetEntity extends Equatable {
  final String type;
  final String? chatId;
  final String? lastMessageTime;
  final ShareTargetDataEntity data;
  final String? groupName;

  const ShareTargetEntity({
    required this.type,
    this.chatId,
    this.lastMessageTime,
    required this.data,
    this.groupName,
  });

  @override
  List<Object?> get props => [type, chatId, lastMessageTime, data, groupName];
}

class ShareTargetDataEntity extends Equatable {
  final String id;
  final String username;
  final String name;
  final String? profileImage;
  final List<ShareTargetParticipantEntity>? participants;

  const ShareTargetDataEntity({
    required this.id,
    required this.username,
    required this.name,
    this.profileImage,
    this.participants,
  });

  @override
  List<Object?> get props => [id, username, name, profileImage, participants];
}

class ShareTargetParticipantEntity extends Equatable {
  final String id;
  final String username;
  final String name;
  final String? profileImage;

  const ShareTargetParticipantEntity({
    required this.id,
    required this.username,
    required this.name,
    this.profileImage,
  });

  @override
  List<Object?> get props => [id, username, name, profileImage];
}