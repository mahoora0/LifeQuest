import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/recommendation/application/quest_recommendation_provider.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_input_widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class PlaceRecommendationFormScreen extends ConsumerStatefulWidget {
  const PlaceRecommendationFormScreen({this.weekly = false, super.key});

  /// 주간 퀘스트 슬롯용이면 서버 경로가 다르다 — Lv.3 잠금과 남은 기간 제한이
  /// 걸리고, 그쪽에서만 후보가 저장돼 `candidateId`가 채워진다.
  final bool weekly;

  @override
  ConsumerState<PlaceRecommendationFormScreen> createState() => _State();
}

class _State extends ConsumerState<PlaceRecommendationFormScreen> {
  static const _interestOptions = [
    '맛집',
    '카페',
    '산책',
    '자연',
    '문화·전시',
    '운동',
    '체험',
    '쇼핑',
    '사진',
    '독서',
  ];

  final area = TextEditingController(),
      customMinutes = TextEditingController(),
      customBudget = TextEditingController(),
      customInterests = TextEditingController(),
      additional = TextEditingController();
  int? selectedMinutes = 180;
  int? selectedBudget = 30000;
  int companions = 1;
  final selectedInterests = <String>{};
  bool showCustomInterests = false;
  RecommendationEnvironment environment = RecommendationEnvironment.any;
  bool busy = false;

  void toggleInterest(String value) {
    if (selectedInterests.contains(value)) {
      setState(() => selectedInterests.remove(value));
      return;
    }
    if (selectedInterests.length >= 5) {
      showLqSnack(context, '관심사는 최대 5개까지 선택할 수 있어요');
      return;
    }
    setState(() => selectedInterests.add(value));
  }

  @override
  void dispose() {
    for (final c in [
      area,
      customMinutes,
      customBudget,
      customInterests,
      additional,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final a = area.text.trim(),
        m = selectedMinutes ?? int.tryParse(customMinutes.text),
        b = selectedBudget ?? int.tryParse(customBudget.text),
        tags = <String>{
          ...selectedInterests,
          if (showCustomInterests)
            ...customInterests.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
        }.toList();
    if (a.length < 2 ||
        a.length > 100 ||
        m == null ||
        m < 30 ||
        m > 720 ||
        b == null ||
        b < 0 ||
        b > 10000000 ||
        companions < 1 ||
        companions > 20 ||
        tags.length > 5 ||
        tags.any((e) => e.length > 30) ||
        additional.text.trim().length > 500) {
      showLqSnack(context, '지역·시간·예산·인원·관심사 입력 범위를 확인해 주세요');
      return;
    }
    setState(() => busy = true);
    try {
      final repository = ref.read(questRecommendationRepositoryProvider);
      final body = {
        'area': a,
        'availableMinutes': m,
        'budgetPerPerson': b,
        'companionCount': companions,
        'environment': environment.name.toUpperCase(),
        'interests': tags,
        'additionalRequest': additional.text.trim().isEmpty
            ? null
            : additional.text.trim(),
      };
      final r = widget.weekly
          ? await repository.weeklyPlace(body)
          : await repository.place(body);
      if (mounted) context.push('/quest-recommendations/result', extra: r);
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RecommendationForm(
    title: '장소 추천 조건',
    children: [
      TextField(
        controller: area,
        maxLength: 100,
        decoration: const InputDecoration(labelText: '지역 (예: 서울 성수동)'),
      ),
      RecommendationChoiceSection<int?>(
        label: '가능 시간',
        selected: selectedMinutes,
        options: const [
          RecommendationOption(30, '30분'),
          RecommendationOption(60, '1시간'),
          RecommendationOption(120, '2시간'),
          RecommendationOption(180, '3시간'),
          RecommendationOption(360, '반나절'),
          RecommendationOption(null, '직접 입력'),
        ],
        onSelected: (value) => setState(() => selectedMinutes = value),
        child: selectedMinutes == null
            ? TextField(
                controller: customMinutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '가능 시간 직접 입력',
                  suffixText: '분',
                  helperText: '30~720분',
                ),
              )
            : null,
      ),
      RecommendationChoiceSection<int?>(
        label: '1인 예산',
        selected: selectedBudget,
        options: const [
          RecommendationOption(0, '무료'),
          RecommendationOption(5000, '5천원 이하'),
          RecommendationOption(10000, '1만원 이하'),
          RecommendationOption(30000, '3만원 이하'),
          RecommendationOption(50000, '5만원 이하'),
          RecommendationOption(null, '직접 입력'),
        ],
        onSelected: (value) => setState(() => selectedBudget = value),
        child: selectedBudget == null
            ? TextField(
                controller: customBudget,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '1인 예산 직접 입력',
                  suffixText: '원',
                ),
              )
            : null,
      ),
      RecommendationCompanionStepper(
        value: companions,
        onChanged: (value) => setState(() => companions = value),
      ),
      RecommendationChoiceSection<RecommendationEnvironment>(
        label: '환경',
        selected: environment,
        options: const [
          RecommendationOption(RecommendationEnvironment.any, '상관없음'),
          RecommendationOption(RecommendationEnvironment.indoor, '실내'),
          RecommendationOption(RecommendationEnvironment.outdoor, '실외'),
        ],
        onSelected: (value) => setState(() => environment = value),
      ),
      RecommendationInterestPicker(
        options: _interestOptions,
        selected: selectedInterests,
        onToggle: toggleInterest,
        showCustomInput: showCustomInterests,
        onCustomInputChanged: (value) =>
            setState(() => showCustomInterests = value),
        customController: customInterests,
      ),
      TextField(
        controller: additional,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: '원하는 조건이 더 있나요? (선택)',
          hintText: '예: 조용하고 차분한 분위기',
        ),
      ),
      LqButton(label: '3개 추천받기', busy: busy, onPressed: submit),
    ],
  );
}

class RecommendationForm extends StatelessWidget {
  const RecommendationForm({
    required this.title,
    required this.children,
    super.key,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LqColors.surfacePanel,
    body: SafeArea(
      child: Column(
        children: [
          LqHeader(title: title),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}
