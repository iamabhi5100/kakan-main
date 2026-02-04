import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class GetMessageHistory implements UseCase<MessageHistoryResponse, String> {
  final ChatRepository repository;

  GetMessageHistory(this.repository);

  @override
  Future<Either<Failure, MessageHistoryResponse>> call(String chatId) async {
    return await repository.getMessageHistory(chatId);
  }
}