import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/recommendation/application/quest_recommendation_provider.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class PlaceRecommendationFormScreen extends ConsumerStatefulWidget {
  const PlaceRecommendationFormScreen({super.key});
  @override
  ConsumerState<PlaceRecommendationFormScreen> createState() => _State();
}

class _State extends ConsumerState<PlaceRecommendationFormScreen> {
  final area = TextEditingController(),
      minutes = TextEditingController(text: '180'),
      budget = TextEditingController(text: '30000'),
      companions = TextEditingController(text: '1'),
      interests = TextEditingController(),
      additional = TextEditingController();
  RecommendationEnvironment environment = RecommendationEnvironment.any;
  bool busy = false;
  @override
  void dispose() {
    for (final c in [
      area,
      minutes,
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
    final a = area.text.trim(),
        m = int.tryParse(minutes.text),
        b = int.tryParse(budget.text),
        c = int.tryParse(companions.text),
        tags = interests.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (a.length < 2 ||
        a.length > 100 ||
        m == null ||
        m < 30 ||
        m > 720 ||
        b == null ||
        b < 0 ||
        b > 10000000 ||
        c == null ||
        c < 1 ||
        c > 20 ||
        tags.length > 5 ||
        tags.any((e) => e.length > 30) ||
        additional.text.trim().length > 500) {
      showLqSnack(context, '지역·시간·예산·인원·관심사 입력 범위를 확인해 주세요');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await ref.read(questRecommendationRepositoryProvider).place({
        'area': a,
        'availableMinutes': m,
        'budgetPerPerson': b,
        'companionCount': c,
        'environment': environment.name.toUpperCase(),
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
    title: '장소 추천 조건',
    children: [
      TextField(
        controller: area,
        maxLength: 100,
        decoration: const InputDecoration(labelText: '지역 (예: 서울 성수동)'),
      ),
      TextField(
        controller: minutes,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '가능 시간 (30~720분)'),
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
      DropdownButtonFormField(
        initialValue: environment,
        items: const [
          DropdownMenuItem(
            value: RecommendationEnvironment.any,
            child: Text('상관없음'),
          ),
          DropdownMenuItem(
            value: RecommendationEnvironment.indoor,
            child: Text('실내'),
          ),
          DropdownMenuItem(
            value: RecommendationEnvironment.outdoor,
            child: Text('실외'),
          ),
        ],
        onChanged: (v) => setState(() => environment = v!),
        decoration: const InputDecoration(labelText: '환경'),
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
