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
    final level = ref.watch(levelStatusProvider);
    final levelValue = level.value;
    final unlocked = switch (_filter) {
      _QuestFilter.daily => true,
      _QuestFilter.weekly => levelValue?.unlocks.weekly.unlocked ?? false,
      _QuestFilter.coop => levelValue?.unlocks.coop.unlocked ?? false,
    };
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
