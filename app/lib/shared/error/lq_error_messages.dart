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
    'OUT_OF_RADIUS' =>
      failure.message.isNotEmpty
          ? failure.message
          : '아직 인증 반경 밖이에요. 조금 더 가까이 가 주세요.',
    'QUEST_EXPIRED' => '만료된 퀘스트예요. 오늘의 퀘스트를 다시 확인해 주세요.',
    'LOCATION_ACCURACY_TOO_LOW' => '위치 정확도가 낮아요. 잠시 후 다시 시도해 주세요.',
    'LOCATION_REQUIRED' => '위치 정보가 필요해요. 위치 권한과 GPS를 확인해 주세요.',
    'RESOURCE_NOT_FOUND' => '요청한 정보를 찾을 수 없어요.',
    // 화면이 `notReadyMessage`를 주면 이 문구까지 오지 않는다. 안 준 화면을 위한 기본값.
    'ENDPOINT_NOT_FOUND' => '아직 준비 중인 기능이에요.',
    'FORBIDDEN' => '권한이 없어요.',
    'VALIDATION_FAILED' || 'INVALID_REQUEST' =>
      failure.message.isNotEmpty ? failure.message : '입력값을 다시 확인해 주세요.',
    ApiException.networkError => '네트워크 연결을 확인해 주세요.',
    _ =>
      failure.message.isNotEmpty
          ? failure.message
          : '문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
  };
}

/// 서버에 아직 열리지 않은 엔드포인트인지 판별한다.
///
/// 컨트롤러가 없는 경로는 "리소스를 못 찾았다"가 아니라 "그 기능이 아직 없다"는
/// 뜻이다. 사용자에게는 재시도해도 소용없는 상태이므로 오류 화면 대신 준비 중
/// 안내를 보여줘야 한다.
///
/// 서버가 그 경우에만 붙이는 `ENDPOINT_NOT_FOUND`로 판정한다. `RESOURCE_NOT_FOUND`는
/// 엔드포인트가 살아 있고 특정 리소스만 없는 경우라 "다시 시도"가 의미를 가질 수 있어
/// 여기 포함하지 않는다.
///
/// 상태 코드가 아니라 코드로 보는 이유 — 백엔드의 포괄 예외 핸들러가 스프링의
/// `NoResourceFoundException`까지 삼켜 **500**으로 내보내던 때가 있었고, 그동안 이
/// 판정이 조용히 항상 거짓이라 준비 중 안내가 한 번도 뜨지 않았다. 상태 코드는
/// 중간 계층이 바꿔 놓기 쉽지만 코드는 서버가 의도해서 붙인 값이다.
bool isFeatureNotReady(Object error) =>
    ApiException.from(error).code == 'ENDPOINT_NOT_FOUND';
