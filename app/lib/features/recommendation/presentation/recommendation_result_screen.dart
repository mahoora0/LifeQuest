import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 추천 결과 3건.
///
/// 주간 퀘스트로 받을 수 있는지는 화면 인자가 아니라 후보의 `candidateId` 유무로 판단한다
/// (`isClaimable`). 서버가 저장한 후보에만 id가 붙으므로, 모드 플래그를 따로 나르면
/// 그 플래그와 서버 상태가 어긋날 수 있다.
class RecommendationResultScreen extends ConsumerStatefulWidget {
  const RecommendationResultScreen({required this.result, super.key});

  final QuestRecommendationResult result;

  @override
  ConsumerState<RecommendationResultScreen> createState() => _State();
}

class _State extends ConsumerState<RecommendationResultScreen> {
  /// 진행 중인 선택의 후보 id. 주에 한 번뿐이라 두 카드가 동시에 눌리면 안 된다.
  int? _claiming;

  Future<void> _claim(QuestRecommendationCandidate candidate) async {
    final candidateId = candidate.candidateId;
    if (candidateId == null || _claiming != null) return;

    setState(() => _claiming = candidateId);
    try {
      await ref
          .read(todayQuestsProvider.notifier)
          .claimWeeklyAiQuest(candidateId);
      if (!mounted) return;
      showLqSnack(context, '주간 퀘스트로 받았어요');
      // 목록의 주간 탭으로 보낸다. 기본 탭이 일간이라 그냥 돌아가면 방금 받은
      // 퀘스트가 보이지 않아 실패한 것처럼 읽힌다.
      context.go('/quests?tab=weekly');
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.result.candidates;
    final claimable = candidates.any((c) => c.isClaimable);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '추천 결과'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: LqColors.warnBg,
                      borderRadius: LqShape.rowRadius,
                    ),
                    child: Text(
                      claimable
                          ? '하나를 골라 이번 주 주간 퀘스트로 받을 수 있어요. 장소 운영 여부와 실제 비용은 방문 전에 확인해 주세요.'
                          : '장소 운영 여부와 실제 비용은 방문 전에 확인해 주세요.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final c in candidates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LqCard(
                        header: '${c.index}. ${c.title}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.description, style: LqText.body),
                            const SizedBox(height: 8),
                            Text(
                              '장소 · ${c.suggestedPlaceName}',
                              style: LqText.label,
                            ),
                            Text(
                              '예상 시간 · ${c.durationValue} ${c.durationUnit == 'DAYS' ? '일' : '분'}',
                              style: LqText.label,
                            ),
                            Text(
                              '예상 비용 · ${c.estimatedCostPerPerson}원/인',
                              style: LqText.label,
                            ),
                            const SizedBox(height: 8),
                            Text(c.completionGuide, style: LqText.caption),
                            if (c.isClaimable) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: LqButton(
                                  label: '주간 퀘스트로 받기',
                                  busy: _claiming == c.candidateId,
                                  // 하나를 고르는 동안 나머지도 잠근다 — 주에 한 번뿐이라
                                  // 두 번째 요청은 어차피 409로 끝난다.
                                  onPressed: _claiming == null
                                      ? () => _claim(c)
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  Text(
                    '오늘 남은 추천 ${widget.result.remainingRequestsToday}회 · ${widget.result.model}',
                    textAlign: TextAlign.center,
                    style: LqText.caption,
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
