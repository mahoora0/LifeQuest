import 'package:flutter/material.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

class RecommendationResultScreen extends StatelessWidget {
  const RecommendationResultScreen({required this.result, super.key});
  final QuestRecommendationResult result;
  @override
  Widget build(BuildContext context) => Scaffold(
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
                  child: const Text('장소 운영 여부와 실제 비용은 방문 전에 확인해 주세요.'),
                ),
                const SizedBox(height: 12),
                for (final c in result.candidates)
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
                        ],
                      ),
                    ),
                  ),
                Text(
                  '오늘 남은 추천 ${result.remainingRequestsToday}회 · ${result.model}',
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
