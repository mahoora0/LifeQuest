import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

class AuthSplashScreen extends StatelessWidget {
  const AuthSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: LqColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LIFE QUEST', style: LqText.displayTitle),
            SizedBox(height: 18),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: LqColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
