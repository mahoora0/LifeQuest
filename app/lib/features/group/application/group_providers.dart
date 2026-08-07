import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/features/group/application/group_chat_controller.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/group/data/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(ref.watch(dioProvider)),
);
final myGroupsProvider = FutureProvider<List<GroupSummary>>(
  (ref) => ref.watch(groupRepositoryProvider).myGroups(),
);
final groupInvitationsProvider = FutureProvider<List<GroupMember>>(
  (ref) => ref.watch(groupRepositoryProvider).invitations(),
);
final groupDetailProvider = FutureProvider.family<GroupDetail, int>(
  (ref, id) => ref.watch(groupRepositoryProvider).detail(id),
);
final groupMembersProvider = FutureProvider.family<List<GroupMember>, int>(
  (ref, id) => ref.watch(groupRepositoryProvider).members(id),
);
final groupJoinRequestsProvider = FutureProvider.family<List<GroupMember>, int>(
  (ref, id) => ref.watch(groupRepositoryProvider).joinRequests(id),
);
final upcomingGroupQuestsProvider =
    FutureProvider.family<List<GroupQuest>, int>(
      (ref, id) =>
          ref.watch(groupRepositoryProvider).quests(id, upcoming: true),
    );
final pastGroupQuestsProvider = FutureProvider.family<List<GroupQuest>, int>(
  (ref, id) => ref.watch(groupRepositoryProvider).quests(id, upcoming: false),
);
final myCoopGroupQuestsProvider = FutureProvider<List<GroupQuest>>((ref) async {
  final repository = ref.watch(groupRepositoryProvider);
  final pages = await Future.wait([
    repository.myQuests(upcoming: true),
    repository.myQuests(upcoming: false),
  ]);
  final quests = [
    ...pages[0],
    ...pages[1],
  ].where((quest) => quest.status != GroupQuestStatus.cancelled).toList();
  quests.sort((a, b) {
    if (a.status == GroupQuestStatus.published &&
        b.status != GroupQuestStatus.published) {
      return -1;
    }
    if (a.status != GroupQuestStatus.published &&
        b.status == GroupQuestStatus.published) {
      return 1;
    }
    return a.scheduledAt.compareTo(b.scheduledAt);
  });
  return quests;
});
final groupChatProvider = Provider.autoDispose.family<GroupChatController, int>(
  (ref, id) {
    final controller = GroupChatController(
      repository: ref.watch(groupRepositoryProvider),
      groupId: id,
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
);
