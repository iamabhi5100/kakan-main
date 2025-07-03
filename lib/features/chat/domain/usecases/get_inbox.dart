import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class GetInbox implements UseCase<InboxResponse, NoParams> {
  final ChatRepository repository;

  GetInbox(this.repository);

  @override
  Future<Either<Failure, InboxResponse>> call(NoParams params) async {
    return await repository.getInbox();
  }
}