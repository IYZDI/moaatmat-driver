import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/action_queue.dart' show QueueClock;
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import 'stop_actions.dart';

/// ============================================================================
/// شريطُ التراجع العائم: «سُلّم #12 — سارة · تراجع (9)».
/// ----------------------------------------------------------------------------
/// كلُّ فعلٍ يُنتظر قليلًا قبل أن يُرسَل (4 ثوانٍ للتحميل، 10 للتسليم)، لأنّ
/// الإصبعَ في سيّارةٍ تهتزّ يخطئ. والعدُّ التنازليُّ حيٌّ ليعرف المندوبُ كم بقي
/// له — ويختفي الشريطُ وحدَه حين تنقضي المهلة.
/// ============================================================================
class UndoBar extends ConsumerStatefulWidget {
  const UndoBar({super.key});

  @override
  ConsumerState<UndoBar> createState() => _UndoBarState();
}

class _UndoBarState extends ConsumerState<UndoBar> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// المؤقّتُ يعيش ما دام هناك ما يُتراجَع عنه فقط — لا نبضَ بلا حاجة.
  void _ensureTicking(bool needed) {
    if (needed && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    // ساعةُ الطابور نفسُها: الشريطُ يختفي في اللحظة التي يُرسَل فيها الفعل.
    final now = QueueClock.now();
    final live = s.pending.where((a) => a.undoable);
    final action = live.isEmpty ? null : live.last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureTicking(action != null);
    });
    if (action == null) return const SizedBox.shrink();
    final match = s.stops.where((x) => x.id == action.deliveryId);
    final stop = match.isEmpty ? null : match.first;
    final secs = (action.commitAt.difference(now).inMilliseconds / 1000).ceil();
    final label = t.undoLabel(action.action, stop?.bagLabel ?? '', firstName(stop?.customerName ?? ''));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: p.ink,
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w700, color: p.bg)),
              ),
              TextButton(
                onPressed: () => ref.read(driverProvider.notifier).undo(action.key),
                style: TextButton.styleFrom(
                  foregroundColor: p.primarySoft,
                  minimumSize: const Size(88, 48),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: TextSizes.body, fontWeight: FontWeight.w800),
                ),
                child: Text('${t.undo} ($secs)'),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
