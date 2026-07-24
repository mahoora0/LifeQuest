import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/features/user/data/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(dioProvider));
});

final myProfileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(userRepositoryProvider).fetchMe();
});

/// 레벨 표기는 항상 이 provider를 사용한다(시안의 예시 수치 하드코딩 금지).
final levelStatusProvider = FutureProvider<LevelStatus>((ref) {
  return ref.watch(userRepositoryProvider).fetchLevel();
});

final rewardHistoryProvider = FutureProvider<RewardHistory>((ref) {
  return ref.watch(userRepositoryProvider).fetchRewards();
});

/// 보유 칭호 + 대표 칭호 선택.
final titleCollectionProvider =
    AsyncNotifierProvider<TitleCollectionNotifier, TitleCollection>(
      TitleCollectionNotifier.new,
    );

class TitleCollectionNotifier extends AsyncNotifier<TitleCollection> {
  @override
  Future<TitleCollection> build() {
    return ref.watch(userRepositoryProvider).fetchTitles();
  }

  /// 대표 칭호 지정 / 재탭 시 해제(null 전송).
  Future<void> select(int titleId) async {
    final current = state.value;
    if (current == null) return;

    final next = current.representativeTitleId == titleId ? null : titleId;
    state = AsyncData(
      TitleCollection(titles: current.titles, representativeTitleId: next),
    );

    try {
      await ref.read(userRepositoryProvider).updateRepresentativeTitle(next);
      ref.invalidate(myProfileProvider);
    } catch (error, stackTrace) {
      // 실패 시 서버 상태로 되돌린다.
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
