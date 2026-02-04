import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/profile/domain/entities/profileimage_entity.dart';

abstract class ProfileimageRepository {
  Future<Either<Failure, ProfileimageEntity>> uploadProfileimage(
    String userId,
    String imagePath,
  );
}