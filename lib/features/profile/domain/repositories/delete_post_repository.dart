import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';

abstract class DeletePostRepository {
  Future<Either<Failure, void>> deletePost(String postId);
}