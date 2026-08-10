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
    return ref.watch(questRepositoryProvider).fetchToday();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(questRepositoryProvider).fetchToday(),
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
