// File: lib/features/profile/domain/usecases/update_profile.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/profile/domain/entities/profile.dart';
import 'package:kakan/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfile implements UseCase<Profile, UpdateProfileParams> {
  final ProfileRepository repository;

  UpdateProfile(this.repository);

  @override
  Future<Either<Failure, Profile>> call(UpdateProfileParams params) async {
    return await repository.updateProfile(params.userId, params.data);
  }
}

class UpdateProfileParams {
  final String userId;
  final Map<String, dynamic> data;

  UpdateProfileParams({required this.userId, required this.data});
}