import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/widgets/secret_achievement_modal.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/features/proof/presentation/proof_form_args.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';

/// S-12 퀘스트 완료 결과.
///
/// 완료 응답 객체를 `extra`로 받아 그대로 렌더링한다(재호출 없음).
/// 탭 밖 push 라우트라 하단 탭바는 표시되지 않는다.
class QuestResultScreen extends ConsumerStatefulWidget {
  const QuestResultScreen({super.key, required this.result});

  final QuestCompletionResult result;

  @override
  ConsumerState<QuestResultScreen> createState() => _QuestResultScreenState();
}

class _QuestResultScreenState extends ConsumerState<QuestResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showResultEvents();
    });
  }

  Future<void> _showResultEvents() async {
    final result = widget.result;
    if (!result.duplicated && result.growth.levelUp) {
      ref.invalidate(levelStatusProvider);
      ref.invalidate(characterCollectionProvider);
      ref.invalidate(accessoryCollectionProvider);
      ref.invalidate(myProfileProvider);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: LqColors.ink.withValues(alpha: 0.45),
        builder: (dialogContext) => _LevelUpDialog(
          growth: result.growth,
          onConfirm: () => Navigator.of(dialogContext).pop(),
        ),
      );
    }

    if (!mounted) return;
    final secrets = result.collection.newSecretAchievements;
    if (secrets.isNotEmpty) {
      await showSecretAchievementModals(context, secrets);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
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
                            message: "도감에 '${item.name}' 도장이 새로 찍혔어요",
                          ),
                      ],
                      // 비밀 업적은 모달이 맡으므로 줄로 중복해 알리지 않는다.
                      if (result
                          .collection
                          .newPlainAchievements
                          .isNotEmpty) ...[
                        const SizedBox(height: LqSpacing.gap),
                        for (final item
                            in result.collection.newPlainAchievements)
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
                  // 인증 사진을 올릴 마음이 제일 큰 순간이 바로 여기다 — 방금 그 장소에
                  // 있었고 사진도 방금 찍었다. 홈으로 돌아간 뒤에 다시 들어와 올리는
                  // 사람은 거의 없으므로 주 버튼을 이쪽에 준다.
                  //
                  // 중복 완료(duplicated)는 이미 게시물이 있을 수 있어 권하지 않는다.
                  child: Column(
                    children: [
                      if (!result.duplicated)
                        LqButton(
                          label: '인증 사진 올리기',
                          onPressed: () => context.pushReplacement(
                            '/proofs/new',
                            extra: ProofFormArgs(
                              completionId: result.completionId,
                              questTitle: result.questTitle,
                              questGrade: result.grade,
                            ),
                          ),
                        ),
                      if (!result.duplicated) const SizedBox(height: 8),
                      LqButton(
                        label: '확인',
                        background: LqColors.surfaceRaised,
                        foreground: LqColors.textPrimary,
                        borderColor: LqColors.borderMuted,
                        shadow: result.duplicated,
                        onPressed: () => context.go('/'),
                      ),
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
    final unlocks = _newlyUnlockedFeatures(
      growth.previousLevel,
      growth.currentLevel,
    );

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
          if (unlocks.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: LqColors.borderMuted, height: 1),
            const SizedBox(height: 12),
            Text('새 기능 해금', style: LqText.label),
            const SizedBox(height: 8),
            for (final unlock in unlocks)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: LqColors.surfaceRaised,
                    borderRadius: LqShape.cardRadius,
                    border: Border.all(
                      color: LqColors.ink,
                      width: LqShape.borderWidth,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        size: 22,
                        color: LqColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(unlock.name, style: LqText.bodySm),
                            const SizedBox(height: 2),
                            Text(
                              unlock.description,
                              style: LqText.caption.copyWith(
                                color: LqColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LevelUnlock {
  const _LevelUnlock({
    required this.requiredLevel,
    required this.name,
    required this.description,
  });

  final int requiredLevel;
  final String name;
  final String description;
}

const _levelUnlocks = [
  _LevelUnlock(
    requiredLevel: 3,
    name: '주간 퀘스트',
    description: '한 주 동안 도전하는 퀘스트를 시작할 수 있어요.',
  ),
  _LevelUnlock(
    requiredLevel: 5,
    name: '그룹 퀘스트',
    description: '다른 모험가와 함께 퀘스트에 도전할 수 있어요.',
  ),
];

List<_LevelUnlock> _newlyUnlockedFeatures(
  int previousLevel,
  int currentLevel,
) => _levelUnlocks
    .where(
      (unlock) =>
          previousLevel < unlock.requiredLevel &&
          currentLevel >= unlock.requiredLevel,
    )
    .toList(growable: false);

List<AvatarCharacter> _newlyUnlockedCharacters(
  List<AvatarCharacter> characters,
  int previousLevel,
  int currentLevel,
) => characters
    .where(
      (character) =>
          previousLevel < character.requiredLevel &&
          currentLevel >= character.requiredLevel,
    )
    .toList(growable: false);

List<AvatarAccessory> _newlyUnlockedAccessories(
  List<AvatarAccessory> accessories,
  int previousLevel,
  int currentLevel,
) => accessories
    .where(
      (accessory) =>
          accessory.requiredLevel != null &&
          previousLevel < accessory.requiredLevel! &&
          currentLevel >= accessory.requiredLevel!,
    )
    .toList(growable: false);

int _crossedAccessoryLevels(int previousLevel, int currentLevel) {
  var count = 0;
  for (var level = 2; level <= 28; level += 2) {
    if (previousLevel < level && currentLevel >= level) count++;
  }
  return count;
}

class _LevelUpDialog extends ConsumerWidget {
  const _LevelUpDialog({required this.growth, required this.onConfirm});

  final GrowthResult growth;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureUnlocks = _newlyUnlockedFeatures(
      growth.previousLevel,
      growth.currentLevel,
    );
    final expectedAccessories = _crossedAccessoryLevels(
      growth.previousLevel,
      growth.currentLevel,
    );
    final characters = ref.watch(characterCollectionProvider);
    final characterUnlocks = _newlyUnlockedCharacters(
      characters.value ?? const <AvatarCharacter>[],
      growth.previousLevel,
      growth.currentLevel,
    );
    final accessories = ref.watch(accessoryCollectionProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: LqCard(
        background: LqColors.surfaceCard,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 620),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LqStamp(
                  label: 'LEVEL UP!',
                  angleDegrees: -3,
                  fontSize: 16,
                ),
                const SizedBox(height: 14),
                Text('Lv.${growth.currentLevel}', style: LqText.levelNumber),
                const SizedBox(height: 4),
                Text(
                  'Lv.${growth.previousLevel}에서 한 단계 성장했어요!',
                  style: LqText.bodySm,
                  textAlign: TextAlign.center,
                ),
                if (growth.rewards.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('획득 보상', style: LqText.label),
                  const SizedBox(height: 6),
                  for (final reward in growth.rewards)
                    _LevelUpUnlockLine(
                      icon: reward.isTitle
                          ? Icons.workspace_premium_rounded
                          : Icons.redeem_rounded,
                      title: reward.name,
                      subtitle: reward.isTitle ? '새 칭호 획득' : '새 아이템 획득',
                    ),
                ],
                if (featureUnlocks.isNotEmpty ||
                    characterUnlocks.isNotEmpty ||
                    expectedAccessories > 0) ...[
                  const SizedBox(height: 16),
                  Text('새로 해금됐어요', style: LqText.label),
                  const SizedBox(height: 6),
                  for (final unlock in featureUnlocks)
                    _LevelUpUnlockLine(
                      icon: Icons.lock_open_rounded,
                      title: unlock.name,
                      subtitle: unlock.description,
                    ),
                  for (final character in characterUnlocks)
                    _LevelUpUnlockLine(
                      leading: LqImage(
                        LqAssets.character(character.code),
                        key: ValueKey('unlocked-character-${character.id}'),
                        width: 32,
                        height: 32,
                      ),
                      title: character.name,
                      subtitle: '새 캐릭터 해금',
                    ),
                  if (expectedAccessories > 0)
                    accessories.when(
                      data: (collection) {
                        final unlocked = _newlyUnlockedAccessories(
                          collection.accessories,
                          growth.previousLevel,
                          growth.currentLevel,
                        );
                        if (unlocked.isEmpty && expectedAccessories > 0) {
                          return const _LevelUpUnlockLine(
                            icon: Icons.checkroom_rounded,
                            title: '새 액세서리',
                            subtitle: '캐릭터 꾸미기에서 확인할 수 있어요.',
                          );
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final accessory in unlocked)
                              _LevelUpUnlockLine(
                                icon: Icons.checkroom_rounded,
                                title: accessory.name,
                                subtitle: '새 액세서리 해금',
                              ),
                          ],
                        );
                      },
                      loading: () => const _LevelUpUnlockLine(
                        icon: Icons.checkroom_rounded,
                        title: '새 액세서리',
                        subtitle: '해금된 액세서리를 확인하고 있어요.',
                      ),
                      error: (_, _) => const _LevelUpUnlockLine(
                        icon: Icons.checkroom_rounded,
                        title: '새 액세서리',
                        subtitle: '캐릭터 꾸미기에서 확인할 수 있어요.',
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                LqButton(label: '확인', onPressed: onConfirm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelUpUnlockLine extends StatelessWidget {
  const _LevelUpUnlockLine({
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
  }) : assert(icon != null || leading != null);

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: LqColors.surfaceRaised,
          borderRadius: LqShape.cardRadius,
          border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
        ),
        child: Row(
          children: [
            leading ?? Icon(icon, size: 22, color: LqColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: LqText.bodySm),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: LqText.caption.copyWith(
                      color: LqColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
