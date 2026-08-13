import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/core/network/provider_retry.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';

import '../support/stub_location_service.dart';

/// 지도의 주변 퀘스트 조회가 **어느 경로로 위치를 얻는지** 고정한다.
///
/// 재는 것이 좌표값이 아니라 호출 경로인 이유는, 이 화면이 죽던 방식이 그랬기 때문이다.
/// `getCurrentPosition()`은 새 fix를 요청하고, geolocator는 조회를 끝낸 뒤 NMEA 리스너를
/// 해제하는데 그 해제가 **메인 스레드 동기 binder 호출**이다. 시스템이 늦게 응답하면
/// 15초를 넘겨 ANR(`Input dispatching timed out`)이 나고, 이때 **Dart 예외는 한 건도
/// 없다** — 앱 로그만 보면 원인이 보이지 않는다.
///
/// `getLastKnownPosition()`은 새 fix를 잡지 않아 그 경로를 타지 않는다. 그래서 여기서
/// 지켜야 할 계약은 "좌표가 맞는가"가 아니라 **"캐시가 있으면 새 fix를 부르지 않는가"**다.
/// 좌표만 단언하면 두 경로 중 무엇을 썼든 통과해서 아무것도 막지 못한다.
///
/// 상세: 볼트 `plugin-cleanup-blocks-main-thread`
void main() {
  final seoul = testPosition(37.5665, 126.9780);
  final busan = testPosition(35.1796, 129.0756);

  Future<({_RecordingQuestRepository repository, NearbyQuests result})>
  fetchWith(LocationService location) async {
    final repository = _RecordingQuestRepository();
    final container = ProviderContainer(
      // 앱과 같은 재시도 정책을 얹는다(`main.dart`의 ProviderScope). 기본값으로 두면
      // 실패가 40초 가까이 재시도로 흘러 테스트가 타임아웃되는데, 그것은 테스트만의
      // 사정이 아니라 **사용자가 보게 되는 화면 그대로**다.
      retry: lqProviderRetry,
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        questRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(nearbyQuestsProvider.future);
    return (repository: repository, result: result);
  }

  /// 이 테스트 하나가 ANR 경로를 막는다. 나머지는 그 대가를 확인하는 것들이다.
  test('캐시가 있으면 새 fix를 요청하지 않는다', () async {
    final location = RecordingLocationService(lastKnown: seoul, fresh: busan);

    await fetchWith(location);

    expect(
      location.freshFixRequested,
      isFalse,
      reason:
          '캐시가 있는데 새 fix를 요청했다 — 그 조회의 정리 단계가 메인 스레드를 막아 '
          '지도 탭에서 ANR이 났던 경로다',
    );
  });

  test('캐시된 좌표를 그대로 조회에 쓴다', () async {
    final fetched = await fetchWith(
      RecordingLocationService(lastKnown: seoul, fresh: busan),
    );

    expect(fetched.repository.calls, hasLength(1));
    expect(fetched.repository.calls.single.latitude, seoul.latitude);
    expect(fetched.repository.calls.single.longitude, seoul.longitude);
    // 지도는 이 좌표를 기준점으로 그린다 — 조회에 쓴 값과 같아야 한다.
    expect(fetched.result.origin.latitude, seoul.latitude);
  });

  /// 캐시는 "있으면 쓰는 것"이지 전제가 아니다. 앱을 처음 깔았거나 권한을 방금 허용한
  /// 기기에는 없고, 그때는 새 fix가 유일한 경로다.
  test('캐시가 없으면 새 fix로 떨어진다', () async {
    final location = RecordingLocationService(lastKnown: null, fresh: busan);

    final fetched = await fetchWith(location);

    expect(location.freshFixRequested, isTrue);
    expect(fetched.repository.calls.single.latitude, busan.latitude);
  });

  /// **오늘의 퀘스트와 갈리는 지점이다.** 그쪽은 좌표가 없어도 카탈로그 전체에서
  /// 골라 조회를 진행하지만, 여기서는 좌표가 없으면 "주변"을 정의할 수 없어 조회
  /// 자체가 성립하지 않는다. 조용히 빈 목록을 돌려주면 사용자는 주변에 퀘스트가
  /// 없는 것으로 오해한다.
  test('위치를 어느 경로로도 못 얻으면 오류가 된다', () async {
    final repository = _RecordingQuestRepository();
    final container = ProviderContainer(
      // 앱과 같은 재시도 정책을 얹는다(`main.dart`의 ProviderScope). 기본값으로 두면
      // 실패가 40초 가까이 재시도로 흘러 테스트가 타임아웃되는데, 그것은 테스트만의
      // 사정이 아니라 **사용자가 보게 되는 화면 그대로**다.
      retry: lqProviderRetry,
      overrides: [
        locationServiceProvider.overrideWithValue(
          const BrokenLocationService(),
        ),
        questRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    Object? caught;
    try {
      await container.read(nearbyQuestsProvider.future);
    } catch (error) {
      caught = error;
    }

    expect(caught, isA<LocationServiceException>());
    expect(
      repository.calls,
      isEmpty,
      reason: '좌표 없이 주변 조회를 부르면 서버가 어디를 기준으로 답해야 할지 알 수 없다',
    );
  });
}

/// `fetchNearby`가 받은 좌표를 그대로 모아 둔다.
class _RecordingQuestRepository extends QuestRepository {
  _RecordingQuestRepository() : super(Dio());

  final List<({double latitude, double longitude, double radiusKm})> calls = [];

  @override
  Future<List<DailyQuest>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    calls.add((latitude: latitude, longitude: longitude, radiusKm: radiusKm));
    return const [];
  }
}
