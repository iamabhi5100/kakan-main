// lib/core/models/otp_page_args.dart
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';

class OTPPageArgs {
  final String phone;
  final RemoteDataSource remoteDataSource;

  OTPPageArgs({
    required this.phone,
    required this.remoteDataSource,
  });
}