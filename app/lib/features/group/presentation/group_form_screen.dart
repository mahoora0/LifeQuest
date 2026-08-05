import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.groupId});
  final int? groupId;
  @override
  ConsumerState<GroupFormScreen> createState() => _State();
}

class _State extends ConsumerState<GroupFormScreen> {
  final name = TextEditingController(),
      description = TextEditingController(),
      max = TextEditingController(text: '10');
  GroupVisibility visibility = GroupVisibility.public;
  bool busy = false, loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.groupId != null && !loaded) {
      loaded = true;
      ref.read(groupRepositoryProvider).detail(widget.groupId!).then((g) {
        if (!mounted) return;
        name.text = g.name;
        description.text = g.description;
        max.text = '${g.maxMembers}';
        setState(() => visibility = g.visibility);
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    max.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final n = name.text.trim(),
        d = description.text.trim(),
        m = int.tryParse(max.text);
    if (n.length < 2 ||
        n.length > 100 ||
        d.isEmpty ||
        d.length > 500 ||
        m == null ||
        m < 2 ||
        m > 100) {
      showLqSnack(context, '이름 2~100자, 설명 1~500자, 정원 2~100명을 확인해 주세요');
      return;
    }
    setState(() => busy = true);
    try {
      final repo = ref.read(groupRepositoryProvider);
      final g = widget.groupId == null
          ? await repo.create(
              name: n,
              description: d,
              visibility: visibility,
              maxMembers: m,
            )
          : await repo.update(
              widget.groupId!,
              name: n,
              description: d,
              visibility: visibility,
              maxMembers: m,
            );
      ref.invalidate(myGroupsProvider);
      ref.invalidate(groupDetailProvider(g.id));
      if (mounted) context.go('/groups/${g.id}');
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹을 보관할까요?'),
        content: const Text('보관 후에는 그룹 활동을 다시 시작할 수 없고, 기존 기록만 조회할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('보관'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.groupId == null || !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(groupRepositoryProvider).archive(widget.groupId!);
      ref.invalidate(myGroupsProvider);
      ref.invalidate(groupDetailProvider(widget.groupId!));
      if (mounted) {
        context.go('/groups');
      }
    } catch (error) {
      if (mounted) {
        showLqError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LqColors.surfacePanel,
    body: SafeArea(
      child: Column(
        children: [
          LqHeader(title: widget.groupId == null ? '그룹 만들기' : '그룹 편집'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: name,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '그룹 이름'),
                ),
                TextField(
                  controller: description,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
                TextField(
                  controller: max,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '최대 인원 (2~100)'),
                ),
                SwitchListTile(
                  value: visibility == GroupVisibility.public,
                  onChanged: (v) => setState(
                    () => visibility = v
                        ? GroupVisibility.public
                        : GroupVisibility.private,
                  ),
                  title: const Text('공개 검색 허용'),
                ),
                const SizedBox(height: 16),
                LqButton(
                  label: widget.groupId == null ? '그룹 만들기' : '변경 저장',
                  busy: busy,
                  onPressed: submit,
                ),
                if (widget.groupId != null) ...[
                  const SizedBox(height: 12),
                  LqButton(
                    label: '그룹 보관',
                    busy: busy,
                    shadow: false,
                    background: LqColors.surfaceCard,
                    foreground: LqColors.textPrimary,
                    borderColor: LqColors.borderMuted,
                    onPressed: archive,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
