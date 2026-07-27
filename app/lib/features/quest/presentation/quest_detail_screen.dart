import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// S-09 퀘스트 상세.
class QuestDetailScreen extends ConsumerStatefulWidget {
  const QuestDetailScreen({super.key, required this.questId, this.args});

  final int questId;

  /// 목록/홈에서 함께 넘어온 배정 정보(`dailyQuestId`, `status`).
  final QuestDetailArgs? args;

  @override
  ConsumerState<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends ConsumerState<QuestDetailScreen> {
  bool _completing = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(questDetailProvider(widget.questId));
    // extra로 받은 배정 정보는 진입 시점의 스냅샷이라 갱신되지 않는다.
    // GPS 인증으로 완료하고 뒤로 돌아오면 여기서 다시 읽어야 최신 상태가 된다.
    final assignment = ref
        .watch(todayQuestsProvider)
        .value
        ?.findAssignment(
          dailyQuestId: widget.args?.dailyQuestId,
          questId: widget.questId,
        );

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(),
            Expanded(
              child: LqAsyncView<Quest>(
                value: detail,
                onRetry: () =>
                    ref.invalidate(questDetailProvider(widget.questId)),
                data: (quest) => _DetailBody(
                  quest: quest,
                  status: assignment?.status ?? widget.args?.status,
                  dailyQuestId:
                      assignment?.dailyQuestId ?? widget.args?.dailyQuestId,
                  completing: _completing,
                  onComplete: () => _complete(quest),
                  onVerify: () => _goVerify(quest),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 현재 유효한 배정 id — 최신 상태를 우선하고 없으면 진입 인자를 쓴다.
  int? get _dailyQuestId =>
      ref
          .read(todayQuestsProvider)
          .value
          ?.findAssignment(
            dailyQuestId: widget.args?.dailyQuestId,
            questId: widget.questId,
          )
          ?.dailyQuestId ??
      widget.args?.dailyQuestId;

  /// SELF_REPORT 완료 — 본문 없이 호출.
  Future<void> _complete(Quest quest) async {
    final dailyQuestId = _dailyQuestId;
    if (dailyQuestId == null || _completing) return;

    setState(() => _completing = true);
    try {
      final result = await ref
          .read(todayQuestsProvider.notifier)
          .complete(dailyQuestId);
      if (!mounted) return;
      // 상세를 결과 화면으로 교체해 뒤로가기 시 목록으로 돌아가게 한다.
      context.pushReplacement('/quests/result', extra: result);
    } catch (error) {
      if (!mounted) return;
      showLqError(context, error);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _goVerify(Quest quest) {
    final dailyQuestId = _dailyQuestId;
    if (dailyQuestId == null) return;
    context.push(
      '/quests/$dailyQuestId/verify',
      extra: QuestVerifyArgs(quest: quest),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.quest,
    required this.status,
    required this.dailyQuestId,
    required this.completing,
    required this.onComplete,
    required this.onVerify,
  });

  final Quest quest;
  final DailyQuestStatus? status;
  final int? dailyQuestId;
  final bool completing;
  final VoidCallback onComplete;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final isLocation = quest.completionType.isLocation;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              LqSpacing.screen,
              4,
              LqSpacing.screen,
              16,
            ),
            children: [
              Center(child: LqRewardBadge.tag(quest.completionType.palette)),
              const SizedBox(height: 10),
              Text(
                quest.title,
                textAlign: TextAlign.center,
                style: LqText.displayTitle,
              ),
              const SizedBox(height: 14),
              Center(
                child: LqImage(
                  isLocation ? LqAssets.charMap : LqAssets.charSit,
                  width: 150,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                quest.description ?? '오늘 이 퀘스트를 완료하고 경험치를 모아 보세요.',
                textAlign: TextAlign.center,
                style: LqText.body,
              ),
              const SizedBox(height: LqSpacing.gap),
              _InfoCard(quest: quest),
              // ⑤ 진행형(누적) 게이지는 API가 1회 완료 모델이라 v1 제외.
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
          child: _Cta(
            quest: quest,
            status: status,
            dailyQuestId: dailyQuestId,
            completing: completing,
            onComplete: onComplete,
            onVerify: onVerify,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final isLocation = quest.completionType.isLocation;

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          _InfoRow(
            label: '보상',
            child: Wrap(
              spacing: 6,
              children: [
                LqRewardBadge.exp(quest.expReward),
                if (LqFeatures.currencyEnabled)
                  LqRewardBadge.gold(quest.expReward ~/ 2),
              ],
            ),
          ),
          if (isLocation) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: LqDashedDivider(),
            ),
            _InfoRow(
              label: '장소',
              child: Text(
                quest.placeName ?? '지정된 장소',
                style: LqText.bodySm.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: LqDashedDivider(),
            ),
            _InfoRow(
              label: '인증 반경',
              child: Text(
                // 반경을 모르면 추측하지 않고 서버 판정에 맡긴다는 것을 그대로 알린다.
                quest.hasRadius ? '${quest.radiusM}m' : '서버에서 확인',
                style: LqText.bodySm.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: LqText.label),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: child),
        ),
      ],
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({
    required this.quest,
    required this.status,
    required this.dailyQuestId,
    required this.completing,
    required this.onComplete,
    required this.onVerify,
  });

  final Quest quest;
  final DailyQuestStatus? status;
  final int? dailyQuestId;
  final bool completing;
  final VoidCallback onComplete;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (status?.isCompleted ?? false) {
      return const LqButton(label: '오늘 완료했어요 ✓');
    }
    if (status?.isExpired ?? false) {
      return const LqButton(label: '만료된 퀘스트예요');
    }
    if (dailyQuestId == null) {
      // 오늘 배정되지 않은 퀘스트를 직접 열어본 경우.
      return const LqButton(label: '오늘 배정된 퀘스트가 아니에요');
    }
    if (quest.completionType.isLocation) {
      return LqButton(label: '위치 인증하러 가기', onPressed: onVerify);
    }
    return LqButton(label: '완료하기', busy: completing, onPressed: onComplete);
  }
}
