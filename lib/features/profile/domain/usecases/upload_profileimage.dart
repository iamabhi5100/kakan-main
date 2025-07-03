import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/profile/domain/entities/profileimage_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profileimage_repository.dart';

class UploadProfileimage implements UseCase<ProfileimageEntity, UploadProfileimageParams> {
  final ProfileimageRepository repository;

  UploadProfileimage(this.repository);

  @override
  Future<Either<Failure, ProfileimageEntity>> call(UploadProfileimageParams params) async {
    return await repository.uploadProfileimage(params.userId, params.imagePath);
  }
}

class UploadProfileimageParams {
  final String userId;
  final String imagePath;

  UploadProfileimageParams({
    required this.userId,
    required this.imagePath,
  });
}