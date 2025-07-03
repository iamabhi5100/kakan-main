// lib/core/error/failures.dart
import 'package:kakan/core/error/exceptions.dart';

abstract class Failure {}

class ServerFailure extends Failure {
  final ServerException? exception;

  ServerFailure({this.exception});
}

class CacheFailure extends Failure {}