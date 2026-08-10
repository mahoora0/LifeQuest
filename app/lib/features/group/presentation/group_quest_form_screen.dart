import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/presentation/date_labels.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class GroupQuestFormScreen extends ConsumerStatefulWidget {
  const GroupQuestFormScreen({required this.groupId, this.questId, super.key});
  final int groupId;
  final int? questId;
  @override
  ConsumerState<GroupQuestFormScreen> createState() => _State();
}

class _State extends ConsumerState<GroupQuestFormScreen> {
  final title = TextEditingController(),
      description = TextEditingController(),
      place = TextEditingController();

  /// 최대 참여 인원. 비워 두면 정원 없이 그룹 멤버 누구나 신청할 수 있다.
  final maxParticipants = TextEditingController();

  DateTime scheduled = DateTime.now().add(const Duration(days: 1));
  bool busy = false, loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.questId != null && !loaded) {
      loaded = true;
      ref
          .read(groupRepositoryProvider)
          .quest(widget.groupId, widget.questId!)
          .then((q) {
            if (!mounted) return;
            title.text = q.title;
            description.text = q.description;
            place.text = q.placeName;
            maxParticipants.text = q.maxParticipants?.toString() ?? '';
            setState(() => scheduled = q.scheduledAt);
          });
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    place.dispose();
    maxParticipants.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: scheduled,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduled),
    );
    if (time != null) {
      setState(
        () => scheduled = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> submit() async {
    final t = title.text.trim(),
        d = description.text.trim(),
        p = place.text.trim(),
        capacityText = maxParticipants.text.trim();
    // 빈 칸은 "정원 없음"이고, 값을 넣었는데 2~100을 벗어나면 서버가 거절한다.
    final capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);
    if (capacityText.isNotEmpty &&
        (capacity == null || capacity < 2 || capacity > 100)) {
      showLqSnack(context, '최대 인원은 2~100명 사이로 적어 주세요');
      return;
    }
    if (t.length < 2 ||
        t.length > 100 ||
        d.isEmpty ||
        d.length > 1000 ||
        p.isEmpty ||
        p.length > 200 ||
        !scheduled.isAfter(DateTime.now())) {
      showLqSnack(context, '제목·설명·장소와 미래 일시를 확인해 주세요');
      return;
    }
    setState(() => busy = true);
    try {
      final q = await ref
          .read(groupRepositoryProvider)
          .saveQuest(
            widget.groupId,
            questId: widget.questId,
            title: t,
            description: d,
            placeName: p,
            scheduledAt: scheduled,
            maxParticipants: capacity,
          );
      ref.invalidate(upcomingGroupQuestsProvider(widget.groupId));
      ref.invalidate(pastGroupQuestsProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      if (mounted) context.go('/groups/${widget.groupId}/quests/${q.id}');
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LqColors.surfacePanel,
    body: SafeArea(
      child: Column(
        children: [
          LqHeader(title: widget.questId == null ? '그룹 퀘스트 만들기' : '그룹 퀘스트 편집'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: title,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                TextField(
                  controller: description,
                  maxLength: 1000,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
                TextField(
                  controller: place,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: '장소'),
                ),
                TextField(
                  controller: maxParticipants,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최대 인원',
                    helperText: '비워 두면 인원 제한 없이 신청받아요 (2~100명)',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('일시'),
                  subtitle: Text(
                    '${scheduled.year}년 ${questDateTimeLabel(scheduled)}',
                  ),
                  trailing: TextButton(
                    onPressed: pick,
                    child: const Text('변경'),
                  ),
                ),
                LqButton(label: '저장', busy: busy, onPressed: submit),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
