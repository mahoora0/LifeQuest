import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/achievement/data/achievement_repository.dart';

final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  return AchievementRepository(ref.watch(dioProvider));
});

final achievementOverviewProvider = FutureProvider<AchievementOverview>((ref) {
  return ref.watch(achievementRepositoryProvider).fetchOverview();
});
