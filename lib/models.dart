import 'theme.dart';
import 'package:flutter/material.dart';

/// دورة حياة الطلب لدى المندوب.
enum OrderStatus { preparing, ready, picked, enroute, delivered, failed }

class StatusMeta {
  final String label;
  final Color fg;
  final Color bg;
  const StatusMeta(this.label, this.fg, this.bg);
}

/// تحويل حالة قاعدة البيانات (enum الطلبات) إلى حالة واجهة المندوب.
OrderStatus orderStatusFromDb(String s) {
  switch (s) {
    case 'preparing':
      return OrderStatus.preparing;
    case 'ready':
      return OrderStatus.ready;
    case 'picked': // حالة مشتقة من driver_orders (0144): picked_at مسجّل
      return OrderStatus.picked;
    case 'out_for_delivery':
      return OrderStatus.enroute;
    case 'delivered':
      return OrderStatus.delivered;
    case 'failed':
    case 'cancelled':
      return OrderStatus.failed;
    default:
      return OrderStatus.preparing;
  }
}

class DriverStats {
  final int total;
  final int delivered;
  final int remaining;
  const DriverStats({required this.total, required this.delivered, required this.remaining});
}

StatusMeta statusMeta(OrderStatus s) {
  switch (s) {
    case OrderStatus.preparing:
      return const StatusMeta('قيد التحضير', AppColors.amber, AppColors.amberBg);
    case OrderStatus.ready:
      return const StatusMeta('جاهزة للاستلام', AppColors.teal, AppColors.tealTint);
    case OrderStatus.picked:
      return const StatusMeta('تم الاستلام', AppColors.teal, AppColors.tealTint);
    case OrderStatus.enroute:
      return const StatusMeta('في الطريق', AppColors.teal, AppColors.tealTint);
    case OrderStatus.delivered:
      return const StatusMeta('تم التسليم', AppColors.teal, AppColors.tealTint);
    case OrderStatus.failed:
      return const StatusMeta('تعذّر', AppColors.muted, AppColors.border2);
  }
}

class Order {
  final String id; // = delivery_id (للحالة والتوجيه)
  final String? orderId; // = order_id (للمحادثة؛ فارغ لتوصيلات الاشتراكات)
  final String name;
  final String initial;
  final String items;
  final String address;
  final String prefTime;
  final OrderStatus status;
  final String distance;
  final String eta;

  /// إحداثيات وجهة التسليم (من driver_orders — قد تكون فارغة لعناوين بلا موقع).
  final double? lat;
  final double? lng;

  /// فترةُ التوصيل كما بِيعت للعميل — عمود `delivery_slot` من `driver_orders`
  /// (0366)، مثال: «صباحًا (٨ - ١١ ص)».
  ///
  /// ⚠ و`null` هي الحالةُ الأغلب لا الاستثناء: طلبُ نقطة البيع لا اشتراكَ له
  ///   فلا فترةَ بيعت له أصلًا، وكلُّ اشتراكٍ أُنشئ قبل 0365 لم تُحفظ فترتُه.
  ///   فالمستودعُ يوحّد الفراغَ إلى `null` (لا سلسلةً فارغة) لتبقى للواجهة
  ///   حالةٌ واحدةٌ تفحصها: موجودةٌ فتُعرض، أو غائبةٌ فلا يُعرض عنها شيء.
  final String? deliverySlot;

  /// جوّالُ العميل — عمود `customer_phone` من `driver_orders`.
  ///
  /// 🚨 كانت الدالّةُ تُعيده منذ كُتبت **ولا يقرؤه أحد**، وزرّا الهاتف في
  ///   التطبيق يعرضان رسالةً («جارٍ الاتصال بفلان») ولا يتّصلان. فمندوبٌ
  ///   يقف أمام بابٍ مغلقٍ لا يملك وسيلةً للوصول إلى صاحبه — وهو أوّلُ ما
  ///   يحتاجه في الميدان. ونظيرُه في الويب يتّصل فعلًا (parts.jsx).
  ///
  /// ⚠ و`null` واردةٌ: عنوانٌ بلا رقمٍ مسجَّل. فالزرُّ يُخفى عندها بدل أن
  ///   يَعِد بما لا يقع.
  final String? phone;

  const Order({
    required this.id,
    this.orderId,
    required this.name,
    required this.initial,
    required this.items,
    required this.address,
    required this.prefTime,
    required this.status,
    this.distance = '',
    this.eta = '',
    this.phone,
    this.lat,
    this.lng,
    this.deliverySlot,
  });

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        orderId: orderId,
        name: name,
        initial: initial,
        items: items,
        address: address,
        prefTime: prefTime,
        status: status ?? this.status,
        distance: distance,
        eta: eta,
        lat: lat,
        lng: lng,
        // ⚠ كلُّ حقلٍ يُنسى هنا يُمحى عند أوّل تغييرِ حالة (والانعكاسُ الفوريّ
        //   في state.dart يُغيّر الحالةَ قبل ردّ الخادم): فترةُ التوصيل تظهر
        //   ثمّ تختفي فجأةً بضغطة «تأكيد التوجّه».
        deliverySlot: deliverySlot,
      );

  bool get active =>
      status != OrderStatus.delivered && status != OrderStatus.failed;
  bool get picked =>
      status == OrderStatus.picked || status == OrderStatus.enroute;
}

class ChatMessage {
  final bool outgoing; // true = المندوب (أبيض ناحية البداية)، false = العميل (تركوازي ناحية النهاية)
  final String text;
  final String time;
  const ChatMessage({required this.outgoing, required this.text, required this.time});
}

class HistoryItem {
  final String id;
  final String name;
  final String sub;
  final bool ok;

  /// وقتُ التسليم — كان يُقرأ من `driver_history.delivered_at` ثمّ **يُرمى**
  /// بعد تنسيقه نصًّا. فبقي عدّادُ «هذا الشهر» في الشاشة سلسلةً حرفيّةً
  /// مكتوبةً في الشيفرة: `'142'`. رقمٌ لا يقرأ شيئًا ولا يتغيّر لأحد.
  final DateTime? deliveredAt;

  const HistoryItem({
    required this.id,
    required this.name,
    required this.sub,
    required this.ok,
    this.deliveredAt,
  });
}
