import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/proof/application/proof_providers.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/presentation/widgets/proof_widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 인증 게시물 상세. 카드에서 못 하는 것은 댓글뿐이라, 이 화면의 본체는 댓글이다.
class ProofDetailScreen extends ConsumerStatefulWidget {
  const ProofDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<ProofDetailScreen> createState() => _ProofDetailScreenState();
}

class _ProofDetailScreenState extends ConsumerState<ProofDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;
  bool _voting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _vote(ProofVoteChoice choice) async {
    if (_voting) return;
    setState(() => _voting = true);

    try {
      final result = await ref
          .read(proofRepositoryProvider)
          .vote(widget.postId, choice);
      ref.invalidate(proofDetailProvider(widget.postId));
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
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);

    try {
      await ref
          .read(proofRepositoryProvider)
          .addComment(widget.postId, content);
      _commentController.clear();
      ref.invalidate(proofCommentsProvider(widget.postId));
      // 댓글 수가 카드에 표시되므로 게시물도 함께 새로 읽는다.
      ref.invalidate(proofDetailProvider(widget.postId));
    } catch (error) {
      if (!mounted) return;
      showLqError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LqColors.surfaceRaised,
        title: const Text('인증을 삭제할까요?'),
        content: const Text('사진과 댓글, 받은 투표가 함께 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(proofRepositoryProvider).delete(widget.postId);
      ref.invalidate(proofHighlightsProvider);
      ref.invalidate(proofCandidatesProvider);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      showLqError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(proofDetailProvider(widget.postId));
    final comments = ref.watch(proofCommentsProvider(widget.postId));

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            LqHeader(
              title: '인증 상세',
              trailing: post.value?.mine == true
                  ? IconButton(
                      onPressed: _delete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: LqColors.textSecondary,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: LqAsyncView<ProofPost>(
                value: post,
                onRetry: () =>
                    ref.invalidate(proofDetailProvider(widget.postId)),
                data: (value) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _PostBody(post: value, voting: _voting, onVote: _vote),
                    const SizedBox(height: 16),
                    Text('댓글', style: LqText.sectionTitle),
                    const SizedBox(height: 8),
                    _CommentList(value: comments),
                  ],
                ),
              ),
            ),
            _CommentComposer(
              controller: _commentController,
              sending: _sending,
              onSubmit: _submitComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({
    required this.post,
    required this.voting,
    required this.onVote,
  });

  final ProofPost post;
  final bool voting;
  final ValueChanged<ProofVoteChoice> onVote;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProofAvatar(author: post.author, size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.nickname,
                      style: LqText.label.copyWith(color: LqColors.textPrimary),
                    ),
                    Text(proofTimeLabel(post.createdAt), style: LqText.caption),
                  ],
                ),
              ),
              ProofStatusBadge(post: post),
            ],
          ),
          const SizedBox(height: 12),
          ProofQuestBadge(title: post.questTitle, grade: post.questGrade),
          const SizedBox(height: 12),
          ProofPhotoCarousel(photoUrls: post.photoUrls),
          if (post.content != null && post.content!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(post.content!, style: LqText.body),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: LqColors.divider),
          const SizedBox(height: 12),
          if (post.canVote) ...[
            Text('이 인증, 어떻게 보이나요?', style: LqText.label),
            const SizedBox(height: 8),
            ProofVoteButtons(onVote: onVote, busy: voting),
          ] else
            ProofVoteResultBar(post: post),
        ],
      ),
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({required this.value});

  final AsyncValue<List<ProofComment>> value;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: LqColors.primary,
            ),
          ),
        ),
      ),
      error: (error, stackTrace) =>
          Text('댓글을 불러오지 못했어요', style: LqText.caption),
      data: (comments) => comments.isEmpty
          ? Text('첫 댓글을 남겨보세요', style: LqText.caption)
          : Column(
              children: [
                for (final comment in comments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProofAvatar(author: comment.author, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    comment.author.nickname,
                                    style: LqText.label.copyWith(
                                      color: LqColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    proofTimeLabel(comment.createdAt),
                                    style: LqText.caption,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(comment.content, style: LqText.bodySm),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: LqColors.surfaceRaised,
        border: Border(top: BorderSide(color: LqColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              style: LqText.bodySm,
              decoration: const InputDecoration(
                hintText: '응원이나 궁금한 점을 남겨보세요',
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: sending ? null : onSubmit,
            icon: Icon(
              Icons.send,
              color: sending ? LqColors.textMuted : LqColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
