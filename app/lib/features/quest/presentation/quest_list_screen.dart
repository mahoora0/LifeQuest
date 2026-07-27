import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/features/quest/presentation/widgets/quest_rows.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

/// 퀘스트 목록 필터 (07 명세 §6-③ 제안값).
///
/// 시안의 일간/주간/습관 칩은 서버에 해당 분류 필드가 없어
/// v1에서는 완료 방식 기준 3칩으로 대체한다.
enum _QuestFilter {
  all('전체'),
  selfReport('직접 완료'),
  location('위치');

  const _QuestFilter(this.label);

  final String label;

  bool matches(DailyQuest quest) => switch (this) {
    _QuestFilter.all => true,
    _QuestFilter.selfReport => !quest.quest.completionType.isLocation,
    _QuestFilter.location => quest.quest.completionType.isLocation,
  };
}

/// S-08 퀘스트 목록. 홈과 동일한 `todayQuestsProvider`를 재사용한다.
class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  _QuestFilter _filter = _QuestFilter.all;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayQuestsProvider);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LqHeader(
              title: '퀘스트 목록',
              showBack: false,
              // 검색은 이번 범위에서 시각 요소만 둔다.
              trailing: LqIconButton(icon: Icons.search, semanticLabel: '검색'),
            ),
            LqChipRow(
              labels: [for (final filter in _QuestFilter.values) filter.label],
              selectedIndex: _QuestFilter.values.indexOf(_filter),
              onSelected: (index) =>
                  setState(() => _filter = _QuestFilter.values[index]),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LqAsyncView<TodayQuests>(
                value: today,
                isEmpty: (value) => value.isEmpty,
                emptyMessage: '오늘 배정된 퀘스트가 없어요',
                onRetry: () => ref.read(todayQuestsProvider.notifier).refresh(),
                data: (value) => _QuestList(
                  quests: value.quests.where(_filter.matches).toList(),
                  onTap: _openDetail,
                  onRefresh: () =>
                      ref.read(todayQuestsProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
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
}

class _QuestList extends StatelessWidget {
  const _QuestList({
    required this.quests,
    required this.onTap,
    required this.onRefresh,
  });

  final List<DailyQuest> quests;
  final void Function(DailyQuest) onTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return const LqEmptyView(message: '이 조건에 맞는 퀘스트가 없어요');
    }

    return RefreshIndicator(
      color: LqColors.primary,
      backgroundColor: LqColors.surfaceRaised,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          LqSpacing.screen,
          8,
          LqSpacing.screen,
          24,
        ),
        itemCount: quests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final dailyQuest = quests[index];
          return LqCard(
            radius: LqShape.rowRadius,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            onTap: () => onTap(dailyQuest),
            child: QuestListRow(
              dailyQuest: dailyQuest,
              onTap: () => onTap(dailyQuest),
            ),
          );
        },
      ),
    );
  }
}
