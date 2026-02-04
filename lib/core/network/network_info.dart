// lib/core/network/network_info.dart
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Works with connectivity_plus v6+: checkConnectivity() may return either a
/// single ConnectivityResult (older) or a List<ConnectivityResult> (newer).
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;
  NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    final dynamic result = await connectivity.checkConnectivity();

    // v6 style: List<ConnectivityResult>
    if (result is List<ConnectivityResult>) {
      if (result.isEmpty) return false;
      return result.any((r) => r != ConnectivityResult.none);
    }

    // older style: single ConnectivityResult
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    // Fallback (unexpected)
    return false;
  }
}
