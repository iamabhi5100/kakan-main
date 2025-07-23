import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/home/model/repositories/share_repository.dart';


class SendShareMessageParams {
  final String chatId;
  final String type; // 'user' or 'group'
  final String content;
  final String messageType;
  final String? mediaFileUrl;

  SendShareMessageParams({
    required this.chatId,
    required this.type,
    required this.content,
    required this.messageType,
    this.mediaFileUrl,
  });
}

class SendShareMessage implements UseCase<void, SendShareMessageParams> {
  final ShareRepository repository;

  SendShareMessage(this.repository);

  @override
  Future<Either<Failure, void>> call(SendShareMessageParams params) async {
    return await repository.sendMessage(
      chatId: params.chatId,
      type: params.type,
      content: params.content,
      messageType: params.messageType,
      mediaFileUrl: params.mediaFileUrl,
    );
  }
}