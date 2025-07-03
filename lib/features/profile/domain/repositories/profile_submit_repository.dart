import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';

abstract class ProfileSubmitRepository {
  Future<Either<Failure, ProfiledetailsEntity>> submitProfile(String userId, Map<String, dynamic> data);
}