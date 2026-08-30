import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n.dart';
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

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // في الوضع المتّصل نجلب رسائل المحادثة من الخادم (لا يفعل شيئًا في التجريبي).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = ref.read(driverProvider.notifier);
      n.loadMessages(widget.orderId);
      // المحادثة مفتوحة → الرسائل الواردة تحدّثها مباشرة بلا إشعار نظام
      n.setOpenChat(widget.orderId);
    });
    // ============================================================
    // استطلاعٌ كلّ ثماني ثوانٍ **ما دامت الشاشةُ مفتوحة**.
    // ------------------------------------------------------------
    // كان البثُّ (0143) يقع على `order-chat:<order_id>` وحدَها، وتوصيلةُ
    // الاشتراك بلا طلب — فلا قناةَ لها ولا حدث. وهي ٧٤ من ٨٩ في الإنتاج.
    // وصار البثُّ في 0434 يقع على `delivery-chat:<delivery_id>` أيضًا،
    // والتطبيقُ يشترك بها — فمحادثةُ الاشتراك حيّةٌ الآن.
    //
    // ⚠ **ويبقى الاستطلاعُ شبكةَ أمان لا تكرارًا**: `realtime.send` في
    //   المُشغِّل ملفوفةٌ بـ`exception when others then null` — أي أنّ فشلَ
    //   البثّ **صامتٌ تمامًا**. فلو سقط لبقيت الشاشةُ جامدةً بلا أن يعلم أحد.
    //   ثمانِ ثوانٍ ثمنٌ زهيدٌ مقابل ذلك. ويتوقّف مع إغلاق الشاشة.
    // ============================================================
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) ref.read(driverProvider.notifier).loadMessages(widget.orderId);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    ref.read(driverProvider.notifier).setOpenChat(null);
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
    final t = ref.watch(stringsProvider);
    final data = ref.watch(driverProvider);
    final order = data.orderById(widget.orderId);
    final messages = data.messages[widget.orderId] ?? const [];
    final name = order?.name ?? t.customer;
    final initial = order?.initial ?? (t.ar ? 'ع' : 'C');

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
                        child: Icon(backChevron(context), color: Colors.white, size: 24),
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
                            Text('${t.orderNo(shortId(widget.orderId))} · ${t.onlineNow}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
                          ],
                        ),
                      ),
                      InkWell(
                        // 🚨 كان `_snack(t.calling(name))` وحدَه: يقول «جارٍ
                        //   الاتّصال» ولا يتّصل. وهو أظهرُ زرٍّ في الشاشة التي
                        //   يصل إليها المندوبُ **حين لا يردّ العميل** — أي
                        //   وعدٌ كاذبٌ في اللحظة التي يحتاج فيها الاتّصالَ حقًّا.
                        //   والرقمُ متاحٌ في `order.phone` (يملؤه المستودع من
                        //   `driver_orders.customer_phone`). أُصلح في شاشة
                        //   العملاء وبقي هنا.
                        onTap: () => _call(t, order),
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
                    child: Text(t.today, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8781))),
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
    final t = ref.watch(stringsProvider);
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
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        border: InputBorder.none,
                        hintText: t.typeMessage,
                        hintStyle: const TextStyle(color: AppColors.muted3, fontSize: 14),
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

  /// نفسُ منطق `customers_screen._call` حرفًا — ثلاثُ حالاتٍ لا واحدة:
  /// لا رقمَ مسجَّل · فشلَ فتحُ المُتّصِل · أو يفتح فعلًا.
  Future<void> _call(L t, Order? order) async {
    final raw = (order?.phone ?? '').trim();
    if (raw.isEmpty) {
      _snack(t.noPhone);
      return;
    }
    // `tel:` لا يقبل الفراغَ ولا الشرطات في بعض الأجهزة.
    final uri = Uri.parse('tel:${raw.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _snack(t.callFailed);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}
