import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';

/// 모든 조회 화면이 공유하는 3상태(로딩 / 빈 / 오류) 래퍼.
class LqAsyncView<T> extends StatelessWidget {
  const LqAsyncView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.emptyMessage = '아직 보여드릴 내용이 없어요',
    this.emptyAsset = LqAssets.charSit,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;

  /// 데이터는 왔지만 비어 있는 경우의 판정.
  final bool Function(T value)? isEmpty;
  final String emptyMessage;
  final String emptyAsset;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // 새로고침 중에는 직전 데이터를 그대로 유지해 화면 깜빡임을 막는다.
    if (value.hasError && !value.isLoading) {
      return LqErrorView(error: value.error!, onRetry: onRetry);
    }
    if (value.hasValue) {
      final current = value.requireValue;
      if (isEmpty?.call(current) ?? false) {
        return LqEmptyView(message: emptyMessage, asset: emptyAsset);
      }
      return data(current);
    }
    return const LqLoadingView();
  }
}

/// 로딩 — 캐릭터 + 인디케이터.
class LqLoadingView extends StatelessWidget {
  const LqLoadingView({super.key, this.label = '불러오는 중이에요…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LqImage(LqAssets.charWalk, width: 92),
          const SizedBox(height: 14),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: LqColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: LqText.caption),
        ],
      ),
    );
  }
}

/// 빈 상태 — 캐릭터 + 안내 문구.
class LqEmptyView extends StatelessWidget {
  const LqEmptyView({
    super.key,
    required this.message,
    this.asset = LqAssets.charSit,
    this.hint,
  });

  final String message;
  final String asset;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LqImage(asset, width: 118),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LqText.body.copyWith(color: LqColors.textSecondary),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!, textAlign: TextAlign.center, style: LqText.caption),
            ],
          ],
        ),
      ),
    );
  }
}

/// 오류 — 문구 + "다시 시도" 버튼.
class LqErrorView extends StatelessWidget {
  const LqErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LqImage(LqAssets.charSit, width: 108),
            const SizedBox(height: 14),
            Text(
              lqErrorMessage(error),
              textAlign: TextAlign.center,
              style: LqText.body.copyWith(color: LqColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 180,
                child: LqButton(label: '다시 시도', onPressed: onRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
