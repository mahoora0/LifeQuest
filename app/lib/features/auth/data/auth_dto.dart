import 'package:life_quest/shared/data/json_reader.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthTokens.fromJson(Object? body) {
    final json = asMap(body);
    return AuthTokens(
      accessToken: asString(json['accessToken']) ?? '',
      refreshToken: asString(json['refreshToken']) ?? '',
      expiresIn: asInt(json['expiresIn']) ?? 0,
    );
  }
}
