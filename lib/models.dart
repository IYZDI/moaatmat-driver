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
  final String id;
  final String name;
  final String initial;
  final String items;
  final String address;
  final String prefTime;
  final OrderStatus status;
  final String distance;
  final String eta;

  const Order({
    required this.id,
    required this.name,
    required this.initial,
    required this.items,
    required this.address,
    required this.prefTime,
    required this.status,
    this.distance = '',
    this.eta = '',
  });

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        name: name,
        initial: initial,
        items: items,
        address: address,
        prefTime: prefTime,
        status: status ?? this.status,
        distance: distance,
        eta: eta,
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
  const HistoryItem({required this.id, required this.name, required this.sub, required this.ok});
}
