abstract class ProfileSubmitEvent {}

class SubmitProfileEvent extends ProfileSubmitEvent {
  final String userId;
  final Map<String, dynamic> data;

  SubmitProfileEvent({required this.userId, required this.data});
}