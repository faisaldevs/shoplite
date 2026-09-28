abstract class BaseAuthStorage {
  Future<void> saveTokens(String accessToken, String refreshToken);
  Future<void> clearTokens(String accessToken, String refreshToken);
  Future<String?> getAccessToken(String accessToken);
  Future<String?> getRefreshToken(String refreshToken);
}
