import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class DeleteGroupChat implements UseCase<DeleteGroupChatResponse, String> {
  final ChatRepository repository;

  DeleteGroupChat(this.repository);

  @override
  Future<Either<Failure, DeleteGroupChatResponse>> call(String groupChatId) async {
    return await repository.deleteGroupChat(groupChatId);
  }
}