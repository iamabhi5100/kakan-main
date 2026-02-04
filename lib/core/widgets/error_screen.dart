// lib/core/widgets/error_screen.dart
import 'package:flutter/material.dart';
import 'package:kakan/core/error/app_error.dart';
// If you use a global appTheme (you referenced it elsewhere), import it:
import 'package:kakan/config/theme.dart';

class ErrorScreen extends StatelessWidget {
  final AppErrorType type;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    required this.type,
    required this.onRetry,
  });

  String _title() {
    switch (type) {
      case AppErrorType.noInternet:      return "No Internet Connection";
      case AppErrorType.serverTimeout:   return "Request Timed Out";
      case AppErrorType.serverMaintenance:return "Server Maintenance";
      case AppErrorType.forbidden:       return "Access Denied";
      case AppErrorType.tooManyRequests: return "Too Many Requests";
      case AppErrorType.unauthorized:    return "Session Expired";
      case AppErrorType.notFound:        return "Not Found";
      case AppErrorType.badRequest:      return "Invalid Request";
      case AppErrorType.payloadTooLarge: return "File Too Large";
      case AppErrorType.unknown:         return "Something Went Wrong";
    }
  }

  String _subtitle() {
    switch (type) {
      case AppErrorType.noInternet:
        return "Your phone is not connected to the internet. Please check Wi-Fi or mobile data and try again.";
      case AppErrorType.serverTimeout:
        return "The server is taking too long to respond. Please try again.";
      case AppErrorType.serverMaintenance:
        return "Our servers are under maintenance. Please check back later.";
      case AppErrorType.forbidden:
        return "You don’t have permission to access this.";
      case AppErrorType.tooManyRequests:
        return "You’ve made too many requests. Please wait a bit.";
      case AppErrorType.unauthorized:
        return "Your session may have expired. Please log in again.";
      case AppErrorType.notFound:
        return "The content you’re looking for isn’t available.";
      case AppErrorType.badRequest:
        return "Some details look invalid. Please review and retry.";
      case AppErrorType.payloadTooLarge:
        return "The uploaded file is too big. Try a smaller one.";
      case AppErrorType.unknown:
        return "An unexpected error occurred. Please try again later.";
    }
  }

  String _imageAsset() {
    switch (type) {
      case AppErrorType.noInternet:       return "assets/images/no_internet.png";
      case AppErrorType.serverTimeout:
      case AppErrorType.serverMaintenance:return "assets/images/server_maintenance.png";
      case AppErrorType.forbidden:        return "assets/images/forbidden.png";
      case AppErrorType.tooManyRequests:  return "assets/images/too_many.png";
      case AppErrorType.unauthorized:     return "assets/images/lock.png";
      case AppErrorType.notFound:         return "assets/images/not_found.png";
      case AppErrorType.badRequest:       return "assets/images/warn.png";
      case AppErrorType.payloadTooLarge:  return "assets/images/too_large.png";
      case AppErrorType.unknown:          return "assets/images/error.png";
    }
  }

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 48;
    // Use your global appTheme primary color; if you don't have it, fallback to Theme.
    final Color primary = appTheme.primaryColor; // or: Theme.of(context).colorScheme.primary

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(_imageAsset(), height: 180, fit: BoxFit.contain),
              const SizedBox(height: 24),
              Text(
                _title(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // -------- Custom outlined white button with InkWell ripple --------
              Material(
                color: Colors.transparent,
                child: Ink(
                  width: double.infinity,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: primary, width: 1),
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    onTap: onRetry,
                    child: Center(
                      child: Text(
                        "Retry",
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // -------------------------------------------------------------------
            ],
          ),
        ),
      ),
    );
  }
}
