import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/login/domain/repositories/auth_repository.dart';

class RequestOtp {
  final AuthRepository repository;

  RequestOtp(this.repository);

  Future<Either<Failure, String>> call(String mobile) async {
    return await repository.requestOtp(mobile);
  }
}