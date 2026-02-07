// import 'package:dartz/dartz.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:kakan/core/error/failures.dart';
// import 'package:kakan/features/login/domain/repositories/auth_repository.dart';
// import 'package:kakan/features/login/domain/usecases/request_otp.dart';
// import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';

// import 'request_otp_test.mocks.dart';

// @GenerateMocks([AuthRepository])
// void main() {
//   late RequestOtp usecase;
//   late MockAuthRepository mockAuthRepository;

//   setUp(() {
//     mockAuthRepository = MockAuthRepository();
//     usecase = RequestOtp(mockAuthRepository);
//   });

//   const tMobile = '1234567890';
//   const tResponse = 'OTP sent successfully';

//   test('should return success message when OTP request is successful', () async {
//     // Arrange
//     when(mockAuthRepository.requestOtp(tMobile))
//         .thenAnswer((_) async => Right(tResponse));

//     // Act
//     final result = await usecase(tMobile);

//     // Assert
//     expect(result, Right(tResponse));
//     verify(mockAuthRepository.requestOtp(tMobile));
//     verifyNoMoreInteractions(mockAuthRepository);
//   });

//   test('should return ServerFailure when OTP request fails', () async {
//     // Arrange
//     when(mockAuthRepository.requestOtp(tMobile))
//         .thenAnswer((_) async => Left(ServerFailure()));

//     // Act
//     final result = await usecase(tMobile);

//     // Assert
//     expect(result, Left(ServerFailure()));
//     verify(mockAuthRepository.requestOtp(tMobile));
//     verifyNoMoreInteractions(mockAuthRepository);
//   });
// }