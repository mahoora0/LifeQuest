import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/auth/data/auth_dto.dart';
import 'package:life_quest/features/auth/data/auth_repository.dart';
import 'package:life_quest/features/auth/data/google_auth_service.dart';

enum AuthSession { authenticated, unauthenticated }

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

/// 별도 provider로 분리해 앱 시작 인증 복원을 위젯 테스트에서 대체할 수 있게 한다.
final storedAuthSessionProvider = FutureProvider<AuthSession>((ref) async {
  final storage = ref.watch(tokenStorageProvider);
  try {
    final tokens = await Future.wait([
      storage.readAccessToken(),
      storage.readRefreshToken(),
    ]);
    return tokens.any((token) => token != null && token.isNotEmpty)
        ? AuthSession.authenticated
        : AuthSession.unauthenticated;
  } catch (_) {
    return AuthSession.unauthenticated;
  }
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession> {
  @override
  Future<AuthSession> build() {
    ref.listen(sessionInvalidationProvider, (previous, invalidated) {
      if (invalidated) {
        state = const AsyncData(AuthSession.unauthenticated);
      }
    });
    return ref.watch(storedAuthSessionProvider.future);
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await ref
        .read(authRepositoryProvider)
        .login(email: email.trim(), password: password);
    await _save(tokens);
  }

  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.signup(
      email: email.trim(),
      password: password,
      nickname: nickname.trim(),
    );
    final tokens = await repository.login(
      email: email.trim(),
      password: password,
    );
    await _save(tokens);
  }

  Future<void> loginWithGoogle() async {
    final idToken = await ref.read(googleAuthServiceProvider).getIdToken();
    final tokens = await ref.read(authRepositoryProvider).googleLogin(idToken);
    await _save(tokens);
  }

  Future<void> logout() async {
    final storage = ref.read(tokenStorageProvider);
    try {
      final refreshToken = await storage.readRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await ref.read(authRepositoryProvider).logout(refreshToken);
      }
    } catch (_) {
      // 서버 로그아웃 실패 시에도 로컬 세션은 반드시 종료한다.
    }
    await ref.read(googleAuthServiceProvider).signOut();
    await storage.clear();
    ref.read(sessionInvalidationProvider.notifier).reset();
    state = const AsyncData(AuthSession.unauthenticated);
  }

  Future<void> _save(AuthTokens tokens) async {
    if (tokens.accessToken.isEmpty || tokens.refreshToken.isEmpty) {
      throw StateError('서버에서 인증 토큰을 받지 못했습니다.');
    }
    await ref
        .read(tokenStorageProvider)
        .writeTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
    ref.read(sessionInvalidationProvider.notifier).reset();
    state = const AsyncData(AuthSession.authenticated);
  }
}
