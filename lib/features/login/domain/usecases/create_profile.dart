import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/domain/repositories/auth_repository.dart';

class CreateProfileParams {
  final String token;
  final Map<String, dynamic> profileData;

  CreateProfileParams({required this.token, required this.profileData});
}

class CreateProfile {
  final AuthRepository repository;

  CreateProfile(this.repository);

  Future<Either<Failure, String>> call(CreateProfileParams params) async {
    return await repository.createProfile(params.token, params.profileData);
  }
}