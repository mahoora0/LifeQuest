import 'package:flutter/material.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/presentation/widgets/proof_widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';

/// 피드의 인증 게시물 카드.
///
/// 투표 버튼이 카드 안에 있고 댓글만 상세로 넘어간다. 판단에 필요한 것(퀘스트명·사진·
/// 설명)은 카드에 다 있으므로, 투표하려고 화면을 옮길 이유가 없다.
class ProofCard extends StatelessWidget {
  const ProofCard({
    super.key,
    required this.post,
    required this.onVote,
    required this.onOpen,
    this.voting = false,
  });

  final ProofPost post;
  final ValueChanged<ProofVoteChoice> onVote;
  final VoidCallback onOpen;

  /// 투표 요청 진행 중 — 세 버튼을 함께 잠가 중복 전송을 막는다.
  final bool voting;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProofAvatar(author: post.author),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LqText.label.copyWith(color: LqColors.textPrimary),
                    ),
                    Text(proofTimeLabel(post.createdAt), style: LqText.caption),
                  ],
                ),
              ),
              ProofStatusBadge(post: post),
            ],
          ),
          const SizedBox(height: 10),
          ProofQuestBadge(title: post.questTitle, grade: post.questGrade),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onOpen,
            child: ProofPhotoCarousel(photoUrls: post.photoUrls),
          ),
          if (post.content != null && post.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.content!, maxLines: 3, style: LqText.bodySm),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: LqColors.divider),
          const SizedBox(height: 10),
          if (post.canVote)
            ProofVoteButtons(onVote: onVote, busy: voting)
          else
            ProofVoteResultBar(post: post),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                post.commentCount == 0
                    ? '댓글 남기기'
                    : '댓글 ${post.commentCount}개 보기',
                style: LqText.label.copyWith(color: LqColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
