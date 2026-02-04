import 'package:flutter/material.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/network/models/user_details.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';

class ChatItem extends StatelessWidget {
  final FollowingUserModel user;
  final String lastMessage;
  final bool isGroup;
  final List<UserDetails> participants;
  final VoidCallback onTap;
  final VoidCallback? onDismissed;

  const ChatItem({
    super.key,
    required this.user,
    required this.lastMessage,
    required this.isGroup,
    required this.participants,
    required this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final String baseUrl = 'https://staging.api.kakan.co';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Dismissible(
        key: Key(user.id),
        direction: onDismissed != null ? DismissDirection.endToStart : DismissDirection.none,
        onDismissed: onDismissed != null ? (direction) => onDismissed!() : null,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12.0),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 30,
          ),
        ),
        child: Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12.0),
            leading: isGroup
                ? Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        child: const Icon(Icons.group, color: Colors.grey, size: 30),
                      ),
                      if (participants.isNotEmpty)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundImage: participants.first.profileImage != null
                                ? NetworkImage(
                                    participants.first.profileImage!.startsWith('http')
                                        ? participants.first.profileImage!
                                        : '$baseUrl${participants.first.profileImage}',
                                  ) as ImageProvider
                                : const AssetImage('assets/images/avatar1.png'),
                          ),
                        ),
                    ],
                  )
                : CircleAvatar(
                    radius: 28,
                    backgroundImage: user.followedToDetails.profileImage != null
                        ? NetworkImage(
                            user.followedToDetails.profileImage!.startsWith('http')
                                ? user.followedToDetails.profileImage!
                                : '$baseUrl${user.followedToDetails.profileImage}',
                          ) as ImageProvider
                        : const AssetImage('assets/images/avatar1.png'),
                    backgroundColor: Colors.grey[200],
                  ),
            title: Text(
              isGroup ? user.followedToDetails.name : user.followedToDetails.name,
              style: appTheme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            trailing: Text(
              user.created.split(',')[1].trim(),
              style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}