import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../route_logic.dart';

/// يحفظ قراراتِ المندوب على هاتفه (المؤجَّل، «اذهب إليها الآن»، من بدأ، كم اتّصل)
/// ليومِ المطعم وحدَه.
///
/// ⚠ اليومُ يومُ **المطعم** (`org_today`) لا يومُ الهاتف: مسارُ الفجر يبدأ قبل أن
///   يتغيّر تاريخُ هاتفٍ مضبوطٍ على منطقةٍ أخرى، وتأجيلُ الأمس لا يُرحَّل إلى اليوم.
class RouteLocalStore {
  static const key = 'route_local_v1';

  /// يُعيد قراراتِ [day]، أو بدايةً نظيفة إن كان المحفوظُ ليومٍ آخر.
  Future<RouteLocal> load(String day) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      if (raw == null) return RouteLocal(day: day);
      final local = RouteLocal.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      return local.day == day ? local : RouteLocal(day: day);
    } catch (_) {
      return RouteLocal(day: day);
    }
  }

  Future<void> save(RouteLocal local) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, jsonEncode(local.toJson()));
    } catch (_) {/* قراراتٌ محلّيّة — ضياعُها لا يُسقط شيئًا */}
  }

  Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(key);
    } catch (_) {}
  }
}

/// يومٌ بصيغة yyyy-MM-dd.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
