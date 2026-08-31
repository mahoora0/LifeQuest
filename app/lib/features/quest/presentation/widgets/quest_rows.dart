import 'package:flutter/material.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';
import 'package:life_quest/shared/widgets/lq_swipe_action.dart';

/// 홈(S-07)의 오늘의 퀘스트 행.
///
/// SELF_REPORT는 우측 원형 체크 버튼으로 즉시 완료,
/// LOCATION은 체크 대신 `위치 인증` 뱃지를 두고 행 전체 탭으로 상세로 보낸다.
///
/// 행은 시안대로 각자 `divider` 테두리를 두른 카드다. 배경은 지정하지 않고
/// 부모 카드의 `surfaceCard`를 그대로 쓴다 — 테두리만으로 경계를 만든다.
///
/// 좌측 아이콘 타일은 목록(S-08)과 같은 [_IconTile]이다. 퀘스트별 그림은
/// 서버가 주지 않으므로(`QUESTS.icon`이 스키마에 없다) 제목 첫 글자를 쓴다.
class HomeQuestRow extends StatelessWidget {
  const HomeQuestRow({
    super.key,
    required this.dailyQuest,
    required this.onTap,
    required this.onCheck,
    this.busy = false,
  });

  final DailyQuest dailyQuest;
  final VoidCallback onTap;
  final VoidCallback onCheck;

  /// 완료 요청 중 — 중복 탭 방지.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final quest = dailyQuest.quest;
    final status = dailyQuest.status;
    final completed = status.isCompleted;
    // 만료 건도 서버가 QUEST_EXPIRED로 거절하므로 완료와 같이 비활성으로 보인다.
    final inactive = !status.isActionable;

    // 흐림은 만료에만 준다. 완료는 해낸 일이라 선명하게 두고 취소선과 채워진
    // 체크로만 표시한다 — 둘을 같이 흐리면 "못 한 것"과 구분이 사라진다(시안).
    return Opacity(
      opacity: status.isExpired ? 0.55 : 1,
      // 옆으로 끌어서도 완료할 수 있다. 위치 퀘스트는 인증이 필요하므로 제외한다 —
      // 끌어서 끝낼 수 있을 것처럼 보이면 안 된다.
      child: LqSwipeAction(
        enabled: !inactive && !busy && !quest.completionType.isLocation,
        onCommit: onCheck,
        semanticLabel: '퀘스트 완료',
        background: (context, progress) => _SwipeHint(progress: progress),
        child: LqCard(
          background: LqColors.surfaceCard,
          borderColor: LqColors.divider,
          radius: LqShape.tileRadius,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IconTile(title: quest.title),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LqText.cardTitle.copyWith(
                        fontSize: 16,
                        height: 1.1,
                        fontWeight: FontWeight.w500,
                        // 완료한 줄은 취소선과 함께 글자도 한 단계 물린다.
                        color: completed ? LqColors.textSecondary : null,
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        LqRewardBadge.exp(quest.expReward),
                        if (LqFeatures.currencyEnabled)
                          LqRewardBadge.gold(quest.expReward ~/ 2),
                        // 홈 카드는 `GET /quests/today`가 주는 두 트랙을 한 목록으로
                        // 그린다(일간 3 + 주간 자동 2). 카드 제목 띠가 `오늘의 퀘스트`라
                        // 일간은 문맥이 이미 말하고 있으므로, 문맥에서 벗어나는 주간에만
                        // 표시를 붙인다 — 둘 다 붙이면 모든 행에 뱃지가 하나씩 늘어
                        // 좁은 홈 행에서 제목이 밀린다. 뱃지는 목록(S-08)이 쓰는 주기
                        // 뱃지를 그대로 쓴다.
                        if (quest.cadence == QuestCadence.weekly)
                          LqRewardBadge.tag(quest.cadence.palette),
                        if (quest.completionType.isLocation)
                          LqRewardBadge.location(),
                        if (status.isExpired) const _ExpiredBadge(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              if (quest.completionType.isLocation)
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: LqColors.textMuted,
                )
              else
                QuestCheckButton(
                  checked: completed,
                  busy: busy,
                  expReward: quest.expReward,
                  onTap: (inactive || busy) ? null : onCheck,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 행을 끌었을 때 뒤에서 드러나는 자리.
///
/// 임계값에 다다르면 체크가 또렷해진다 — 얼마나 더 가야 하는지 손이 알 수 있어야
/// 도중에 마음을 바꿀 수 있다.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(
          LqColors.surfaceCard,
          LqColors.expBadge,
          progress * 0.9,
        ),
        borderRadius: LqShape.tileRadius,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Opacity(
            opacity: progress,
            child: Transform.scale(
              scale: 0.7 + 0.3 * progress,
              child: const Icon(Icons.check, size: 20, color: LqColors.onDark),
            ),
          ),
        ),
      ),
    );
  }
}

/// 체크가 채워지는 연출의 길이.
///
/// 완료 직후 결과 화면으로 넘어가는 화면들은 이만큼 기다렸다 이동한다 —
/// 누른 자리에서 아무 일도 안 일어난 채 화면이 바뀌면, 방금 무엇을 눌러
/// 무엇이 됐는지가 연결되지 않는다.
const questCheckCelebration = Duration(milliseconds: 420);

/// 원형 체크 버튼(27) — 완료 시 `expBadge` 배경 + ✓.
///
/// 완료로 바뀌는 순간 원이 한 번 부풀었다 가라앉고 `+EXP`가 위로 떠오른다.
/// 보상을 받은 자리를 눈으로 확인시키는 것이 목적이다.
class QuestCheckButton extends StatefulWidget {
  const QuestCheckButton({
    super.key,
    required this.checked,
    this.busy = false,
    this.onTap,
    this.expReward,
  });

  final bool checked;
  final bool busy;
  final VoidCallback? onTap;

  /// 주면 완료 순간 `+EXP n`이 떠오른다.
  final int? expReward;

  @override
  State<QuestCheckButton> createState() => _QuestCheckButtonState();
}

class _QuestCheckButtonState extends State<QuestCheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LqMotion.emphasized,
  );

  @override
  void didUpdateWidget(QuestCheckButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 처음부터 완료였던 행(목록을 다시 열었을 때)은 연출하지 않는다.
    // 방금 해낸 것과 예전에 해낸 것은 다르다.
    if (!oldWidget.checked && widget.checked && !LqMotion.isReduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.expReward;

    return Semantics(
      button: true,
      checked: widget.checked,
      label: '퀘스트 완료',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: LqSpacing.minTouchTarget,
          height: LqSpacing.minTouchTarget,
          child: Stack(
            // 떠오르는 라벨이 버튼 밖으로 나가야 한다.
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (exp != null)
                Positioned(
                  top: 0,
                  child: _RisingExp(exp: exp, animation: _controller),
                ),
              Center(child: _circle()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 한 번 부풀었다 제자리로. 끝에서 다시 커지면 두 번 눌린 것처럼 보인다.
        final pop = _controller.value == 0 || _controller.value == 1
            ? 0.0
            : Curves.easeOut.transform(
                    (1 - (_controller.value * 2 - 1).abs()).clamp(0.0, 1.0),
                  ) *
                  0.3;
        return Transform.scale(scale: 1 + pop, child: child);
      },
      child: AnimatedContainer(
        duration: LqMotion.quick,
        curve: LqMotion.standard,
        width: 27,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.checked ? LqColors.expBadge : LqColors.surfaceRaised,
          shape: BoxShape.circle,
          border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
        ),
        child: widget.busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: LqColors.textMuted,
                ),
              )
            : widget.checked
            ? const Icon(Icons.check, size: 16, color: LqColors.onDark)
            : null,
      ),
    );
  }
}

/// 완료 순간 위로 떠오르며 사라지는 `+EXP n`.
class _RisingExp extends StatelessWidget {
  const _RisingExp({required this.exp, required this.animation});

  final int exp;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();
          return Opacity(
            // 떠오르며 흐려진다. 끝까지 선명하면 사라지는 게 아니라 잘린다.
            opacity: (1 - t) * (t < 0.15 ? t / 0.15 : 1),
            child: Transform.translate(
              offset: Offset(0, -22 * Curves.easeOut.transform(t)),
              child: child,
            ),
          );
        },
        child: Text(
          '+$exp',
          style: LqText.badge.copyWith(fontSize: 13, color: LqColors.expBadge),
        ),
      ),
    );
  }
}

/// 퀘스트 목록(S-08)의 행 — 아이콘 타일 + 제목/보상 + 분류 태그 + `›`.
class QuestListRow extends StatelessWidget {
  const QuestListRow({
    super.key,
    required this.dailyQuest,
    required this.onTap,
  });

  final DailyQuest dailyQuest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quest = dailyQuest.quest;
    final status = dailyQuest.status;
    final completed = status.isCompleted;
    final inactive = !status.isActionable;

    return Opacity(
      opacity: inactive ? 0.55 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IconTile(title: quest.title),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        quest.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LqText.cardTitle,
                      ),
                    ),
                    if (completed) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: LqColors.expBadge,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    LqRewardBadge.exp(quest.expReward),
                    // 주기 뱃지와 위치 뱃지는 별개의 축이라 함께 붙을 수 있다
                    // (예: "새로운 카페 방문하기" = 주간 + 위치).
                    LqRewardBadge.tag(quest.cadence.palette),
                    if (quest.completionType.isLocation)
                      LqRewardBadge.tag(LqTagPalette.location),
                    if (status.isExpired) const _ExpiredBadge(),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 22, color: LqColors.textMuted),
        ],
      ),
    );
  }
}

/// 만료 표시 — 완료와 구분해 "왜 누를 수 없는지"를 알린다.
class _ExpiredBadge extends StatelessWidget {
  const _ExpiredBadge();

  @override
  Widget build(BuildContext context) {
    return LqRewardBadge(
      label: '만료',
      background: LqColors.lockedTile,
      foreground: LqColors.textMuted,
      border: LqColors.borderMuted,
    );
  }
}

/// 행 좌측의 38 정사각 타일 — 홈([HomeQuestRow])과 목록([QuestListRow])이 함께 쓴다.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LqColors.surfaceTint,
        borderRadius: LqShape.tileRadius,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: Text(
        title.isEmpty ? '?' : title.characters.first,
        style: LqText.cardTitle.copyWith(fontSize: 18),
      ),
    );
  }
}
