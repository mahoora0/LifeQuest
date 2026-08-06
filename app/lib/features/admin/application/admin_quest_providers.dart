import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/admin/data/admin_quest.dart';
import 'package:life_quest/features/admin/data/admin_quest_repository.dart';

final adminQuestRepositoryProvider = Provider<AdminQuestRepository>((ref) {
  return AdminQuestRepository(ref.watch(dioProvider));
});

final adminQuestsProvider =
    AsyncNotifierProvider.autoDispose<AdminQuestsNotifier, List<AdminQuest>>(
      AdminQuestsNotifier.new,
    );

class AdminQuestsNotifier extends AsyncNotifier<List<AdminQuest>> {
  @override
  Future<List<AdminQuest>> build() {
    return ref.watch(adminQuestRepositoryProvider).fetchQuests();
  }

  Future<void> save(AdminQuestDraft draft, {int? id}) async {
    final repository = ref.read(adminQuestRepositoryProvider);
    if (id == null) {
      await repository.create(draft);
    } else {
      await repository.update(id, draft);
    }
    state = AsyncData(await repository.fetchQuests());
  }

  Future<void> deactivate(int id) async {
    await ref.read(adminQuestRepositoryProvider).deactivate(id);
    state = AsyncData([
      for (final quest in state.value ?? const <AdminQuest>[])
        if (quest.id == id)
          AdminQuest(
            id: quest.id,
            title: quest.title,
            description: quest.description,
            grade: quest.grade,
            cadence: quest.cadence,
            completionType: quest.completionType,
            expReward: quest.expReward,
            active: false,
            placeName: quest.placeName,
            latitude: quest.latitude,
            longitude: quest.longitude,
            radiusM: quest.radiusM,
          )
        else
          quest,
    ]);
  }
}
