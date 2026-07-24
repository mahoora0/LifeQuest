import 'package:life_quest/core/network/api_exception.dart';

/// 에러 코드 → 사용자 문구 매핑.
///
/// 화면은 서버 원문 대신 항상 이 함수를 거친 문구를 보여준다.
String lqErrorMessage(Object error) {
  final failure = ApiException.from(error);

  return switch (failure.code) {
    'TOKEN_EXPIRED' || 'UNAUTHORIZED' => '로그인이 만료됐어요. 다시 로그인해 주세요.',
    'INVALID_CREDENTIALS' => '이메일 또는 비밀번호가 올바르지 않아요.',
    'DUPLICATE_EMAIL' => '이미 가입된 이메일이에요.',
    'DUPLICATE_NICKNAME' => '이미 사용 중인 닉네임이에요.',
    'INVALID_GOOGLE_TOKEN' => 'Google 인증 정보를 확인하지 못했어요.',
    'AUTH_PROVIDER_NOT_CONFIGURED' => 'Google 로그인이 아직 설정되지 않았어요.',
    'GOOGLE_SIGN_IN_CANCELED' => 'Google 로그인이 취소되었어요.',
    'OUT_OF_RADIUS' => failure.message.isNotEmpty
        ? failure.message
        : '아직 인증 반경 밖이에요. 조금 더 가까이 가 주세요.',
    'QUEST_EXPIRED' => '만료된 퀘스트예요. 오늘의 퀘스트를 다시 확인해 주세요.',
    'LOCATION_ACCURACY_TOO_LOW' => '위치 정확도가 낮아요. 잠시 후 다시 시도해 주세요.',
    'LOCATION_REQUIRED' => '위치 정보가 필요해요. 위치 권한과 GPS를 확인해 주세요.',
    'RESOURCE_NOT_FOUND' => '요청한 정보를 찾을 수 없어요.',
    'FORBIDDEN' => '권한이 없어요.',
    'VALIDATION_FAILED' || 'INVALID_REQUEST' => failure.message.isNotEmpty
        ? failure.message
        : '입력값을 다시 확인해 주세요.',
    ApiException.networkError => '네트워크 연결을 확인해 주세요.',
    _ => failure.message.isNotEmpty
        ? failure.message
        : '문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
  };
}
