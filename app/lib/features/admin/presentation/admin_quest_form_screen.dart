import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/admin/application/admin_quest_providers.dart';
import 'package:life_quest/features/admin/data/admin_quest.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class AdminQuestFormScreen extends ConsumerStatefulWidget {
  const AdminQuestFormScreen({super.key, this.quest});

  final AdminQuest? quest;

  @override
  ConsumerState<AdminQuestFormScreen> createState() =>
      _AdminQuestFormScreenState();
}

class _AdminQuestFormScreenState extends ConsumerState<AdminQuestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _exp;
  late final TextEditingController _place;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;
  late String _grade;
  late String _cadence;
  late String _completionType;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final quest = widget.quest;
    _title = TextEditingController(text: quest?.title);
    _description = TextEditingController(text: quest?.description);
    _exp = TextEditingController(text: quest?.expReward.toString() ?? '10');
    _place = TextEditingController(text: quest?.placeName);
    _latitude = TextEditingController(text: quest?.latitude?.toString());
    _longitude = TextEditingController(text: quest?.longitude?.toString());
    _radius = TextEditingController(text: quest?.radiusM?.toString());
    _grade = quest?.grade ?? 'NORMAL';
    _cadence = quest?.cadence ?? 'DAILY';
    _completionType = quest?.completionType ?? 'SELF_REPORT';
    _active = quest?.active ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _exp,
      _place,
      _latitude,
      _longitude,
      _radius,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gps = _completionType == 'GPS';
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            LqHeader(title: widget.quest == null ? '관리자 퀘스트 등록' : '관리자 퀘스트 수정'),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _field(_title, '제목', required: true),
                    _field(_description, '설명', lines: 3),
                    _dropdown('등급', _grade, const [
                      'NORMAL',
                      'RARE',
                      'EPIC',
                      'LEGENDARY',
                    ], (v) => setState(() => _grade = v)),
                    _dropdown('주기', _cadence, const [
                      'DAILY',
                      'WEEKLY',
                      'ONCE',
                    ], (v) => setState(() => _cadence = v)),
                    _dropdown(
                      '완료 방식',
                      _completionType,
                      const ['SELF_REPORT', 'GPS'],
                      (v) => setState(() => _completionType = v),
                    ),
                    _field(_exp, 'EXP 보상', required: true, number: true),
                    if (gps) ...[
                      _field(_place, '장소명', required: true),
                      _field(_latitude, '위도', required: true, number: true),
                      _field(_longitude, '경도', required: true, number: true),
                      _field(_radius, '인증 반경(m)', required: true, number: true),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('활성 상태'),
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                    const SizedBox(height: 12),
                    LqButton(
                      label: widget.quest == null ? '등록하기' : '저장하기',
                      busy: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? '$label을 입력하세요' : null
            : null,
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in items)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = AdminQuestDraft(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      grade: _grade,
      cadence: _cadence,
      completionType: _completionType,
      expReward: int.tryParse(_exp.text) ?? 0,
      active: _active,
      placeName: _place.text.trim().isEmpty ? null : _place.text.trim(),
      latitude: double.tryParse(_latitude.text),
      longitude: double.tryParse(_longitude.text),
      radiusM: int.tryParse(_radius.text),
    );
    setState(() => _saving = true);
    try {
      await ref
          .read(adminQuestsProvider.notifier)
          .save(draft, id: widget.quest?.id);
      if (mounted) {
        showLqSnack(
          context,
          widget.quest == null ? '퀘스트를 등록했어요' : '퀘스트를 수정했어요',
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
