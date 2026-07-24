import 'package:google_sign_in/google_sign_in.dart';
import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/core/network/api_exception.dart';

class GoogleAuthService {
  GoogleAuthService();

  Future<void>? _initialization;

  Future<String> getIdToken() async {
    if (AppConfig.googleServerClientId.isEmpty) {
      throw const ApiException(
        code: 'AUTH_PROVIDER_NOT_CONFIGURED',
        message: 'Google 클라이언트 ID가 설정되지 않았어요.',
      );
    }

    await (_initialization ??= GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
      serverClientId: AppConfig.googleServerClientId,
    ));

    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const ApiException(
          code: 'GOOGLE_SIGN_IN_UNSUPPORTED',
          message: '이 환경에서는 Google 로그인을 사용할 수 없어요.',
        );
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          code: 'INVALID_GOOGLE_TOKEN',
          message: 'Google 인증 토큰을 받지 못했어요.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const ApiException(
          code: 'GOOGLE_SIGN_IN_CANCELED',
          message: 'Google 로그인이 취소되었어요.',
        );
      }
      throw ApiException(
        code: 'GOOGLE_SIGN_IN_FAILED',
        message: error.description ?? 'Google 로그인에 실패했어요.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // 앱 세션 로그아웃은 Google SDK 상태와 무관하게 계속한다.
    }
  }
}
