import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_quest/features/proof/application/proof_providers.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/presentation/widgets/proof_widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 인증 게시물 작성.
///
/// [initialCompletionId]가 있으면 퀘스트 선택 단계를 건너뛴다. 퀘스트 완료 결과 화면에서
/// 바로 넘어오는 경로가 그렇다 — 사진을 올릴 마음이 제일 큰 순간이라 선택지를 한 번 더
/// 보여줄 이유가 없다.
class ProofFormScreen extends ConsumerStatefulWidget {
  const ProofFormScreen({super.key, this.initialCompletionId});

  final int? initialCompletionId;

  @override
  ConsumerState<ProofFormScreen> createState() => _ProofFormScreenState();
}

class _ProofFormScreenState extends ConsumerState<ProofFormScreen> {
  /// 서버 `app.proof.max-photos`와 같은 값. 넘겨 보내면 서버가 막지만,
  /// 업로드가 끝난 뒤 거절당하는 것보다 고를 때 막는 편이 낫다.
  static const _maxPhotos = 5;

  final _contentController = TextEditingController();
  final _photoPaths = <String>[];
  int? _completionId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _completionId = widget.initialCompletionId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photoPaths.length >= _maxPhotos) return;

    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
      limit: _maxPhotos - _photoPaths.length,
    );
    if (picked.isEmpty || !mounted) return;

    setState(() {
      for (final file in picked) {
        if (_photoPaths.length < _maxPhotos) _photoPaths.add(file.path);
      }
    });
  }

  Future<void> _submit() async {
    final completionId = _completionId;
    if (completionId == null || _photoPaths.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      final post = await ref
          .read(proofRepositoryProvider)
          .create(
            completionId: completionId,
            photoPaths: _photoPaths,
            content: _contentController.text,
          );

      ref.invalidate(proofCandidatesProvider);
      ref.invalidate(proofHighlightsProvider);

      if (!mounted) return;
      showLqSnack(context, '인증을 올렸어요. 다른 모험가들의 판정을 기다려요');
      context.pushReplacement('/proofs/${post.postId}');
    } catch (error) {
      if (!mounted) return;
      showLqError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '인증 올리기'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text('어떤 퀘스트인가요?', style: LqText.sectionTitle),
                  const SizedBox(height: 8),
                  _QuestPicker(
                    selectedCompletionId: _completionId,
                    onSelect: (id) => setState(() => _completionId = id),
                  ),
                  const SizedBox(height: 20),
                  Text('인증 사진', style: LqText.sectionTitle),
                  const SizedBox(height: 4),
                  Text('최대 $_maxPhotos장까지 올릴 수 있어요', style: LqText.caption),
                  const SizedBox(height: 8),
                  _PhotoPicker(
                    paths: _photoPaths,
                    onAdd: _pickPhotos,
                    onRemove: (index) =>
                        setState(() => _photoPaths.removeAt(index)),
                    maxPhotos: _maxPhotos,
                  ),
                  const SizedBox(height: 20),
                  Text('한 줄 설명', style: LqText.sectionTitle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: 5,
                    style: LqText.bodySm,
                    decoration: const InputDecoration(
                      hintText: '어떤 모험이었는지 짧게 남겨주세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LqButton(
                label: '인증 올리기',
                busy: _submitting,
                onPressed: _completionId != null && _photoPaths.isNotEmpty
                    ? _submit
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 아직 인증을 올리지 않은 완료 기록에서만 고를 수 있다. 자유 입력이 아니라 목록 선택인
/// 것이 요점 — 수행하지 않은 퀘스트를 인증 대상으로 올릴 경로가 애초에 없다.
class _QuestPicker extends ConsumerWidget {
  const _QuestPicker({
    required this.selectedCompletionId,
    required this.onSelect,
  });

  final int? selectedCompletionId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(proofCandidatesProvider);

    return LqAsyncView<List<ProofCandidate>>(
      value: candidates,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: '인증을 올릴 수 있는 완료 퀘스트가 없어요',
      onRetry: () => ref.invalidate(proofCandidatesProvider),
      data: (items) => Column(
        children: [
          for (final candidate in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LqCard(
                background: candidate.completionId == selectedCompletionId
                    ? LqColors.successBg
                    : LqColors.surfaceCard,
                borderColor: candidate.completionId == selectedCompletionId
                    ? LqColors.primary
                    : LqColors.ink,
                onTap: () => onSelect(candidate.completionId),
                child: Row(
                  children: [
                    Expanded(
                      child: ProofQuestBadge(
                        title: candidate.questTitle,
                        grade: candidate.questGrade,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      proofTimeLabel(candidate.completedAt),
                      style: LqText.caption,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.paths,
    required this.onAdd,
    required this.onRemove,
    required this.maxPhotos,
  });

  final List<String> paths;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var index = 0; index < paths.length; index++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: LqShape.cardRadius,
                    child: Image.file(
                      File(paths[index]),
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onRemove(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: LqColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: LqColors.onDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (paths.length < maxPhotos)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: LqColors.surfaceCard,
                  borderRadius: LqShape.cardRadius,
                  border: Border.all(
                    color: LqColors.borderMuted,
                    width: LqShape.borderWidth,
                  ),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: LqColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
