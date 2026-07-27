import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';

/// S-12 퀘스트 완료 결과.
///
/// 완료 응답 객체를 `extra`로 받아 그대로 렌더링한다(재호출 없음).
/// 탭 밖 push 라우트라 하단 탭바는 표시되지 않는다.
class QuestResultScreen extends StatelessWidget {
  const QuestResultScreen({super.key, required this.result});

  final QuestCompletionResult result;

  @override
  Widget build(BuildContext context) {
    final growth = result.growth;

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: Stack(
        children: [
          const Positioned.fill(child: _FloatingConfetti()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      LqSpacing.screen,
                      24,
                      LqSpacing.screen,
                      16,
                    ),
                    children: [
                      Center(
                        child: Transform.rotate(
                          angle: -2 * 3.1415926535 / 180,
                          child: LqCard(
                            background: LqColors.surfaceCard,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 10,
                            ),
                            child: Text(
                              result.duplicated ? '이미 완료한 퀘스트예요' : '퀘스트 완료!',
                              style: LqText.bigTitle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Center(
                        child: LqImage(LqAssets.charWalk, width: 158),
                      ),
                      const SizedBox(height: 18),
                      if (result.questTitle != null)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: LqColors.surfaceRaised,
                              borderRadius: LqShape.pillRadius,
                              border: Border.all(
                                color: LqColors.ink,
                                width: LqShape.borderWidth,
                              ),
                            ),
                            child: Text(
                              result.questTitle!,
                              style: LqText.cardTitle,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 멱등 재요청이면 보상이 재지급되지 않으므로 안내만 남긴다.
                      if (result.duplicated)
                        const _Notice(
                          message: '이미 완료 처리된 퀘스트라 보상은 다시 지급되지 않았어요.',
                        )
                      else
                        _RewardRow(growth: growth),

                      if (!result.duplicated && growth.levelUp) ...[
                        const SizedBox(height: LqSpacing.gap),
                        _LevelUpPanel(growth: growth),
                      ],

                      if (result.collection.newLifedexItems.isNotEmpty) ...[
                        const SizedBox(height: LqSpacing.gap),
                        for (final item in result.collection.newLifedexItems)
                          _CollectionNotice(
                            message: "LifeDex '${item.name}' 도장이 새로 찍혔어요",
                          ),
                      ],
                      if (result.collection.newAchievements.isNotEmpty) ...[
                        const SizedBox(height: LqSpacing.gap),
                        for (final item in result.collection.newAchievements)
                          _CollectionNotice(
                            message: "업적 '${item.name}' 을(를) 달성했어요",
                          ),
                      ],
                      if (result.location?.distanceM != null) ...[
                        const SizedBox(height: LqSpacing.gap),
                        Center(
                          child: Text(
                            '인증 거리 ${result.location!.distanceM!.round()}m',
                            style: LqText.caption,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LqSpacing.screen,
                    0,
                    LqSpacing.screen,
                    16,
                  ),
                  child: LqButton(
                    label: '확인',
                    onPressed: () => context.go('/'),
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

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.growth});

  final GrowthResult growth;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Text('획득한 보상', style: LqText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              LqRewardBadge(
                label: 'EXP ${growth.expGained}',
                background: LqColors.expBadge,
                foreground: LqColors.onDark,
                fontSize: 14,
              ),
              // ② 연속 달성 보너스는 서버 판정이 필요해 v1에서 제외.
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelUpPanel extends StatelessWidget {
  const _LevelUpPanel({required this.growth});

  final GrowthResult growth;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        children: [
          const LqStamp(label: 'LEVEL UP', angleDegrees: -3, fontSize: 14),
          const SizedBox(height: 10),
          Text(
            'Lv.${growth.previousLevel} → Lv.${growth.currentLevel}',
            style: LqText.levelNumber,
          ),
          if (growth.rewards.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final reward in growth.rewards)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  reward.isTitle
                      ? '칭호 · ${reward.name}'
                      : '아이템 · ${reward.name}',
                  style: LqText.bodySm,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CollectionNotice extends StatelessWidget {
  const _CollectionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LqCard(
        locked: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const LqImage(LqAssets.iconBackpack, width: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: LqText.bodySm)),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      locked: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: LqText.bodySm.copyWith(color: LqColors.textSecondary),
      ),
    );
  }
}

/// 배경에 떠다니는 색상 조각 4개(시안의 `lqFloat` 애니메이션).
class _FloatingConfetti extends StatelessWidget {
  const _FloatingConfetti();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            left: 26,
            top: 96,
            child: _FloatingPiece(
              color: LqColors.gold,
              size: 16,
              circle: false,
              seconds: 2.4,
            ),
          ),
          Positioned(
            right: 32,
            top: 138,
            child: _FloatingPiece(
              color: LqColors.accent,
              size: 13,
              circle: true,
              seconds: 3.1,
            ),
          ),
          Positioned(
            left: 44,
            bottom: 168,
            child: _FloatingPiece(
              color: LqColors.gem,
              size: 14,
              circle: true,
              seconds: 2.7,
            ),
          ),
          Positioned(
            right: 40,
            bottom: 210,
            child: _FloatingPiece(
              color: LqColors.gold,
              size: 12,
              circle: false,
              seconds: 2.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingPiece extends StatefulWidget {
  const _FloatingPiece({
    required this.color,
    required this.size,
    required this.circle,
    required this.seconds,
  });

  final Color color;
  final double size;
  final bool circle;
  final double seconds;

  @override
  State<_FloatingPiece> createState() => _FloatingPieceState();
}

class _FloatingPieceState extends State<_FloatingPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.seconds * 1000).round()),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -10 * Curves.easeInOut.transform(_controller.value)),
        child: child,
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circle ? null : BorderRadius.circular(3),
          border: Border.all(color: LqColors.ink, width: 1.8),
        ),
      ),
    );
  }
}
