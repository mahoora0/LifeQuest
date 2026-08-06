import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/proof/application/proof_providers.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/presentation/widgets/proof_card.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 인증 광장 피드. 무한 스크롤은 여기에만 있다 —
/// 홈은 미리보기만 보여준다(홈이 이미 세로 스크롤 목록이라 안에 또 스크롤을 넣으면
/// 어느 쪽이 제스처를 먹을지 불안정해지고, 게시물 전체를 한 번에 빌드하게 된다).
class ProofFeedScreen extends ConsumerStatefulWidget {
  const ProofFeedScreen({super.key});

  @override
  ConsumerState<ProofFeedScreen> createState() => _ProofFeedScreenState();
}

class _ProofFeedScreenState extends ConsumerState<ProofFeedScreen> {
  final _scrollController = ScrollController();
  ProofFeedTab _tab = ProofFeedTab.needsVote;
  final _voting = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 바닥에 닿기 전에 미리 당겨 온다. 닿은 뒤에 요청하면 빈 화면을 한 번 보게 된다.
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(proofFeedProvider(_tab).notifier).loadMore();
    }
  }

  Future<void> _vote(ProofPost post, ProofVoteChoice choice) async {
    if (_voting.contains(post.postId)) return;
    setState(() => _voting.add(post.postId));

    try {
      final result = await ref
          .read(proofRepositoryProvider)
          .vote(post.postId, choice);

      // 목록 전체를 다시 부르지 않고 해당 카드만 갈아 끼운다. "투표 필요" 탭에서
      // 새로 조회하면 방금 투표한 카드가 조건에서 빠져 사라지고, 사용자는 자기가
      // 무엇을 눌렀는지 확인하지 못한다.
      ref.read(proofFeedProvider(_tab).notifier).replace(result.post);
      ref.invalidate(proofHighlightsProvider);

      if (!mounted) return;
      showLqSnack(
        context,
        result.expGained > 0
            ? '검증 참여로 ${result.expGained} EXP를 받았어요'
            : '오늘 투표 보상은 모두 받았어요. 투표는 그대로 반영됐어요',
      );
    } catch (error) {
      if (!mounted) return;
      showLqError(context, error);
    } finally {
      if (mounted) setState(() => _voting.remove(post.postId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(proofFeedProvider(_tab));

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LqColors.primary,
        foregroundColor: LqColors.onDark,
        onPressed: () => context.push('/proofs/new'),
        icon: const Icon(Icons.add_a_photo_outlined, size: 20),
        label: const Text('인증 올리기'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '인증 광장'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  for (final tab in ProofFeedTab.values) ...[
                    LqChip(
                      label: tab.label,
                      selected: tab == _tab,
                      onTap: () => setState(() => _tab = tab),
                    ),
                    if (tab != ProofFeedTab.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: LqAsyncView<ProofFeedState>(
                value: value,
                isEmpty: (state) => state.posts.isEmpty,
                emptyMessage: switch (_tab) {
                  ProofFeedTab.needsVote => '지금은 판정을 기다리는 인증이 없어요',
                  ProofFeedTab.all => '아직 올라온 인증이 없어요',
                  ProofFeedTab.mine => '아직 올린 인증이 없어요',
                },
                onRetry: () => ref.invalidate(proofFeedProvider(_tab)),
                data: (state) => RefreshIndicator(
                  color: LqColors.primary,
                  backgroundColor: LqColors.surfaceRaised,
                  onRefresh: () =>
                      ref.read(proofFeedProvider(_tab).notifier).refresh(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: state.posts.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= state.posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: LqColors.primary,
                              ),
                            ),
                          ),
                        );
                      }

                      final post = state.posts[index];
                      return ProofCard(
                        post: post,
                        voting: _voting.contains(post.postId),
                        onVote: (choice) => _vote(post, choice),
                        onOpen: () => context.push('/proofs/${post.postId}'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
