import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/location/presentation/widgets/location_consent_prompts.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/features/quest/presentation/widgets/quest_rows.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

/// 퀘스트 목록 필터 — 주기(일간·주간·월간) 기준.
///
/// "전체" 칩은 두지 않는다. 진입 시 [daily]가 선택되고 항상 하나의 주기만 켜져 있다.
/// 위치 인증 여부는 필터가 아니라 카드 우측의 보조 뱃지로 남는다 — 주기와 완료 방식은
/// 별개의 축이라 한 축으로 다른 축을 대신할 수 없다.
enum _QuestFilter {
  daily(QuestCadence.daily),
  weekly(QuestCadence.weekly),
  monthly(QuestCadence.monthly);

  const _QuestFilter(this.cadence);

  final QuestCadence cadence;

  String get label => cadence.label;

  bool matches(DailyQuest quest) => quest.quest.cadence == cadence;
}

/// S-08 퀘스트 목록. 홈과 동일한 `todayQuestsProvider`를 재사용한다.
class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  /// 진입 시 일간이 선택된다("전체" 칩이 없어 기본값이 반드시 하나 있어야 한다).
  _QuestFilter _filter = _QuestFilter.daily;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayQuestsProvider);
    // 조회 전에는 개수를 모르므로 레이블에서 개수만 뺀다. 0개로 보이면 오해를 부른다.
    final loaded = today.value;
    final countLabel = loaded == null
        ? '${_filter.label} 퀘스트'
        : '${_filter.label} 퀘스트 · ${loaded.quests.where(_filter.matches).length}개';

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 헤더에 검색을 두지 않는다. 목록이 3~8개인 화면에 검색이 있으면
            // 데이터가 더 많아 보이는 오해를 주고, 이번 범위에 검색 기능이
            // 없어 눌러도 아무 일이 없는 컨트롤이 된다.
            const LqHeader(title: '퀘스트 목록', showBack: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(LqSpacing.screen, 0, 0, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(countLabel, style: LqText.label),
              ),
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
                // 홈과 같은 배정 API를 쓴다. 준비 중에는 재시도 버튼을 붙이지 않는다.
                notReadyMessage: '퀘스트 목록은 아직 준비 중이에요',
                notReadyHint: '배정이 열리면 주기별로 나눠 보여드려요.',
                onRetry: () => ref.read(todayQuestsProvider.notifier).refresh(),
                data: (value) => _QuestList(
                  quests: value.quests.where(_filter.matches).toList(),
                  emptyMessage: '오늘 배정된 ${_filter.label} 퀘스트가 없어요',
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

  Future<void> _openDetail(DailyQuest dailyQuest) async {
    // 위치 퀘스트를 눌렀을 때만 시트를 올린다(2b). 홈과 같은 규칙이다.
    await ensureLocationConsent(
      context,
      ref,
      isLocationQuest: dailyQuest.quest.completionType.isLocation,
    );

    if (!mounted) return;
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
    required this.emptyMessage,
    required this.onTap,
    required this.onRefresh,
  });

  final List<DailyQuest> quests;

  /// 배정은 있으나 선택한 주기에 해당하는 퀘스트가 없을 때의 문구.
  final String emptyMessage;
  final void Function(DailyQuest) onTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return LqEmptyView(message: emptyMessage);
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
