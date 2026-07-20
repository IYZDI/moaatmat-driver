import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ChatScreen({super.key, required this.orderId});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // في الوضع المتّصل نجلب رسائل المحادثة من الخادم (لا يفعل شيئًا في التجريبي).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverProvider.notifier).loadMessages(widget.orderId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    ref.read(driverProvider.notifier).sendMessage(widget.orderId, t);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(driverProvider);
    final order = data.orderById(widget.orderId);
    final messages = data.messages[widget.orderId] ?? const [];
    final name = order?.name ?? 'العميل';
    final initial = order?.initial ?? 'ع';

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1EE),
      body: Column(
        children: [
          TealHeader(
            bottomRadius: 24,
            child: Column(
              children: [
                const StatusBar(dark: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.canPop() ? context.pop() : context.go('/customers'),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            Text('طلب #${widget.orderId} · متصلة الآن', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _snack('جارٍ الاتصال بـ $name'),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.phone_outlined, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
                    child: const Text('اليوم 8:14 م', style: TextStyle(fontSize: 11, color: Color(0xFF8A8781))),
                  ),
                ),
                const SizedBox(height: 10),
                for (final m in messages) ...[
                  _bubble(m),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final driver = m.outgoing;
    return Align(
      alignment: driver ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: driver ? Colors.white : AppColors.teal,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(driver ? 4 : 16),
              bottomRight: Radius.circular(driver ? 16 : 4),
            ),
            boxShadow: driver ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.text, style: TextStyle(fontSize: 14, height: 1.5, color: driver ? AppColors.ink : Colors.white)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(m.time, style: TextStyle(fontSize: 10.5, color: driver ? AppColors.muted3 : Colors.white.withValues(alpha: 0.75))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      color: const Color(0xFFEEF1EE),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE3E5E1)),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                        border: InputBorder.none,
                        hintText: 'اكتب رسالة…',
                        hintStyle: TextStyle(color: AppColors.muted3, fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.attach_file, size: 19, color: AppColors.muted3),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _send,
            borderRadius: BorderRadius.circular(23),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.teal),
              child: Transform.flip(flipX: true, child: const Icon(Icons.send, color: Colors.white, size: 20)),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}
