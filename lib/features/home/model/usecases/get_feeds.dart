// lib/features/home/domain/usecases/get_feeds.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';

class GetFeeds implements UseCase<List<FeedEntity>, NoParams> {
  final FeedRepository repository;

  GetFeeds(this.repository);

  @override
  Future<Either<Failure, List<FeedEntity>>> call(NoParams params) async {
    return await repository.getFeeds();
  }
}