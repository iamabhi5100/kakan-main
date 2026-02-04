// Defining models for shareable users and groups
class ShareItem {
  final String type;
  final String? chatId;
  final String? lastMessageTime;
  final ShareData data;
  final String? name; // For groups

  ShareItem({
    required this.type,
    this.chatId,
    this.lastMessageTime,
    required this.data,
    this.name,
  });

  factory ShareItem.fromJson(Map<String, dynamic> json) {
    return ShareItem(
      type: json['type'] ?? '',
      chatId: json['chat_id'],
      lastMessageTime: json['last_message_time'],
      data: ShareData.fromJson(json['data']),
      name: json['name'],
    );
  }
}

class ShareData {
  final String id;
  final String username;
  final String name;
  final String? profileImage;
  final ParticipantsDetails? participantsDetails; // For groups

  ShareData({
    required this.id,
    required this.username,
    required this.name,
    this.profileImage,
    this.participantsDetails,
  });

  factory ShareData.fromJson(Map<String, dynamic> json) {
    return ShareData(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      profileImage: json['profile_image'],
      participantsDetails: json['participants_details'] != null
          ? ParticipantsDetails.fromJson(json['participants_details'])
          : null,
    );
  }
}

class ParticipantsDetails {
  final Participant sender;
  final List<Participant> receivers;

  ParticipantsDetails({
    required this.sender,
    required this.receivers,
  });

  factory ParticipantsDetails.fromJson(Map<String, dynamic> json) {
    return ParticipantsDetails(
      sender: Participant.fromJson(json['sender']),
      receivers: (json['receivers'] as List<dynamic>)
          .map((e) => Participant.fromJson(e))
          .toList(),
    );
  }
}

class Participant {
  final String id;
  final String username;
  final String name;
  final String? gender;
  final String? profileImage;

  Participant({
    required this.id,
    required this.username,
    required this.name,
    this.gender,
    this.profileImage,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'],
      profileImage: json['profile_image'],
    );
  }
}