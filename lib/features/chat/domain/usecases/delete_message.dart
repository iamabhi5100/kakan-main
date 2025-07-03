import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class DeleteMessage implements UseCase<DeleteMessageResponse, String> {
  final ChatRepository repository;

  DeleteMessage(this.repository);

  @override
  Future<Either<Failure, DeleteMessageResponse>> call(String messageId) async {
    return await repository.deleteMessage(messageId);
  }
}