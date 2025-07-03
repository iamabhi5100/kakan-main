// lib/features/home/domain/repositories/feed_repository.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';

abstract class FeedRepository {
  Future<Either<Failure, List<FeedEntity>>> getFeeds();
}