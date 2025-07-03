import 'package:kakan/features/postmyfeed/domain/entities/post_entity.dart';

abstract class PostState {}

class PostInitial extends PostState {}

class PostLoading extends PostState {}

class PostCreated extends PostState {
  final PostEntity post;

  PostCreated(this.post);
}

class PostError extends PostState {
  final String message;

  PostError(this.message);
}