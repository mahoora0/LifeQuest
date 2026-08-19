import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/core/network/provider_retry.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/quest/presentation/map_screen.dart';

import '../support/stub_location_service.dart';

/// 지도 화면이 **키 없이도 성립하는가**를 고정한다.
///
/// `NAVER_MAP_CLIENT_ID`는 실행기가 주입하고 `flutter test`·CI 빌드는 주입하지
/// 않는다. 그 상태에서 지도 자리가 비면 화면이 통째로 고장난 것처럼 보이는데,
/// 키가 있는 개발자 PC에서는 그 모습을 한 번도 볼 수 없다. 여기서 재는 것은
/// 좌표나 마커가 아니라 **대체 화면으로 내려오는가**다.
void main() {
  test('테스트 환경에는 지도 키가 없다', () {
    // 아래 위젯 테스트의 전제. 이 단언이 깨지면 대체 화면 경로가 아니라 실지도
    // 경로를 재게 되고, 플랫폼 뷰가 없는 위젯 테스트에서는 그대로 멈춘다.
    expect(AppConfig.isMapEnabled, isFalse);
  });

  testWidgets('키가 없으면 지도 자리에 탐험 캔버스가 그려진다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: lqProviderRetry,
        overrides: [
          locationServiceProvider.overrideWithValue(
            StubLocationService(position: testPosition(37.5665, 126.9780)),
          ),
          questRepositoryProvider.overrideWithValue(_NearbyQuestRepository()),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    // 대체 캔버스의 펄스 링이 무한 반복이라 pumpAndSettle은 정착하지 못한다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('지역 지도'), findsOneWidget);
    // 대체 화면의 장식 라벨. 지도가 없어도 화면이 비지 않는다는 증거다.
    expect(find.text('숲길 구역'), findsOneWidget);
  });

  testWidgets('주변 퀘스트는 지도 유무와 무관하게 요약 카드에 나온다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: lqProviderRetry,
        overrides: [
          locationServiceProvider.overrideWithValue(
            StubLocationService(position: testPosition(37.5665, 126.9780)),
          ),
          questRepositoryProvider.overrideWithValue(_NearbyQuestRepository()),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    // 대체 캔버스의 펄스 링이 무한 반복이라 pumpAndSettle은 정착하지 못한다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('근처 퀘스트 1개'), findsOneWidget);
    expect(find.text('경복궁 돌아보기'), findsOneWidget);
  });
}

class _NearbyQuestRepository extends QuestRepository {
  _NearbyQuestRepository() : super(Dio());

  @override
  Future<List<DailyQuest>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async => const [
    DailyQuest(
      dailyQuestId: 1,
      status: DailyQuestStatus.assigned,
      quest: Quest(
        id: 1,
        title: '경복궁 돌아보기',
        cadence: QuestCadence.daily,
        completionType: QuestCompletionType.location,
        expReward: 32,
        grade: 'RARE',
        placeName: '경복궁',
        latitude: 37.5796,
        longitude: 126.9770,
        radiusM: 100,
      ),
      distanceM: 412,
    ),
  ];
}
