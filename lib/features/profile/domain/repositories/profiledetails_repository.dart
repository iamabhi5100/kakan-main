import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';

abstract class ProfiledetailsRepository {
  Future<Either<Failure, ProfiledetailsEntity>> getProfiledetails(String userId);
}