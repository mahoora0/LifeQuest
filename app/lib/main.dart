import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/app/life_quest_app.dart';

void main() {
  runApp(const ProviderScope(child: LifeQuestApp()));
}
