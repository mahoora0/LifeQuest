import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/auth/data/auth_dto.dart';

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  }) => _guard(() async {
    await _dio.post<dynamic>(
      '/auth/signup',
      data: {'email': email, 'password': password, 'nickname': nickname},
    );
  });

  Future<AuthTokens> login({required String email, required String password}) =>
      _guard(() async {
        final response = await _dio.post<dynamic>(
          '/auth/login',
          data: {'email': email, 'password': password},
        );
        return AuthTokens.fromJson(response.data);
      });

  Future<AuthTokens> googleLogin(String idToken) => _guard(() async {
    final response = await _dio.post<dynamic>(
      '/auth/google',
      data: {'idToken': idToken},
    );
    return AuthTokens.fromJson(response.data);
  });

  Future<void> logout(String refreshToken) => _guard(() async {
    await _dio.post<dynamic>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
