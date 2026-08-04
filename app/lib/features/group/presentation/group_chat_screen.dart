import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({required this.groupId, super.key});
  final int groupId;
  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatState();
}

class _GroupChatState extends ConsumerState<GroupChatScreen>
    with WidgetsBindingObserver {
  final input = TextEditingController();
  final scroll = ScrollController();
  final List<GroupMessage> messages = [];
  Timer? timer;
  bool loading = true, polling = false, sending = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      timer?.cancel();
    }
  }

  Future<void> _load() async {
    try {
      final page = await ref
          .read(groupRepositoryProvider)
          .messages(widget.groupId);
      _merge(page.messages);
      if (mounted) setState(() => loading = false);
      _start();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e;
        });
      }
    }
  }

  void _start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (polling || !mounted) return;
    polling = true;
    try {
      final page = await ref
          .read(groupRepositoryProvider)
          .messages(
            widget.groupId,
            afterId: messages.isEmpty ? null : messages.last.id,
          );
      _merge(page.messages);
    } catch (_) {
    } finally {
      polling = false;
    }
  }

  void _merge(List<GroupMessage> incoming) {
    final ids = messages.map((message) => message.id).toSet();
    final additions = incoming.where((message) => ids.add(message.id)).toList();
    if (additions.isEmpty) return;
    messages.addAll(additions);
    messages.sort((a, b) => a.id.compareTo(b.id));
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || text.length > 1000 || sending) return;
    setState(() => sending = true);
    try {
      final message = await ref
          .read(groupRepositoryProvider)
          .sendMessage(widget.groupId, text);
      input.clear();
      _merge([message]);
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived =
        ref.watch(groupDetailProvider(widget.groupId)).value?.archived == true;
    Widget content;
    if (loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      content = Center(child: Text('채팅을 불러오지 못했어요', style: LqText.body));
    } else if (messages.isEmpty) {
      content = const Center(child: Text('첫 메시지를 보내 보세요'));
    } else {
      content = ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return Align(
            alignment: message.mine
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: message.mine ? LqColors.successBg : LqColors.surfaceCard,
                borderRadius: LqShape.rowRadius,
                border: Border.all(color: LqColors.borderMuted),
              ),
              child: Column(
                crossAxisAlignment: message.mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!message.mine)
                    Text(message.senderNickname, style: LqText.caption),
                  Text(message.content, style: LqText.bodySm),
                ],
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '그룹 채팅'),
            Expanded(child: content),
            if (archived)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('보관된 그룹은 채팅 기록만 볼 수 있어요.'),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: '메시지 입력',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: sending ? null : _send,
                      icon: sending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
