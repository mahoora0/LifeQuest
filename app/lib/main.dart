import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/app/life_quest_app.dart';
import 'package:life_quest/core/network/provider_retry.dart';

void main() {
  runApp(const ProviderScope(retry: lqProviderRetry, child: LifeQuestApp()));
}
