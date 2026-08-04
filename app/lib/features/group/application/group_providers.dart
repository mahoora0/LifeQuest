import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
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
final groupChatProvider = FutureProvider.autoDispose
    .family<GroupMessagePage, int>(
      (ref, id) => ref.watch(groupRepositoryProvider).messages(id),
    );
