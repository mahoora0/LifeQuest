import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/features/quest/presentation/widgets/quest_rows.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_progress_bar.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// S-07 홈 / 오늘의 퀘스트.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 완료 요청 중인 배정 건 — 같은 행의 중복 탭을 막는다.
  final _completing = <int>{};

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final level = ref.watch(levelStatusProvider);
    final today = ref.watch(todayQuestsProvider);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: LqColors.primary,
          backgroundColor: LqColors.surfaceRaised,
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            ref.invalidate(levelStatusProvider);
            await ref.read(todayQuestsProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              LqSpacing.screen,
              8,
              LqSpacing.screen,
              24,
            ),
            children: [
              const _LogoRow(),
              const SizedBox(height: LqSpacing.gap),
              _Greeting(profile: profile),
              const SizedBox(height: LqSpacing.gap),
              _LevelCard(level: level),
              const SizedBox(height: LqSpacing.gap),
              _TodayQuestCard(
                today: today,
                completing: _completing,
                onOpen: _openDetail,
                onCheck: _completeSelfReport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(DailyQuest dailyQuest) {
    context.push(
      '/quests/${dailyQuest.questId}',
      extra: QuestDetailArgs(
        dailyQuestId: dailyQuest.dailyQuestId,
        status: dailyQuest.status,
      ),
    );
  }

  /// SELF_REPORT 즉시 완료 — 본문 없이 호출하고 완료 결과 화면으로 이동한다.
  Future<void> _completeSelfReport(DailyQuest dailyQuest) async {
    if (_completing.contains(dailyQuest.dailyQuestId)) return;
    setState(() => _completing.add(dailyQuest.dailyQuestId));

    try {
      final result = await ref
          .read(todayQuestsProvider.notifier)
          .complete(dailyQuest.dailyQuestId);
      if (!mounted) return;
      context.push('/quests/result', extra: result);
    } catch (error) {
      if (!mounted) return;
      showLqError(context, error);
      // 실패했으므로 서버 상태로 되돌린다.
      await ref.read(todayQuestsProvider.notifier).refresh();
    } finally {
      if (mounted) {
        setState(() => _completing.remove(dailyQuest.dailyQuestId));
      }
    }
  }
}

class _LogoRow extends StatelessWidget {
  const _LogoRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const LqImage(LqAssets.logoChar, width: 30),
        const SizedBox(width: 8),
        Text(
          'Life Quest',
          style: LqText.screenTitle.copyWith(color: LqColors.primary),
        ),
        const Spacer(),
        // 알림은 이번 범위에서 시각 요소만 둔다(알림 화면 미구현).
        const LqIconButton(
          icon: Icons.notifications_none,
          size: 26,
          iconSize: 15,
          showDot: true,
          semanticLabel: '알림',
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final AsyncValue<UserProfile> profile;

  @override
  Widget build(BuildContext context) {
    final nickname = profile.value?.nickname ?? '모험가';

    return Row(
      children: [
        Expanded(
          child: Text(
            '안녕하세요, $nickname님!\n오늘도 멋진 하루가 될 거예요!',
            style: LqText.cardTitle.copyWith(
              fontWeight: FontWeight.w400,
              color: LqColors.textBody,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const LqImage(LqAssets.charWave, width: 62),
      ],
    );
  }
}

class _LevelCard extends ConsumerWidget {
  const _LevelCard({required this.level});

  final AsyncValue<LevelStatus> level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;
    if (level.hasError && !level.isLoading) {
      body = _LevelError(
        message: lqErrorMessage(level.error!),
        onRetry: () => ref.invalidate(levelStatusProvider),
      );
    } else if (level.hasValue) {
      body = _LevelBody(status: level.requireValue);
    } else {
      body = const _LevelPlaceholder();
    }

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: body,
    );
  }
}

class _LevelBody extends StatelessWidget {
  const _LevelBody({required this.status});

  final LevelStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Lv. ${status.level}', style: LqText.levelNumber),
            const SizedBox(width: 10),
            Text(
              'EXP ${status.currentLevelExp} / ${status.nextLevelRequiredExp}',
              style: LqText.label,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LqProgressBar(
          value: status.currentLevelExp,
          max: status.nextLevelRequiredExp,
        ),
        // ① 골드·보석 재화 칸은 서버에 재화가 없어 v1에서 노출하지 않는다.
      ],
    );
  }
}

class _LevelPlaceholder extends StatelessWidget {
  const _LevelPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 62,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: LqColors.primary,
          ),
        ),
      ),
    );
  }
}

class _LevelError extends StatelessWidget {
  const _LevelError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          Expanded(child: Text(message, style: LqText.caption)),
          TextButton(
            onPressed: onRetry,
            child: Text(
              '다시 시도',
              style: LqText.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: LqColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayQuestCard extends ConsumerWidget {
  const _TodayQuestCard({
    required this.today,
    required this.completing,
    required this.onOpen,
    required this.onCheck,
  });

  final AsyncValue<TodayQuests> today;
  final Set<int> completing;
  final void Function(DailyQuest) onOpen;
  final void Function(DailyQuest) onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = today.value;

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: const BoxDecoration(
                  color: LqColors.primary,
                  borderRadius: LqShape.pillRadius,
                ),
                child: Text(
                  '오늘의 퀘스트',
                  style: LqText.badge.copyWith(
                    fontSize: 14,
                    color: LqColors.onDark,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                loaded == null
                    ? '—'
                    : '${loaded.completedCount} / ${loaded.total}',
                style: LqText.cardTitle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            // 로딩·빈·오류 상태는 카드 안에서 일정한 높이를 차지하게 한다.
            // 고정 높이가 아니라 최소 높이인 이유: 오류 상태는 캐릭터(108) + 문구 +
            // "다시 시도" 버튼 + 상하 패딩(48)이 쌓여 250을 넘긴다. 고정하면 잘린다.
            // 글꼴 크기 설정이나 문구 길이에 따라서도 높이가 달라지므로 상한을 두지 않는다.
            constraints: BoxConstraints(
              minHeight: (loaded?.quests.isNotEmpty ?? false) ? 0 : 250,
            ),
            child: LqAsyncView<TodayQuests>(
              value: today,
              isEmpty: (value) => value.isEmpty,
              emptyMessage: '오늘 배정된 퀘스트가 없어요',
              emptyAsset: LqAssets.charSit,
              onRetry: () => ref.read(todayQuestsProvider.notifier).refresh(),
              data: (value) => Column(
                children: [
                  for (var i = 0; i < value.quests.length; i++) ...[
                    if (i > 0) const LqDashedDivider(),
                    HomeQuestRow(
                      dailyQuest: value.quests[i],
                      busy: completing.contains(value.quests[i].dailyQuestId),
                      onTap: () => onOpen(value.quests[i]),
                      onCheck: () => onCheck(value.quests[i]),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '체크해 보세요 — EXP가 바로 올라요',
                    style: LqText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
