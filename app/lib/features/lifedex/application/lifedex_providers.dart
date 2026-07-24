import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';

final lifedexRepositoryProvider = Provider<LifedexRepository>((ref) {
  return LifedexRepository(ref.watch(dioProvider));
});

final lifedexOverviewProvider = FutureProvider<LifedexOverview>((ref) {
  return ref.watch(lifedexRepositoryProvider).fetchOverview();
});

/// 카테고리 상세 항목(S-14).
final lifedexItemsProvider = FutureProvider.family<List<LifedexItem>, int>((
  ref,
  categoryId,
) {
  return ref.watch(lifedexRepositoryProvider).fetchItems(categoryId);
});
