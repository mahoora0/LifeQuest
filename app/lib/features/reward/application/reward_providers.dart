import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/reward/data/reward_dto.dart';
import 'package:life_quest/features/reward/data/reward_repository.dart';

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  return const RewardRepository();
});

/// S-05 레벨 · 보상.
final rewardOverviewProvider = FutureProvider<RewardOverview>((ref) {
  return ref.watch(rewardRepositoryProvider).fetchOverview();
});
