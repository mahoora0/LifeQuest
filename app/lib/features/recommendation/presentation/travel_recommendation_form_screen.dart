import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/recommendation/application/quest_recommendation_provider.dart';
import 'package:life_quest/features/recommendation/presentation/place_recommendation_form_screen.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class TravelRecommendationFormScreen extends ConsumerStatefulWidget {
  const TravelRecommendationFormScreen({super.key});
  @override
  ConsumerState<TravelRecommendationFormScreen> createState() => _State();
}

class _State extends ConsumerState<TravelRecommendationFormScreen> {
  final destination = TextEditingController(),
      days = TextEditingController(text: '2'),
      budget = TextEditingController(text: '200000'),
      companions = TextEditingController(text: '1'),
      interests = TextEditingController(),
      additional = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    for (final c in [
      destination,
      days,
      budget,
      companions,
      interests,
      additional,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final d = destination.text.trim(),
        day = int.tryParse(days.text),
        b = int.tryParse(budget.text),
        c = int.tryParse(companions.text),
        tags = interests.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (d.length < 2 ||
        d.length > 100 ||
        day == null ||
        day < 1 ||
        day > 14 ||
        b == null ||
        b < 0 ||
        b > 50000000 ||
        c == null ||
        c < 1 ||
        c > 20 ||
        tags.length > 5 ||
        tags.any((e) => e.length > 30) ||
        additional.text.trim().length > 500) {
      showLqSnack(context, '여행지·기간·예산·인원·관심사 입력 범위를 확인해 주세요');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await ref.read(questRecommendationRepositoryProvider).travel({
        'destination': d,
        'days': day,
        'budgetPerPerson': b,
        'companionCount': c,
        'interests': tags,
        'additionalRequest': additional.text.trim().isEmpty
            ? null
            : additional.text.trim(),
      });
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
      TextField(
        controller: days,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '기간 (1~14일)'),
      ),
      TextField(
        controller: budget,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '1인 예산 상한'),
      ),
      TextField(
        controller: companions,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '참여 인원'),
      ),
      TextField(
        controller: interests,
        decoration: const InputDecoration(labelText: '관심사 (쉼표 구분, 최대 5개)'),
      ),
      TextField(
        controller: additional,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(labelText: '추가 요청'),
      ),
      LqButton(label: '3개 추천받기', busy: busy, onPressed: submit),
    ],
  );
}
