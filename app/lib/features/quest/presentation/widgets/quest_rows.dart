import 'package:flutter/material.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';

/// 홈(S-07)의 오늘의 퀘스트 행.
///
/// SELF_REPORT는 우측 원형 체크 버튼으로 즉시 완료,
/// LOCATION은 체크 대신 `위치 인증` 뱃지를 두고 행 전체 탭으로 상세로 보낸다.
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
    final completed = dailyQuest.status.isCompleted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: completed ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LqText.cardTitle.copyWith(
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        LqRewardBadge.exp(quest.expReward),
                        if (LqFeatures.currencyEnabled)
                          LqRewardBadge.gold(quest.expReward ~/ 2),
                        if (quest.completionType.isLocation)
                          LqRewardBadge.location(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (quest.completionType.isLocation)
                const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: LqColors.textMuted,
                )
              else
                QuestCheckButton(
                  checked: completed,
                  busy: busy,
                  onTap: (completed || busy) ? null : onCheck,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 원형 체크 버튼(27) — 완료 시 `expBadge` 배경 + ✓.
class QuestCheckButton extends StatelessWidget {
  const QuestCheckButton({
    super.key,
    required this.checked,
    this.busy = false,
    this.onTap,
  });

  final bool checked;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: checked,
      label: '퀘스트 완료',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: LqSpacing.minTouchTarget,
          height: LqSpacing.minTouchTarget,
          child: Center(
            child: Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? LqColors.expBadge : LqColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: LqColors.ink,
                  width: LqShape.borderWidth,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LqColors.textMuted,
                      ),
                    )
                  : checked
                  ? const Icon(Icons.check, size: 16, color: LqColors.onDark)
                  : null,
            ),
          ),
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
    final completed = dailyQuest.status.isCompleted;

    return Opacity(
      opacity: completed ? 0.55 : 1,
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
                    LqRewardBadge.tag(quest.completionType.palette),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 22,
            color: LqColors.textMuted,
          ),
        ],
      ),
    );
  }
}

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
        color: LqColors.panel,
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
