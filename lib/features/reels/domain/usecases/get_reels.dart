import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';

class GetReels implements UseCase<Map<String, dynamic>, Params> {
  final ReelsRepository repository;

  GetReels(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(Params params) async {
    return await repository.getReels(nextUrl: params.nextUrl);
  }
}

class Params extends Equatable {
  final String? nextUrl;

  const Params({this.nextUrl});

  @override
  List<Object?> get props => [nextUrl];
}