import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/profile/domain/repositories/delete_post_repository.dart';
// import 'package:kakan/features/postmyfeed/domain/repositories/delete_post_repository.dart';

class DeletePost implements UseCase<void, String> {
  final DeletePostRepository repository;

  DeletePost(this.repository);

  @override
  Future<Either<Failure, void>> call(String postId) async {
    return await repository.deletePost(postId);
  }
}