import 'package:dartz/dartz.dart';

class InputConverter {
  Either<String, int> stringToUnsignedInteger(String str) {
    try {
      final integer = int.parse(str);
      if (integer < 0) throw FormatException();
      return Right(integer);
    } on FormatException {
      return Left('Invalid number');
    }
  }
}
