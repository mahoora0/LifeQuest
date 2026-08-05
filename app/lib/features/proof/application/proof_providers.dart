import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/data/proof_repository.dart';

final proofRepositoryProvider = Provider<ProofRepository>(
  (ref) => ProofRepository(ref.watch(dioProvider)),
);

/// 홈 섹션의 미리보기. 피드와 같은 "투표 필요" 기준을 쓰되 몇 장만 가져온다.
///
/// 최신순이 아니라 투표가 필요한 게시물을 띄우는 것이 이 섹션의 존재 이유다.
/// 최신순으로 두면 이미 판정이 끝난 게시물이 위를 차지해서, 사용자가 적을 때
/// 정작 표가 모자란 게시물이 아무에게도 보이지 않는다.
final proofHighlightsProvider = FutureProvider.autoDispose<List<ProofPost>>((
  ref,
) async {
  final page = await ref
      .watch(proofRepositoryProvider)
      .feed(tab: ProofFeedTab.needsVote, size: 6);
  return page.items;
});

final proofDetailProvider = FutureProvider.autoDispose.family<ProofPost, int>(
  (ref, postId) => ref.watch(proofRepositoryProvider).detail(postId),
);

final proofCommentsProvider = FutureProvider.autoDispose
    .family<List<ProofComment>, int>(
      (ref, postId) => ref.watch(proofRepositoryProvider).comments(postId),
    );

final proofCandidatesProvider =
    FutureProvider.autoDispose<List<ProofCandidate>>(
      (ref) => ref.watch(proofRepositoryProvider).candidates(),
    );

/// 무한 스크롤 피드의 누적 상태.
class ProofFeedState {
  const ProofFeedState({
    this.posts = const [],
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<ProofPost> posts;
  final int? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  ProofFeedState copyWith({
    List<ProofPost>? posts,
    int? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => ProofFeedState(
    posts: posts ?? this.posts,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// 탭을 바꿔 돌아왔을 때 지난 목록이 그대로 깔려 있지 않도록 autoDispose로 둔다.
final proofFeedProvider = AsyncNotifierProvider.autoDispose
    .family<ProofFeedNotifier, ProofFeedState, ProofFeedTab>(
      ProofFeedNotifier.new,
    );

class ProofFeedNotifier extends AsyncNotifier<ProofFeedState> {
  ProofFeedNotifier(this.tab);

  /// Riverpod 3의 family는 인자를 `build`가 아니라 Notifier 생성자로 넘긴다.
  final ProofFeedTab tab;

  static const _pageSize = 10;

  @override
  Future<ProofFeedState> build() async {
    final page = await ref
        .read(proofRepositoryProvider)
        .feed(tab: tab, size: _pageSize);
    return ProofFeedState(posts: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// 다음 페이지를 이어 붙인다. 이미 불러오는 중이면 아무것도 하지 않는다 —
  /// 스크롤 이벤트는 연달아 들어오므로 이 가드가 없으면 같은 페이지를 여러 번 붙인다.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(proofRepositoryProvider)
          .feed(tab: tab, cursor: current.nextCursor, size: _pageSize);

      state = AsyncData(
        ProofFeedState(
          posts: [...current.posts, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      // 추가 로드 실패는 화면 전체를 오류로 덮지 않는다. 이미 보이는 게시물이
      // 사라지는 편이 이어 붙이지 못한 것보다 나쁘다.
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// 투표 결과로 목록의 해당 카드만 갈아 끼운다. 전체를 다시 불러오면
  /// 스크롤 위치가 튀고, "투표 필요" 탭에서는 방금 투표한 카드가 사라져
  /// 무엇에 투표했는지 확인할 수 없게 된다.
  void replace(ProofPost updated) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        posts: [
          for (final post in current.posts)
            post.postId == updated.postId ? updated : post,
        ],
      ),
    );
  }

  void remove(int postId) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        posts: current.posts.where((post) => post.postId != postId).toList(),
      ),
    );
  }
}
