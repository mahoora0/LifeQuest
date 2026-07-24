import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';

/// 시안 톤에 맞춘 스낵바. 오류는 항상 [lqErrorMessage]를 거쳐 표시한다.
void showLqSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LqColors.ink,
        shape: const RoundedRectangleBorder(borderRadius: LqShape.rowRadius),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: LqColors.onDark,
          ),
        ),
      ),
    );
}

void showLqError(BuildContext context, Object error) {
  showLqSnack(context, lqErrorMessage(error));
}
