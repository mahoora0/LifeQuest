import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/recommendation/application/quest_recommendation_provider.dart';
import 'package:life_quest/features/recommendation/presentation/place_recommendation_form_screen.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_input_widgets.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class TravelRecommendationFormScreen extends ConsumerStatefulWidget {
  const TravelRecommendationFormScreen({this.weekly = false, super.key});

  /// 주간 퀘스트 슬롯용이면 기간 상한이 14일이 아니라 그 주의 남은 일수다.
  /// 상한 판정은 서버가 하므로 여기서 미리 깎지 않는다 — 앱이 계산하면
  /// 04:00 경계에서 서버와 어긋난다.
  final bool weekly;

  @override
  ConsumerState<TravelRecommendationFormScreen> createState() => _State();
}

class _State extends ConsumerState<TravelRecommendationFormScreen> {
  static const _interestOptions = [
    '맛집',
    '카페',
    '자연',
    '바다',
    '문화·역사',
    '시장',
    '체험',
    '사진',
    '휴식',
    '액티비티',
  ];

  final destination = TextEditingController(),
      customDays = TextEditingController(),
      customBudget = TextEditingController(),
      customInterests = TextEditingController(),
      additional = TextEditingController();
  int? selectedDays = 2;
  int? selectedBudget = 200000;
  int companions = 1;
  final selectedInterests = <String>{};
  bool showCustomInterests = false;
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
      destination,
      customDays,
      customBudget,
      customInterests,
      additional,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final d = destination.text.trim(),
        day = selectedDays ?? int.tryParse(customDays.text),
        b = selectedBudget ?? int.tryParse(customBudget.text),
        tags = <String>{
          ...selectedInterests,
          if (showCustomInterests)
            ...customInterests.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
        }.toList();
    if (d.length < 2 ||
        d.length > 100 ||
        day == null ||
        day < 1 ||
        day > 14 ||
        b == null ||
        b < 0 ||
        b > 50000000 ||
        companions < 1 ||
        companions > 20 ||
        tags.length > 5 ||
        tags.any((e) => e.length > 30) ||
        additional.text.trim().length > 500) {
      showLqSnack(context, '여행지·기간·예산·인원·관심사 입력 범위를 확인해 주세요');
      return;
    }
    setState(() => busy = true);
    try {
      final repository = ref.read(questRecommendationRepositoryProvider);
      final body = {
        'destination': d,
        'days': day,
        'budgetPerPerson': b,
        'companionCount': companions,
        'interests': tags,
        'additionalRequest': additional.text.trim().isEmpty
            ? null
            : additional.text.trim(),
      };
      final r = widget.weekly
          ? await repository.weeklyTravel(body)
          : await repository.travel(body);
      if (mounted) context.push('/quest-recommendations/result', extra: r);
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RecommendationForm(
    title: '여행 추천 조건',
    children: [
      TextField(
        controller: destination,
        maxLength: 100,
        decoration: const InputDecoration(labelText: '여행지 (예: 부산)'),
      ),
      RecommendationChoiceSection<int?>(
        label: '기간',
        selected: selectedDays,
        options: const [
          RecommendationOption(1, '당일'),
          RecommendationOption(2, '1박 2일'),
          RecommendationOption(3, '2박 3일'),
          RecommendationOption(4, '3박 4일'),
          RecommendationOption(7, '일주일'),
          RecommendationOption(null, '직접 입력'),
        ],
        onSelected: (value) => setState(() => selectedDays = value),
        child: selectedDays == null
            ? TextField(
                controller: customDays,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '기간 직접 입력',
                  suffixText: '일',
                  helperText: '1~14일',
                ),
              )
            : null,
      ),
      RecommendationChoiceSection<int?>(
        label: '1인 예산',
        selected: selectedBudget,
        options: const [
          RecommendationOption(100000, '10만원 이하'),
          RecommendationOption(200000, '20만원 이하'),
          RecommendationOption(300000, '30만원 이하'),
          RecommendationOption(500000, '50만원 이하'),
          RecommendationOption(1000000, '100만원 이하'),
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
          hintText: '예: 대중교통으로 이동 가능한 활동 위주',
        ),
      ),
      LqButton(label: '3개 추천받기', busy: busy, onPressed: submit),
    ],
  );
}
