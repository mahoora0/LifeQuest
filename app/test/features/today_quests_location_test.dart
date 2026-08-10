import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';

import '../support/stub_location_service.dart';

/// 오늘의 퀘스트 조회가 좌표를 실어 보내는지 고정한다.
///
/// 이 경로는 **에뮬레이터 실측에서 통째로 죽어 있었다.** 새 GPS fix부터 기다리다 5초
/// 타임아웃에 걸려 좌표가 한 번도 서버에 닿지 않았고, 그래서 제주에 둔 기기가 대전
/// 퀘스트를 받았다. 그때 앱 테스트 196건은 전부 초록이었다 — 어느 테스트도 "좌표가
/// 실렸는가"를 재지 않았기 때문이다.
///
/// 배정은 주기당 한 번 만들어지고 그 뒤로는 좌표가 무시되므로, 이 호출이 좌표를
/// 빠뜨리면 사용자는 그 주기 내내 엉뚱한 지역 퀘스트를 받고 되돌릴 방법이 없다.
/// 조용히 깨지는 종류라 여기서 잡는다.
void main() {
  /// 서울시청 부근. 값 자체는 뜻이 없고 "이 좌표가 그대로 실렸는가"만 본다.
  final seoul = _position(37.5665, 126.9780);
  final busan = _position(35.1796, 129.0756);

  Future<_RecordingQuestRepository> fetchWith(LocationService location) async {
    final repository = _RecordingQuestRepository();
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        questRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(todayQuestsProvider.future);
    return repository;
  }

  test('캐시된 마지막 위치를 그대로 실어 보낸다', () async {
    final repository = await fetchWith(StubLocationService(position: seoul));

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.latitude, seoul.latitude);
    expect(repository.calls.single.longitude, seoul.longitude);
  });

  /// **순서가 계약이다.** 새 fix부터 기다리면 콜드 스타트에서 타임아웃에 걸려
  /// 좌표가 통째로 빠진다 — 실측에서 실제로 그랬다. 캐시가 있으면 그쪽을 쓴다.
  test('캐시가 있으면 새 fix를 기다리지 않는다', () async {
    final location = _SlowFixLocationService(lastKnown: seoul, fresh: busan);

    final repository = await fetchWith(location);

    expect(
      location.freshFixRequested,
      isFalse,
      reason: '캐시가 있는데 새 fix를 요청했다 — 콜드 스타트에서 이 대기가 좌표를 통째로 잃게 만든다',
    );
    expect(repository.calls.single.latitude, seoul.latitude);
  });

  test('캐시가 없으면 새 fix로 떨어진다', () async {
    final repository = await fetchWith(
      _SlowFixLocationService(lastKnown: null, fresh: busan),
    );

    expect(repository.calls.single.latitude, busan.latitude);
    expect(repository.calls.single.longitude, busan.longitude);
  });

  /// 위치를 못 얻는 것은 오류가 아니다. 권한 거부·GPS 꺼짐·실내 fix 실패는 모두
  /// 정상적인 상황이고, 그때 잃어야 할 것은 "주변에서 고른다"는 이점뿐이다 —
  /// 오늘의 퀘스트 화면 전체가 아니다.
  test('위치를 못 얻어도 좌표 없이 조회는 진행한다', () async {
    final repository = await fetchWith(const _BrokenLocationService());

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.latitude, isNull);
    expect(repository.calls.single.longitude, isNull);
  });

  /// 캐시 조회가 터져도 새 fix로 이어져야 한다. 여기서 멈추면 캐시를 지원하지 않는
  /// 기기에서 위치 타게팅이 통째로 사라진다.
  test('캐시 조회가 실패해도 새 fix를 시도한다', () async {
    final repository = await fetchWith(
      _SlowFixLocationService(
        lastKnown: null,
        fresh: busan,
        throwOnLastKnown: true,
      ),
    );

    expect(repository.calls.single.latitude, busan.latitude);
  });
}

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.utc(2026, 8, 10),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// `fetchToday`가 받은 좌표를 그대로 모아 둔다.
class _RecordingQuestRepository extends QuestRepository {
  _RecordingQuestRepository() : super(Dio());

  final List<({double? latitude, double? longitude})> calls = [];

  @override
  Future<TodayQuests> fetchToday({double? latitude, double? longitude}) async {
    calls.add((latitude: latitude, longitude: longitude));
    return const TodayQuests(assignedDate: '2026-08-10', quests: []);
  }
}

/// 새 fix가 요청됐는지를 기록한다. 실제로 느리게 만들 필요는 없다 —
/// 재려는 것은 "기다렸는가"가 아니라 "부르기는 했는가"다.
class _SlowFixLocationService extends StubLocationService {
  _SlowFixLocationService({
    required this.lastKnown,
    required this.fresh,
    this.throwOnLastKnown = false,
  });

  final Position? lastKnown;
  final Position fresh;
  final bool throwOnLastKnown;

  bool freshFixRequested = false;

  @override
  Future<Position?> getLastKnownPosition() async {
    if (throwOnLastKnown) {
      throw const LocationServiceException('테스트: 캐시 조회 실패');
    }
    return lastKnown;
  }

  @override
  Future<Position> getCurrentPosition() async {
    freshFixRequested = true;
    return fresh;
  }
}

/// 위치를 어느 경로로도 얻지 못하는 기기.
class _BrokenLocationService extends StubLocationService {
  const _BrokenLocationService();

  @override
  Future<Position?> getLastKnownPosition() =>
      throw const LocationServiceException('테스트: 캐시 없음');

  @override
  Future<Position> getCurrentPosition() =>
      throw const LocationServiceException('테스트: fix 실패');
}
