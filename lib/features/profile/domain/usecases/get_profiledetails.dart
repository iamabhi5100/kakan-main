import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profiledetails_repository.dart';

class GetProfiledetails implements UseCase<ProfiledetailsEntity, String> {
  final ProfiledetailsRepository repository;

  GetProfiledetails(this.repository);

  @override
  Future<Either<Failure, ProfiledetailsEntity>> call(String userId) async {
    return await repository.getProfiledetails(userId);
  }
}