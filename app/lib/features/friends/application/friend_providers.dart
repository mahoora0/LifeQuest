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

/// 이번 주 친구 랭킹(S-22).
final weeklyRankingProvider = FutureProvider<WeeklyRanking>((ref) {
  return ref.watch(friendRepositoryProvider).fetchWeeklyRanking();
});

/// 내 친구 코드. 동료 찾기는 목록을 불러오지 않고도 코드를 보여야 한다.
final myFriendCodeProvider = FutureProvider<String?>((ref) {
  return ref.watch(friendRepositoryProvider).fetchMyCode();
});

/// 동료 찾기 화면 상태 — 질의어와 결과를 함께 들고 있는다.
///
/// 결과만 들고 있으면 "검색 결과 N명" 문구를 아직 검색하지 않은 상태와 구분할 수 없다.
class AdventurerSearchState {
  const AdventurerSearchState({this.query = '', this.results = const []});

  final String query;
  final List<AdventurerSearchResult> results;

  bool get hasQuery => query.isNotEmpty;
}

/// S-18 동료 찾기.
final adventurerSearchProvider =
    AsyncNotifierProvider<AdventurerSearchNotifier, AdventurerSearchState>(
      AdventurerSearchNotifier.new,
    );

class AdventurerSearchNotifier extends AsyncNotifier<AdventurerSearchState> {
  @override
  Future<AdventurerSearchState> build() async => const AdventurerSearchState();

  Future<void> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      state = const AsyncData(AdventurerSearchState());
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final results = await ref
          .read(friendRepositoryProvider)
          .searchAdventurers(normalized);
      return AdventurerSearchState(query: normalized, results: results);
    });
  }

  /// 동료 신청. 화면을 먼저 바꾸고 실패하면 되돌린다.
  ///
  /// 이미 관계가 있는 상대는 아무 일도 하지 않는다 — 중복 요청은 서버에서도
  /// 막히지만, 누를 수 없는 버튼이 눌린 것처럼 보이면 상태 표시를 의심하게 된다.
  Future<void> sendRequest(int userId) async {
    final current = state.value;
    if (current == null) return;

    final target = current.results
        .where((result) => result.userId == userId)
        .firstOrNull;
    if (target == null || !target.relation.isActionable) return;

    state = AsyncData(
      AdventurerSearchState(
        query: current.query,
        results: [
          for (final result in current.results)
            result.userId == userId
                ? result.copyWith(
                    relation: FriendRelation.requestSent,
                    statusLine: '요청을 보냈어요 · 대기 중',
                  )
                : result,
        ],
      ),
    );

    try {
      await ref.read(friendRepositoryProvider).sendRequest(userId);
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// S-19 받은 요청 · 보낸 요청.
final friendRequestsProvider =
    AsyncNotifierProvider<FriendRequestsNotifier, FriendRequestBox>(
      FriendRequestsNotifier.new,
    );

class FriendRequestsNotifier extends AsyncNotifier<FriendRequestBox> {
  @override
  Future<FriendRequestBox> build() {
    return ref.watch(friendRepositoryProvider).fetchRequests();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(friendRepositoryProvider).fetchRequests(),
    );
  }

  /// 수락·거절 모두 그 행을 목록에서 걷어낸다. 처리한 요청이 남아 있으면
  /// 같은 요청을 두 번 처리하게 된다.
  Future<void> respond(int userId, {required bool accept}) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.removeReceived(userId));

    try {
      await ref
          .read(friendRepositoryProvider)
          .respondToRequest(userId, accept: accept);
      // 수락하면 친구 목록이 한 명 늘어난다. 다시 열었을 때 비어 있지 않도록
      // 목록을 무효화해 다음 조회에서 새로 받게 한다.
      if (accept) ref.invalidate(friendListProvider);
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// S-21 동료 여정 비교. 친구마다 별도 상태를 갖도록 family로 둔다.
final friendJourneyProvider =
    AsyncNotifierProvider.family<FriendJourneyNotifier, FriendJourney, int>(
      FriendJourneyNotifier.new,
    );

class FriendJourneyNotifier extends AsyncNotifier<FriendJourney> {
  FriendJourneyNotifier(this.userId);

  /// Riverpod 3의 family는 인자를 `build`가 아니라 Notifier 생성자로 넘긴다.
  final int userId;

  @override
  Future<FriendJourney> build() {
    return ref.watch(friendRepositoryProvider).fetchJourney(userId);
  }

  /// 응원. 목록 화면과 같은 단방향 규칙을 따른다(되돌리기 없음).
  Future<void> cheer() async {
    final current = state.value;
    if (current == null || current.cheered) return;

    state = AsyncData(current.copyWith(cheered: true));

    try {
      await ref.read(friendRepositoryProvider).cheer(userId);
      // 목록 쪽 응원 상태도 같이 바뀌어야 한다 — 돌아갔을 때 다시 응원할 수
      // 있는 것처럼 보이면 재지급을 시도하게 된다.
      ref.invalidate(friendListProvider);
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> unfriend() async {
    await ref.read(friendRepositoryProvider).unfriend(userId);
    ref.invalidate(friendListProvider);
  }
}
