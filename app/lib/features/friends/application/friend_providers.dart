import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/data/friend_repository.dart';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return const FriendRepository();
});

/// 친구 목록(S-18). 응원 상태를 화면에서 바꿔야 해서 Notifier로 둔다.
final friendListProvider =
    AsyncNotifierProvider<FriendListNotifier, FriendList>(
      FriendListNotifier.new,
    );

class FriendListNotifier extends AsyncNotifier<FriendList> {
  @override
  Future<FriendList> build() {
    return ref.watch(friendRepositoryProvider).fetchFriends();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(friendRepositoryProvider).fetchFriends(),
    );
  }

  /// 친구 응원. 화면을 먼저 바꾸고 실패하면 되돌린다.
  ///
  /// 이미 응원한 상대는 아무 일도 하지 않는다. 응원에 EXP 보상이 걸려 있어 해제·재응원을
  /// 허용하면 재지급 경로가 생기는데, 서버의 중복 차단 규칙이 아직 정해지지 않았다.
  Future<void> cheer(int userId) async {
    final current = state.value;
    if (current == null) return;

    final alreadyCheered = current.friends.any(
      (friend) => friend.userId == userId && friend.cheered,
    );
    if (alreadyCheered) return;

    state = AsyncData(
      FriendList(
        myCode: current.myCode,
        friends: [
          for (final friend in current.friends)
            friend.userId == userId ? friend.copyWith(cheered: true) : friend,
        ],
      ),
    );

    try {
      await ref.read(friendRepositoryProvider).cheer(userId);
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// 이번 주 친구 랭킹(S-21).
final weeklyRankingProvider = FutureProvider<WeeklyRanking>((ref) {
  return ref.watch(friendRepositoryProvider).fetchWeeklyRanking();
});
