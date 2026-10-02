import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/bag_badge.dart';
import '../widgets/buttons.dart';
import '../widgets/stop_actions.dart';
import '../widgets/stop_card.dart' show callStop;

enum _Choice { door, noAnswer, notThere, wrongAddress, refused, other, defer }

/// ============================================================================
/// «مشكلة في التسليم» — ورقةٌ واحدة لكلّ ما ليس «سلّمته بيده».
/// ----------------------------------------------------------------------------
/// «تركته عند الباب» في رأسها وبلونِ النجاح: قرارُ المالك أنّه **تسليمٌ ناجح**
/// (بصورةٍ دائمًا)، فلا يُخلَط بالتعذّر. ويغيب إن منعه المطعم.
/// و«أعود إليه آخر المسار» ليس تعذّرًا: المحطةُ تبقى مفتوحةً في الذيل.
/// ============================================================================
Future<void> showProblemSheet(BuildContext context, Stop stop) {
  return showModalBottomSheet<void>(
    context: context,
    // فوق شريط التبويبات وشريط التراجع — لا تحتهما.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ProblemSheet(stop: stop),
  );
}

class _ProblemSheet extends ConsumerStatefulWidget {
  const _ProblemSheet({required this.stop});

  final Stop stop;

  @override
  ConsumerState<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends ConsumerState<_ProblemSheet> {
  _Choice? _choice;
  final _other = TextEditingController();
  bool _busy = false;

  /// لماذا لم تُلتقط صورةُ الباب — يُكتب داخل الورقة: شريطُ أسفل الشاشة يقع
  /// تحتها فلا يُرى، والورقةُ الباقيةُ بلا كلمةٍ كانت زرًّا صامتًا.
  PhotoFailure? _photoFailure;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String? _reason() => switch (_choice) {
        _Choice.noAnswer => L.reasons.noAnswer,
        _Choice.notThere => L.reasons.notThere,
        _Choice.wrongAddress => L.reasons.wrongAddress,
        _Choice.refused => L.reasons.refused,
        _Choice.other => _other.text.trim(),
        _ => null,
      };

  Future<void> _confirm() async {
    final t = ref.read(stringsProvider);
    final n = ref.read(driverProvider.notifier);
    final nav = Navigator.of(context);
    switch (_choice) {
      case null:
        return;
      case _Choice.door:
        setState(() {
          _busy = true;
          _photoFailure = null;
        });
        final r = await takeDeliveryPhoto();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _photoFailure = r.failure == PhotoFailure.cancelled ? null : r.failure;
        });
        final photo = r.bytes;
        if (photo == null) return; // ألغى أو تعذّرت (والسببُ ظاهرٌ في الورقة)
        HapticFeedback.mediumImpact();
        nav.pop();
        await n.leaveAtDoor(widget.stop.id, photo);
      case _Choice.defer:
        nav.pop();
        await n.deferStop(widget.stop.id);
      default:
        final reason = _reason() ?? '';
        if (reason.isEmpty) {
          showSnack(context, t.writeReason);
          return;
        }
        nav.pop();
        await n.fail(widget.stop.id, reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    final doorAllowed = s.profile?.doorAllowed ?? true;
    final calls = s.local.calls[widget.stop.id] ?? 0;
    final phone = widget.stop.phone?.trim() ?? '';

    final (String label, Tone tone, IconData icon) = switch (_choice) {
      _Choice.door => (t.photoAndDeliver, Tone.success, Icons.photo_camera_outlined),
      _Choice.defer => (t.moveToEnd, Tone.primary, Icons.low_priority),
      _ => (t.confirmFailure, Tone.danger, Icons.close),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BagBadge(widget.stop.bagLabel, fontSize: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(firstName(widget.stop.customerName),
                        style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: p.ink)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(t.whatHappened,
                  style: TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w800, color: p.ink)),
              const SizedBox(height: 8),
              if (doorAllowed)
                _Option(
                  selected: _choice == _Choice.door,
                  label: t.leftAtDoor,
                  sub: t.leftAtDoorSub,
                  success: true,
                  onTap: () => setState(() => _choice = _Choice.door),
                ),
              _Option(
                selected: _choice == _Choice.noAnswer,
                label: t.noAnswer,
                onTap: () => setState(() => _choice = _Choice.noAnswer),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(calls == 0 ? t.notCalledYet : t.calledTimes(calls),
                        style: TextStyle(
                            fontSize: TextSizes.caption,
                            fontWeight: FontWeight.w700,
                            color: calls == 0 ? p.warnText : p.muted)),
                    if (phone.isNotEmpty)
                      TextButton(
                        onPressed: () => callStop(context, ref, widget.stop),
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        child: Text(t.callNow, style: const TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
              _Option(
                selected: _choice == _Choice.notThere,
                label: t.notThere,
                onTap: () => setState(() => _choice = _Choice.notThere),
              ),
              _Option(
                selected: _choice == _Choice.wrongAddress,
                label: t.wrongAddress,
                onTap: () => setState(() => _choice = _Choice.wrongAddress),
              ),
              _Option(
                selected: _choice == _Choice.refused,
                label: t.refused,
                onTap: () => setState(() => _choice = _Choice.refused),
              ),
              _Option(
                selected: _choice == _Choice.other,
                label: t.otherReason,
                onTap: () => setState(() => _choice = _Choice.other),
              ),
              if (_choice == _Choice.other)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: TextField(
                    controller: _other,
                    autofocus: true,
                    maxLength: 200,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(hintText: t.otherReasonHint, counterText: ''),
                  ),
                ),
              Divider(height: 20, color: p.border),
              _Option(
                selected: _choice == _Choice.defer,
                label: t.comeBackLater,
                onTap: () => setState(() => _choice = _Choice.defer),
              ),
              const SizedBox(height: 14),
              BigButton(
                label: label,
                icon: icon,
                tone: tone,
                busy: _busy,
                onPressed: _choice == null ? null : _confirm,
              ),
              if (_choice == _Choice.door && _photoFailure != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: p.warnSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.warnBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.no_photography_outlined, color: p.warnText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          // البابُ يحتاج صورةً في كلّ مطعم — لا «إلزاميّة في هذا المطعم».
                          photoFailureText(t, _photoFailure!, required: false) ?? '',
                          style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w700, color: p.warnText),
                        ),
                      ),
                      if (_photoFailure == PhotoFailure.denied)
                        TextButton(
                          onPressed: openAppSettings,
                          style: TextButton.styleFrom(foregroundColor: p.warnText, minimumSize: const Size(48, 48)),
                          child: Text(t.openSettings,
                              style: const TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // «تستطيع التراجع» وعدٌ لا يصدق إلّا على الباب والتعذّر (مهلةُ العشر
              // ثوانٍ). التأجيلُ يُنفَّذ فورًا بلا شريط تراجع — فيُقال كيف يُعاد.
              Text(_choice == _Choice.defer ? t.deferHint : t.undoWithin10,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// خيارٌ واحدٌ من مجموعةٍ حصريّة — بلا `Radio` لأنّ الخيار يحمل ذيلًا (اتصل الآن).
class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.label,
    required this.onTap,
    this.sub,
    this.success = false,
    this.trailing,
  });

  final bool selected;
  final String label;
  final String? sub;
  final bool success;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final accent = success ? p.success : p.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        button: true,
        child: Material(
          color: success ? p.successSoft : (selected ? p.primarySoft : p.surface2),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? accent : Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? accent : p.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: TextSizes.body,
                                fontWeight: FontWeight.w700,
                                color: success ? p.successText : p.ink)),
                        if (sub != null)
                          Text(sub!,
                              style: TextStyle(fontSize: TextSizes.caption, color: success ? p.successText : p.muted)),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
