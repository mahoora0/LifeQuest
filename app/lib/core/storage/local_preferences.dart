import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기기별 상태 저장소.
///
/// 계정을 따라다닐 값이 아닌 것만 여기 둔다 — 위치 권한 안내를 미룬 날짜, 알림 토글처럼
/// 기기마다 달라야 하는 값이다. 사용자 데이터는 서버가 정본이다.
///
/// 테스트에서는 `SharedPreferences.setMockInitialValues({})` 로 대체한다.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});
