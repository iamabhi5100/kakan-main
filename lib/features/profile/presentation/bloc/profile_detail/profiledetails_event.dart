abstract class ProfiledetailsEvent {}

class GetProfiledetailsEvent extends ProfiledetailsEvent {
  final String userId;

  GetProfiledetailsEvent({required this.userId});
}