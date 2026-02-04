import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profile_submit_repository.dart';

class SubmitProfile implements UseCase<ProfiledetailsEntity, SubmitProfileParams> {
  final ProfileSubmitRepository repository;

  SubmitProfile(this.repository);

  @override
  Future<Either<Failure, ProfiledetailsEntity>> call(SubmitProfileParams params) async {
    return await repository.submitProfile(params.userId, params.data);
  }
}

class SubmitProfileParams {
  final String userId;
  final Map<String, dynamic> data;

  SubmitProfileParams({required this.userId, required this.data});
}