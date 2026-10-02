import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/bag_badge.dart';
import '../widgets/common.dart';
import '../widgets/stop_card.dart' show callStop;

/// ============================================================================
/// محادثةُ العميل.
/// ----------------------------------------------------------------------------
/// لا «متصلة الآن» ولا زرَّ إرفاقٍ لا يفعل شيئًا: كلاهما كان كذبًا في النسخة
/// السابقة. والبثُّ اللحظيّ (`delivery-chat:<id>`) واستطلاعُ الثماني ثوانٍ
/// (شبكةُ أمانٍ لبثٍّ يفشل بصمت) كلاهما في `state.dart` عبر `setOpenChat` —
/// مؤقّتٌ ثانٍ هنا كان يضاعف الطلبات بلا فائدة.
/// ============================================================================
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.stopId});

  final String stopId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  /// يُلتقط مرّةً: `ref` لا يُستعمل بعد تفكيك الشاشة.
  late final DriverNotifier _n;

  @override
  void initState() {
    super.initState();
    _n = ref.read(driverProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // المحادثةُ مفتوحة ⇒ تُحمَّل الآن وتُستطلع، والواردُ يحدّثها بلا إشعار نظام.
      _n.setOpenChat(widget.stopId);
    });
  }

  @override
  void dispose() {
    _n.setOpenChat(null);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return;
    final t = ref.read(stringsProvider);
    setState(() => _sending = true);
    _input.clear();
    final ok = await _n.sendMessage(widget.stopId, body);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      // النصُّ يعود إلى الحقل: لا تضيع رسالةٌ كتبها المندوبُ واقفًا عند الباب.
      if (_input.text.isEmpty) _input.text = body;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.messageNotSent)));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    final match = s.stops.where((x) => x.id == widget.stopId);
    final Stop? stop = match.isEmpty ? null : match.first;
    final messages = s.messages[widget.stopId] ?? const <ChatMessage>[];
    final name = (stop?.customerName.trim().isNotEmpty ?? false) ? stop!.customerName.trim() : t.customer;
    final phone = stop?.phone?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/route')),
        titleSpacing: 0,
        title: Row(
          children: [
            if (stop != null) ...[BagBadge(stop.bagLabel, fontSize: 16), const SizedBox(width: 10)],
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: phone.isEmpty ? t.noPhone : t.call,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: phone.isEmpty || stop == null ? null : () => callStop(context, ref, stop),
            icon: const Icon(Icons.call_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: EmptyState(icon: Icons.chat_bubble_outline, title: name, body: t.chatEmpty),
                  )
                : ListView.builder(
                    controller: _scroll,
                    // الأحدثُ في الأسفل قربَ الإبهام، والقائمةُ مقلوبةٌ فلا قفزَ عند الوصول.
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _Bubble(message: messages[messages.length - 1 - i], t: t),
                  ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final q in t.quickReplies)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ActionChip(
                      label: Text(q, style: TextStyle(fontSize: TextSizes.small, color: p.primaryText)),
                      backgroundColor: p.primarySoft,
                      side: BorderSide(color: p.border),
                      onPressed: _sending ? null : () => _send(q),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(hintText: t.typeMessage),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: t.send,
                    constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                    onPressed: _sending ? null : () => _send(_input.text),
                    // سهمُ الإرسال يشير إلى جهة القراءة — يُقلب في العربيّة.
                    icon: const Icon(Icons.send),
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

/// المندوبُ في جهة البداية وبلون السطح، والعميلُ في جهة النهاية وبالنيليّ.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.t});

  final ChatMessage message;
  final L t;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final mine = message.outgoing;
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? p.surface : p.primary,
          border: mine ? Border.all(color: p.border) : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text,
                style: TextStyle(fontSize: TextSizes.body, height: 1.5, color: mine ? p.ink : p.onPrimary)),
            if (message.at != null)
              Text(t.time(message.at!),
                  style: TextStyle(fontSize: TextSizes.caption, color: mine ? p.muted : p.onPrimary)),
          ],
        ),
      ),
    );
  }
}
