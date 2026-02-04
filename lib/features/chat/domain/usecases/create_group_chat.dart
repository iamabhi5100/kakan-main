// lib/features/chat/domain/usecases/create_group_chat.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class CreateGroupChat implements UseCase<CreateGroupChatResponse, CreateGroupChatParams> {
  final ChatRepository repository;

  CreateGroupChat(this.repository);

  @override
  Future<Either<Failure, CreateGroupChatResponse>> call(CreateGroupChatParams params) async {
    return await repository.createGroupChat(params.participantIds, params.name);
  }
}

class CreateGroupChatParams {
  final List<String> participantIds;
  final String name;

  CreateGroupChatParams({required this.participantIds, required this.name});
}