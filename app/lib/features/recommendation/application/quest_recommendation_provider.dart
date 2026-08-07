import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_repository.dart';

final questRecommendationRepositoryProvider =
    Provider<QuestRecommendationRepository>(
      (ref) => QuestRecommendationRepository(ref.watch(dioProvider)),
    );

/// 주간 AI 슬롯 상태. 추천 진입 화면과 여행 폼이 함께 본다.
///
/// `autoDispose`인 이유는 이 값이 주 단위로 바뀌고 선택 직후에도 바뀌기 때문이다.
/// 화면을 벗어나면 버려서, 다시 들어올 때 서버에 새로 묻게 한다.
final weeklyAiQuestStatusProvider =
    FutureProvider.autoDispose<WeeklyAiQuestStatus>(
      (ref) => ref.watch(questRecommendationRepositoryProvider).weeklyStatus(),
    );
