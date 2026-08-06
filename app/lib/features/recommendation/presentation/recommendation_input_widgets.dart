import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';

class RecommendationOption<T> {
  const RecommendationOption(this.value, this.label);

  final T value;
  final String label;
}

class RecommendationChoiceSection<T> extends StatelessWidget {
  const RecommendationChoiceSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.child,
    super.key,
  });

  final String label;
  final List<RecommendationOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget? child;

  @override
  Widget build(BuildContext context) => _RecommendationSection(
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              LqChip(
                key: ValueKey('recommendation-choice-$label-${option.label}'),
                label: option.label,
                selected: option.value == selected,
                onTap: () => onSelected(option.value),
              ),
          ],
        ),
        if (child != null) ...[const SizedBox(height: 10), child!],
      ],
    ),
  );
}

class RecommendationCompanionStepper extends StatelessWidget {
  const RecommendationCompanionStepper({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _RecommendationSection(
    label: '참여 인원',
    child: Row(
      children: [
        _StepperButton(
          icon: Icons.remove,
          tooltip: '인원 1명 줄이기',
          enabled: value > 1,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 92,
          child: Text(
            value == 1 ? '1명 · 혼자' : '$value명',
            textAlign: TextAlign.center,
            style: LqText.cardTitle,
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          tooltip: '인원 1명 늘리기',
          enabled: value < 20,
          onTap: () => onChanged(value + 1),
        ),
      ],
    ),
  );
}

class RecommendationInterestPicker extends StatelessWidget {
  const RecommendationInterestPicker({
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.showCustomInput,
    required this.onCustomInputChanged,
    required this.customController,
    super.key,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool showCustomInput;
  final ValueChanged<bool> onCustomInputChanged;
  final TextEditingController customController;

  @override
  Widget build(BuildContext context) => _RecommendationSection(
    label: '관심사 (최대 5개)',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              LqChip(
                label: option,
                selected: selected.contains(option),
                onTap: () => onToggle(option),
              ),
            LqChip(
              label: '직접 추가',
              selected: showCustomInput,
              onTap: () => onCustomInputChanged(!showCustomInput),
            ),
          ],
        ),
        if (showCustomInput) ...[
          const SizedBox(height: 10),
          TextField(
            controller: customController,
            maxLength: 159,
            decoration: const InputDecoration(
              labelText: '직접 관심사',
              hintText: '북카페, 반려동물처럼 쉼표로 구분',
            ),
          ),
        ],
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: customController,
          builder: (context, value, _) {
            final customValues = showCustomInput
                ? value.text
                      .split(',')
                      .map((entry) => entry.trim())
                      .where((entry) => entry.isNotEmpty)
                      .where((entry) => !selected.contains(entry))
                      .toSet()
                : const <String>{};
            return Text(
              '선택 ${selected.length + customValues.length}개',
              style: LqText.caption,
            );
          },
        ),
      ],
    ),
  );
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LqText.cardTitle),
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: tooltip,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: LqSpacing.minTouchTarget,
        height: LqSpacing.minTouchTarget,
        decoration: BoxDecoration(
          color: enabled ? LqColors.surfaceRaised : LqColors.disabledBg,
          borderRadius: LqShape.tileRadius,
          border: LqShape.mutedBorder(),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? LqColors.textPrimary : LqColors.textMuted,
        ),
      ),
    ),
  );
}
