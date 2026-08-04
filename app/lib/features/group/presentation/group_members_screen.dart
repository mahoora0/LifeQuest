import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class GroupMembersScreen extends ConsumerStatefulWidget {
  const GroupMembersScreen({required this.groupId, super.key});
  final int groupId;
  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersState();
}

class _GroupMembersState extends ConsumerState<GroupMembersScreen> {
  final search = TextEditingController();
  List<GroupUserLookup> results = const [];
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (search.text.trim().isEmpty) return;
    try {
      final value = await ref
          .read(groupRepositoryProvider)
          .searchUsers(search.text.trim());
      if (mounted) setState(() => results = value);
    } catch (e) {
      if (mounted) showLqError(context, e);
    }
  }

  Future<void> _invite(int userId) async {
    try {
      await ref.read(groupRepositoryProvider).invite(widget.groupId, userId);
      if (mounted) showLqSnack(context, '초대를 보냈어요');
    } catch (e) {
      if (mounted) showLqError(context, e);
    }
  }

  Future<void> _act(GroupMember member, bool transfer) async {
    try {
      final repo = ref.read(groupRepositoryProvider);
      if (transfer) {
        await repo.transfer(widget.groupId, member.userId);
      } else {
        await repo.remove(widget.groupId, member.userId);
      }
      ref.invalidate(groupMembersProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      // 위임은 목록의 내 역할을, 내보내기는 멤버 수를 바꾼다. 둘 다 목록까지 갱신해야 한다.
      ref.invalidate(myGroupsProvider);
    } catch (e) {
      if (mounted) showLqError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(widget.groupId)).value;
    final value = ref.watch(groupMembersProvider(widget.groupId));
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '그룹 멤버'),
            if (detail?.isOwner == true && detail?.archived == false)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: search,
                            onSubmitted: (_) => _find(),
                            decoration: const InputDecoration(
                              labelText: '닉네임으로 초대 대상 검색',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: LqButton(label: '검색', onPressed: _find),
                        ),
                      ],
                    ),
                    for (final user in results)
                      ListTile(
                        title: Text(user.nickname),
                        subtitle: Text('Lv. ${user.level}'),
                        trailing: TextButton(
                          onPressed: () => _invite(user.id),
                          child: const Text('초대'),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: LqAsyncView<List<GroupMember>>(
                value: value,
                isEmpty: (items) => items.isEmpty,
                emptyMessage: '멤버가 없어요',
                onRetry: () =>
                    ref.invalidate(groupMembersProvider(widget.groupId)),
                data: (items) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = items[index];
                    return LqCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.nickname, style: LqText.cardTitle),
                                Text(
                                  member.role == GroupRole.owner ? '그룹장' : '멤버',
                                  style: LqText.caption,
                                ),
                              ],
                            ),
                          ),
                          if (detail?.isOwner == true &&
                              member.role != GroupRole.owner)
                            PopupMenuButton<bool>(
                              onSelected: (transfer) => _act(member, transfer),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: true,
                                  child: Text('그룹장 위임'),
                                ),
                                PopupMenuItem(
                                  value: false,
                                  child: Text('내보내기'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
