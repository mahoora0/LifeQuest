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
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final result = await ref
        .read(questRepositoryProvider)
        .complete(
          dailyQuestId,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
        );

    _markCompleted(dailyQuestId);
    ref.invalidate(levelStatusProvider);
    return result.withQuestTitle(_titleOf(dailyQuestId));
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
  final position = await ref.watch(locationServiceProvider).getCurrentPosition();
  final quests = await ref
      .watch(questRepositoryProvider)
      .fetchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: 3,
      );
  return NearbyQuests(origin: position, quests: quests);
});
