import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/group/application/group_chat_controller.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
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
  int _shownCount = 0;

  // dispose()에서는 ref를 쓸 수 없으므로 컨트롤러를 필드에 들고 있는다.
  late final GroupChatController _controller = ref.read(
    groupChatProvider(widget.groupId),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.load();
  }

  @override
  void dispose() {
    // 화면을 벗어나면 폴링을 멈춘다. autoDispose가 컨트롤러를 정리하지만
    // 마지막 프레임과 폐기 사이에 타이머가 한 번 더 도는 것을 막는다.
    _controller.stop();
    WidgetsBinding.instance.removeObserver(this);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  Future<void> _send() async {
    final text = input.text;
    try {
      if (await _controller.send(text)) input.clear();
    } catch (e) {
      if (mounted) showLqError(context, e);
    }
  }

  void _scrollToBottomIfGrew(int count) {
    if (count <= _shownCount) {
      _shownCount = count;
      return;
    }
    _shownCount = count;
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

  @override
  Widget build(BuildContext context) {
    final archived =
        ref.watch(groupDetailProvider(widget.groupId)).value?.archived == true;
    final chat = ref.watch(groupChatProvider(widget.groupId));
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) => _body(chat, archived),
    );
  }

  Widget _body(GroupChatController chat, bool archived) {
    final messages = chat.messages;
    final loading = chat.loading;
    final error = chat.error;
    final sending = chat.sending;
    _scrollToBottomIfGrew(messages.length);
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
