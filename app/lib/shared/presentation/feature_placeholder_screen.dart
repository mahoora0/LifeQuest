import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

/// 이번 범위에 포함되지 않은 화면(프로필 수정 S-04 · 알림 설정 · 로그인)의 진입점.
class FeaturePlaceholderScreen extends StatelessWidget {
  const FeaturePlaceholderScreen({
    super.key,
    required this.title,
    this.message = '준비 중인 화면이에요',
    this.hint,
  });

  final String title;
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            LqHeader(title: title),
            Expanded(
              child: LqEmptyView(
                message: message,
                hint: hint,
                asset: LqAssets.charSit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
