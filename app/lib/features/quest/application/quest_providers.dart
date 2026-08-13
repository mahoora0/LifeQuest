import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/user/application/user_providers.dart';

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  return QuestRepository(ref.watch(dioProvider));
});

/// 오늘의 퀘스트 — 홈(S-07)과 퀘스트 목록(S-08)이 같은 provider를 공유한다.
final todayQuestsProvider =
    AsyncNotifierProvider<TodayQuestsNotifier, TodayQuests>(
      TodayQuestsNotifier.new,
    );

class TodayQuestsNotifier extends AsyncNotifier<TodayQuests> {
  @override
  Future<TodayQuests> build() {
    // 의존성은 첫 await 전에 읽어 둔다 — 위치 조회 도중 provider가 무효화되면
    // await 뒤의 ref는 이미 dispose된 상태다(nearbyQuestsProvider와 같은 이유).
    final locationService = ref.watch(locationServiceProvider);
    final repository = ref.watch(questRepositoryProvider);
    return _fetchWithPosition(locationService, repository);
  }

  Future<void> refresh() async {
    final locationService = ref.read(locationServiceProvider);
    final repository = ref.read(questRepositoryProvider);
    state = await AsyncValue.guard(
      () => _fetchWithPosition(locationService, repository),
    );
  }

  /// 위치를 곁들여 오늘의 퀘스트를 부른다. 위치를 못 얻어도 조회는 진행한다.
  static Future<TodayQuests> _fetchWithPosition(
    LocationService locationService,
    QuestRepository repository,
  ) async {
    final position = await _bestEffortPosition(locationService);
    return repository.fetchToday(
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }

  /// 퀘스트 완료. 성공 시 해당 배정 건을 즉시 완료 상태로 반영하고
  /// 레벨 정보를 무효화해 홈/마이의 EXP 표시를 갱신한다.
  ///
  /// 중복 완료(`duplicated=true`)도 서버가 200으로 돌려주므로 예외가 아니다.
  Future<QuestCompletionResult> complete(
    int dailyQuestId, {
    CompletionCoordinates? coordinates,
  }) async {
    final result = await ref
        .read(questRepositoryProvider)
        .complete(dailyQuestId, coordinates: coordinates);

    _markCompleted(dailyQuestId);
    ref.invalidate(levelStatusProvider);
    ref.invalidate(questHistoryProvider);
    return result.withQuestTitle(_titleOf(dailyQuestId));
  }

  /// AI 추천 후보를 주간 퀘스트로 받는다. 성공하면 목록을 다시 불러
  /// 새 배정이 세 번째 주간 자리에 나타나게 한다.
  ///
  /// 목록 전체를 새로 부르는 이유는 이 호출이 <b>자동 주간 배정을 유발할 수도</b>
  /// 있기 때문이다 — 오늘의 퀘스트를 한 번도 열지 않은 사용자는 이 시점에
  /// 자동 2개가 아직 없고, 다음 조회가 그것을 만든다.
  Future<DailyQuest> claimWeeklyAiQuest(int candidateId) async {
    final claimed = await ref
        .read(questRepositoryProvider)
        .claimWeeklyAiQuest(candidateId);
    await refresh();
    return claimed;
  }

  String? _titleOf(int dailyQuestId) {
    final current = state.value;
    if (current == null) return null;
    for (final quest in current.quests) {
      if (quest.dailyQuestId == dailyQuestId) return quest.quest.title;
    }
    return null;
  }

  void _markCompleted(int dailyQuestId) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      TodayQuests(
        assignedDate: current.assignedDate,
        quests: [
          for (final quest in current.quests)
            if (quest.dailyQuestId == dailyQuestId)
              DailyQuest(
                dailyQuestId: quest.dailyQuestId,
                status: DailyQuestStatus.completed,
                quest: quest.quest,
                distanceM: quest.distanceM,
              )
            else
              quest,
        ],
      ),
    );
  }
}

/// 퀘스트 상세 (`GET /quests/{questId}`).
final questDetailProvider = FutureProvider.family<Quest, int>((
  ref,
  questId,
) async {
  return ref.watch(questRepositoryProvider).fetchQuest(questId);
});

/// 완료 기록 페이지(마이페이지 카운트용).
final questHistoryProvider = FutureProvider<QuestHistoryPage>((ref) async {
  return ref.watch(questRepositoryProvider).fetchHistory(size: 1);
});

/// 지도 화면의 주변 퀘스트 요약.
class NearbyQuests {
  const NearbyQuests({required this.origin, required this.quests});

  final Position origin;
  final List<DailyQuest> quests;

  /// 거리 오름차순 중 첫 항목.
  DailyQuest? get nearest {
    if (quests.isEmpty) return null;
    final sorted = [...quests]
      ..sort(
        (a, b) => (a.distanceM ?? double.infinity).compareTo(
          b.distanceM ?? double.infinity,
        ),
      );
    return sorted.first;
  }
}

/// 위치를 최선 노력으로 얻는다. 얻지 못하면 `null`.
///
/// **캐시된 마지막 위치를 먼저 쓴다.** 서버가 이 좌표로 하는 일은 "어느 동네인가"를
/// 15km·50km 단위로 가르는 것뿐이라(`05-business-rules.md` §1-C) 몇 분 전 위치로
/// 충분하고, 그쪽은 즉시 돌아온다.
///
/// 새 fix부터 기다리면 안 되는 이유는 **이 좌표가 쓰이는 순간이 하필 GPS가 가장
/// 느린 때**이기 때문이다. 배정은 주기당 한 번 만들어지고 그 뒤로는 좌표가 무시되는데,
/// 그 한 번이 앱을 처음 연 직후다. 콜드 스타트의 fix는 10초를 넘기는 일이 흔해
/// 타임아웃으로 떨어지고, 그러면 사용자는 그 주기 내내 엉뚱한 지역 퀘스트를 받는다.
/// 에뮬레이터 실측에서 실제로 이렇게 됐다 — 제주에 둔 기기가 대전 퀘스트를 받았다.
///
/// 실패를 삼키는 것은 여기서 위치가 **있으면 좋은 값**이기 때문이다. 권한 거부·GPS
/// 꺼짐·fix 실패는 모두 정상적인 상황이고, 예외를 올리면 오늘의 퀘스트 화면 전체가
/// 오류로 바뀐다 — 잃어야 할 것은 "주변에서 고른다"는 이점뿐이다.
Future<Position?> _bestEffortPosition(LocationService locationService) async {
  try {
    final lastKnown = await locationService.getLastKnownPosition();
    if (lastKnown != null) {
      return lastKnown;
    }
  } catch (_) {
    // 캐시 조회 실패는 새 fix를 막지 않는다.
  }

  try {
    return await locationService.getCurrentPosition().timeout(
      const Duration(seconds: 8),
    );
  } catch (_) {
    return null;
  }
}

/// 현재 위치 조회 → `GET /quests/nearby`.
final nearbyQuestsProvider = FutureProvider<NearbyQuests>((ref) async {
  // GPS fix는 10초 넘게 걸릴 수 있다. 그 사이 provider가 무효화되면
  // await 뒤의 ref는 이미 dispose된 상태라 사용할 수 없으므로,
  // 의존성은 첫 await 전에 모두 읽어 둔다.
  final locationService = ref.watch(locationServiceProvider);
  final repository = ref.watch(questRepositoryProvider);

  final position = await locationService.getCurrentPosition();
  final quests = await repository.fetchNearby(
    latitude: position.latitude,
    longitude: position.longitude,
    radiusKm: 3,
  );
  return NearbyQuests(origin: position, quests: quests);
});
