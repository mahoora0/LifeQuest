import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_repository.dart';

final questRecommendationRepositoryProvider =
    Provider<QuestRecommendationRepository>(
      (ref) => QuestRecommendationRepository(ref.watch(dioProvider)),
    );
