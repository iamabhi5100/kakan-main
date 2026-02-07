abstract class LocalDataSource {
  Future<String> getCachedToken();
  Future<void> cacheToken(String token);
}

class LocalDataSourceImpl implements LocalDataSource {
  late String _cachedToken;

  @override
  Future<String> getCachedToken() async {
    return _cachedToken;
  }

  @override
  Future<void> cacheToken(String token) async {
    _cachedToken = token;
  }
}
