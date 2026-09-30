abstract class BaseAuthStorage {
  Future<void> saveTokens(String accessToken, String refreshToken);
  Future<void> clearTokens();
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
}
