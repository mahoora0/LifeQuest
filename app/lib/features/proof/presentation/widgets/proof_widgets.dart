import 'package:flutter/material.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 판정 상태 배지의 색과 문구.
///
/// 거절 상태도 위험색을 쓰지 않는다 — 투표 결과가 EXP를 뺏지 않으므로 사용자가
/// 잃은 것이 없고, 붉은 경고는 실제보다 큰 처벌로 읽힌다.
({String label, Color background, Color border, Color text}) proofStatusStyle(
  ProofPost post,
) => switch (post.status) {
  ProofStatus.verified => (
    label: '인증 완료',
    background: LqColors.successBg,
    border: LqColors.primary,
    text: LqColors.successText,
  ),
  ProofStatus.unclear => (
    label: '의견이 갈렸어요',
    background: LqColors.surfaceTint,
    border: LqColors.borderMuted,
    text: LqColors.textSecondary,
  ),
  ProofStatus.rejected => (
    label: '확인이 어려워요',
    background: LqColors.warnBg,
    border: LqColors.goldBorder,
    text: LqColors.warnText,
  ),
  ProofStatus.voting => (
    label: '투표 중 ${post.decidedVoteCount}/${post.minVotes}',
    background: LqColors.goldBg,
    border: LqColors.goldBorder,
    text: LqColors.goldText,
  ),
};

class ProofStatusBadge extends StatelessWidget {
  const ProofStatusBadge({super.key, required this.post});

  final ProofPost post;

  @override
  Widget build(BuildContext context) {
    final style = proofStatusStyle(post);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: LqShape.pillRadius,
        border: Border.all(color: style.border),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: style.text,
        ),
      ),
    );
  }
}

/// 퀘스트명 배지. 완료 기록에서 따라온 값이라 사용자가 편집할 수 없다.
class ProofQuestBadge extends StatelessWidget {
  const ProofQuestBadge({
    super.key,
    required this.title,
    this.grade,
    this.categoryLabel,
  });

  final String title;
  final String? grade;
  final String? categoryLabel;

  static const _gradeColors = <String, Color>{
    'NORMAL': LqColors.gradeNormal,
    'RARE': LqColors.gradeRare,
    'EPIC': LqColors.gradeEpic,
    'LEGENDARY': LqColors.gradeLegendary,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _gradeColors[grade] ?? LqColors.gradeNormal;
    return Row(
      children: [
        Container(width: 4, height: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LqText.cardTitle,
          ),
        ),
        if (categoryLabel != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: LqColors.surfaceRaised,
              borderRadius: LqShape.pillRadius,
              border: Border.all(color: LqColors.borderMuted),
            ),
            child: Text(categoryLabel!, style: LqText.caption),
          ),
        ],
      ],
    );
  }
}

/// 인증 사진 캐러셀. 정사각으로 고정해 카드 높이가 사진 비율에 따라 들쭉날쭉해지지 않게 한다.
class ProofPhotoCarousel extends StatefulWidget {
  const ProofPhotoCarousel({super.key, required this.photoUrls});

  final List<String> photoUrls;

  @override
  State<ProofPhotoCarousel> createState() => _ProofPhotoCarouselState();
}

class _ProofPhotoCarouselState extends State<ProofPhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: LqShape.cardRadius,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photoUrls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => Image.network(
                widget.photoUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: LqColors.lockedTile,
                  alignment: Alignment.center,
                  child: Text('사진을 불러오지 못했어요', style: LqText.caption),
                ),
              ),
            ),
          ),
        ),
        if (widget.photoUrls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.photoUrls.length; index++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _index
                        ? LqColors.primary
                        : LqColors.borderMuted,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 투표 결과 막대. 유효표가 없으면 비율 대신 안내를 보여준다 —
/// 0%로 그리면 모두가 반대한 것처럼 읽힌다.
class ProofVoteResultBar extends StatelessWidget {
  const ProofVoteResultBar({super.key, required this.post});

  final ProofPost post;

  @override
  Widget build(BuildContext context) {
    final ratio = post.agreeRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ratio == null)
          Text('아직 판단할 수 있는 표가 없어요', style: LqText.caption)
        else ...[
          ClipRRect(
            borderRadius: LqShape.pillRadius,
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: LqColors.lockedTile,
              valueColor: const AlwaysStoppedAnimation(LqColors.expFill),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '인증 맞아요 ${(ratio * 100).round()}% · 유효 ${post.decidedVoteCount}표',
            style: LqText.caption,
          ),
        ],
        if (post.unsureCount > 0) ...[
          const SizedBox(height: 2),
          Text('판단하기 어려워요 ${post.unsureCount}표', style: LqText.caption),
        ],
        if (post.myVote != null) ...[
          const SizedBox(height: 6),
          Text(
            '내 선택: ${post.myVote!.label}',
            style: LqText.label.copyWith(color: LqColors.primary),
          ),
        ],
      ],
    );
  }
}

/// 3지선다 투표 버튼. 카드 안에서 바로 누를 수 있어야 참여율이 유지된다 —
/// 상세로 들어갔다 나와야 하면 대부분 투표하지 않고 스크롤을 계속한다.
class ProofVoteButtons extends StatelessWidget {
  const ProofVoteButtons({super.key, required this.onVote, this.busy = false});

  final ValueChanged<ProofVoteChoice> onVote;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final choice in ProofVoteChoice.values) ...[
          Expanded(
            child: _VoteButton(
              choice: choice,
              onTap: busy ? null : () => onVote(choice),
            ),
          ),
          if (choice != ProofVoteChoice.values.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.choice, this.onTap});

  final ProofVoteChoice choice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? LqColors.surfaceRaised : LqColors.disabledBg,
          borderRadius: LqShape.pillRadius,
          border: Border.all(
            color: enabled ? LqColors.ink : LqColors.borderMuted,
            width: LqShape.borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          choice.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: enabled ? LqColors.textPrimary : LqColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class ProofAvatar extends StatelessWidget {
  const ProofAvatar({super.key, required this.author, this.size = 32});

  final ProofAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = author.profileImageUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? _initial()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initial(),
              ),
      ),
    );
  }

  Widget _initial() => Container(
    color: LqColors.tileFill,
    alignment: Alignment.center,
    child: Text(
      author.nickname.isEmpty ? '?' : author.nickname.substring(0, 1),
      style: LqText.label.copyWith(color: LqColors.textPrimary),
    ),
  );
}

/// "2시간 전" 같은 상대 시각. 서버가 문구를 주지 않는 응답이라 앱에서 만든다.
String proofTimeLabel(DateTime createdAt) {
  final elapsed = DateTime.now().difference(createdAt);
  if (elapsed.inMinutes < 1) return '방금';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}분 전';
  if (elapsed.inHours < 24) return '${elapsed.inHours}시간 전';
  if (elapsed.inDays < 7) return '${elapsed.inDays}일 전';
  return '${createdAt.month}월 ${createdAt.day}일';
}
