import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/location/presentation/widgets/location_consent_prompts.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/features/quest/presentation/widgets/quest_rows.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

/// 퀘스트 목록 필터 — 일간·주간·협동 기준.
///
/// "전체" 칩은 두지 않는다. 진입 시 [daily]가 선택되고 항상 하나의 주기만 켜져 있다.
/// 위치 인증 여부는 필터가 아니라 카드 우측의 보조 뱃지로 남는다 — 주기와 완료 방식은
/// 별개의 축이라 한 축으로 다른 축을 대신할 수 없다.
enum _QuestFilter {
  daily(QuestCadence.daily, '일간', 1),
  weekly(QuestCadence.weekly, '주간', 3),
  coop(null, '협동', 5);

  const _QuestFilter(this.cadence, this.label, this.requiredLevel);

  final QuestCadence? cadence;
  final String label;
  final int requiredLevel;

  bool matches(DailyQuest quest) =>
      cadence != null && quest.quest.cadence == cadence;
}

/// S-08 퀘스트 목록. 홈과 동일한 `todayQuestsProvider`를 재사용한다.
class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({this.initialTab, super.key});

  /// 진입 시 열어둘 탭(`daily`·`weekly`·`coop`). AI 퀘스트를 받은 직후 목록으로
  /// 돌아올 때 기본값인 일간이 뜨면 방금 받은 퀘스트가 보이지 않아 실패한 것처럼
  /// 읽힌다. 값이 없거나 모르는 값이면 기존대로 일간이다.
  final String? initialTab;

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  /// 트랙당 슬롯 수. 주간은 이 중 둘만 자동으로 차고 나머지 하나가 AI 슬롯이다.
  static const _weeklySlots = 3;

  /// 진입 시 일간이 선택된다("전체" 칩이 없어 기본값이 반드시 하나 있어야 한다).
  late _QuestFilter _filter = switch (widget.initialTab) {
    'weekly' => _QuestFilter.weekly,
    'coop' => _QuestFilter.coop,
    _ => _QuestFilter.daily,
  };

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayQuestsProvider);
    final level = ref.watch(levelStatusProvider);
    final levelValue = level.value;
    final unlocked = switch (_filter) {
      _QuestFilter.daily => true,
      _QuestFilter.weekly => levelValue?.unlocks.weekly.unlocked ?? false,
      _QuestFilter.coop => levelValue?.unlocks.coop.unlocked ?? false,
    };
    // 조회 전에는 개수를 모르므로 레이블에서 개수만 뺀다. 0개로 보이면 오해를 부른다.
    final loaded = today.value;
    final countLabel = loaded == null || !unlocked
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
            LqHeader(
              title: '퀘스트 목록',
              showBack: false,
              trailing: LqIconButton(
                icon: Icons.auto_awesome,
                semanticLabel: 'AI 퀘스트 추천',
                onTap: () => context.push('/quest-recommendations'),
              ),
            ),
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
              child: !unlocked && _filter != _QuestFilter.daily
                  ? _QuestLockedView(
                      requiredLevel: _filter.requiredLevel,
                      currentLevel: levelValue?.level,
                      levelLoadFailed: level.hasError,
                    )
                  : _filter == _QuestFilter.coop
                  ? const LqEmptyView(
                      message: '협동 퀘스트 목록은 아직 준비 중이에요',
                      hint: 'Lv. 5 해금 정보는 적용됐고, 퀘스트 담당 API 연결을 기다리고 있어요.',
                    )
                  : LqAsyncView<TodayQuests>(
                      value: today,
                      isEmpty: (value) => value.isEmpty,
                      emptyMessage: '오늘 배정된 퀘스트가 없어요',
                      // 홈과 같은 배정 API를 쓴다. 준비 중에는 재시도 버튼을 붙이지 않는다.
                      notReadyMessage: '퀘스트 목록은 아직 준비 중이에요',
                      notReadyHint: '배정이 열리면 주기별로 나눠 보여드려요.',
                      onRetry: () =>
                          ref.read(todayQuestsProvider.notifier).refresh(),
                      data: (value) => _QuestList(
                        quests: value.quests.where(_filter.matches).toList(),
                        emptyMessage: '오늘 배정된 ${_filter.label} 퀘스트가 없어요',
                        // 주간 세 번째 자리는 자동 배정이 채우지 않는다 — 사용자가
                        // AI 추천에서 직접 고르는 슬롯이고, 비어 있을 때만 안내한다.
                        showWeeklyAiSlot:
                            _filter == _QuestFilter.weekly &&
                            _weeklyAiSlotOpen(value.quests),
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

  /// 주간 AI 슬롯이 비어 있는가.
  ///
  /// **자리가 남았는지까지 본다.** "AI 퀘스트가 없다"만 보면, 자동 배정이 3개를
  /// 채운 주에도 카드가 떠서 네 번째 줄이 된다 — 슬롯 규칙이 바뀌기 전에 만들어진
  /// 이번 주 배정이 그렇고, 받아도 서버가 거절할 자리를 권하는 셈이 된다.
  /// 다음 주기부터는 자동이 2개라 자연히 열린다.
  bool _weeklyAiSlotOpen(List<DailyQuest> quests) {
    final weekly = quests
        .where((q) => q.quest.cadence == QuestCadence.weekly)
        .toList();
    return weekly.length < _weeklySlots && !weekly.any((q) => q.quest.isAiGenerated);
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

class _QuestLockedView extends StatelessWidget {
  const _QuestLockedView({
    required this.requiredLevel,
    this.currentLevel,
    required this.levelLoadFailed,
  });
  final int requiredLevel;
  final int? currentLevel;
  final bool levelLoadFailed;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: LqCard(
        locked: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: LqColors.textMuted, size: 36),
            const SizedBox(height: 12),
            Text('Lv. $requiredLevel에 열려요', style: LqText.cardTitle),
            const SizedBox(height: 6),
            Text(
              levelLoadFailed
                  ? '레벨 정보를 불러오지 못했어요'
                  : currentLevel == null
                  ? '레벨 확인 중이에요'
                  : '현재 Lv. $currentLevel',
              style: LqText.caption,
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuestList extends StatelessWidget {
  const _QuestList({
    required this.quests,
    required this.emptyMessage,
    required this.onTap,
    required this.onRefresh,
    this.showWeeklyAiSlot = false,
  });

  final List<DailyQuest> quests;

  /// 주간 AI 슬롯이 비어 있어 "퀘스트 받기" 카드를 띄울 것인가.
  final bool showWeeklyAiSlot;

  /// 배정은 있으나 선택한 주기에 해당하는 퀘스트가 없을 때의 문구.
  final String emptyMessage;
  final void Function(DailyQuest) onTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // 슬롯 카드가 있으면 목록이 비어도 빈 화면을 띄우지 않는다 — 받을 수 있는
    // 자리가 있는데 "배정된 퀘스트가 없어요"만 보이면 막다른 길로 읽힌다.
    if (quests.isEmpty && !showWeeklyAiSlot) {
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
        itemCount: quests.length + (showWeeklyAiSlot ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == quests.length) {
            return const _WeeklyAiSlotCard();
          }
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

/// 주간 세 번째 자리 — 사용자가 AI 추천 중에서 직접 고르는 슬롯.
///
/// 자동 배정은 슬롯 A(위치)·B(직접 완료) 두 개만 만들고 이 자리는 비워 둔다.
/// 주에 한 번만 받을 수 있다.
class _WeeklyAiSlotCard extends StatelessWidget {
  const _WeeklyAiSlotCard();

  @override
  Widget build(BuildContext context) => LqCard(
    radius: LqShape.rowRadius,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    onTap: () => context.push('/quest-recommendations?weekly=true'),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome, color: LqColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('나만의 주간 퀘스트', style: LqText.cardTitle),
              const SizedBox(height: 2),
              Text(
                'AI가 상황에 맞춰 추천해요 · 주 1회',
                style: LqText.caption,
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: LqColors.textMuted),
      ],
    ),
  );
}
