import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class SendMessage implements UseCase<MessageModel, SendMessageParams> {
  final ChatRepository repository;

  SendMessage(this.repository);

  @override
  Future<Either<Failure, MessageModel>> call(SendMessageParams params) async {
    return await repository.sendMessage(params.chatId, params.content, params.mediaFilePath, params.messageType);
  }
}

class SendMessageParams {
  final String chatId;
  final String content;
  final String? mediaFilePath;
  final String? messageType;

  SendMessageParams({
    required this.chatId,
    required this.content,
    this.mediaFilePath,
    this.messageType,
  });
}