import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class SendGroupMessage implements UseCase<MessageModel, SendGroupMessageParams> {
  final ChatRepository repository;

  SendGroupMessage(this.repository);

  @override
  Future<Either<Failure, MessageModel>> call(SendGroupMessageParams params) async {
    return await repository.sendGroupMessage(params.groupChatId, params.content, params.mediaFilePath, params.messageType);
  }
}

class SendGroupMessageParams {
  final String groupChatId;
  final String content;
  final String? mediaFilePath;
  final String? messageType;

  SendGroupMessageParams({
    required this.groupChatId,
    required this.content,
    this.mediaFilePath,
    this.messageType,
  });
}