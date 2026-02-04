import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';

class GetFeeds implements UseCase<Map<String, dynamic>, FeedParams> {
  final FeedRepository repository;
  GetFeeds(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(FeedParams params) async {
    return repository.getFeeds(nextUrl: params.nextUrl);
  }
}

class FeedParams extends Equatable {
  final String? nextUrl;
  const FeedParams({this.nextUrl});

  @override
  List<Object?> get props => [nextUrl];
}
