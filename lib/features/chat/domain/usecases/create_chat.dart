import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class CreateChat implements UseCase<CreateChatResponse, String> {
  final ChatRepository repository;

  CreateChat(this.repository);

  @override
  Future<Either<Failure, CreateChatResponse>> call(String userId) async {
    return await repository.createChat(userId);
  }
}