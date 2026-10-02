import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// ============================================================================
/// الماسح — `mode=bags`: مسحٌ متواصلٌ لملصقات الأكياس (كلُّ ملصقٍ يُحمِّل كيسَه)،
/// و`mode=org`: أوّلُ رمزِ مطعمٍ صالح يُعاد إلى شاشة الدخول.
/// ============================================================================
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, required this.mode});

  final String mode;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

enum _Flash { ok, warn, bad }

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  bool get _bags => widget.mode != 'org';

  /// الكاميرا تقرأ الملصقَ نفسَه عشرات المرّات في الثانية: نتجاهل تكرارَ آخر
  /// قراءةٍ ثانيتين، وإلّا اهتزّ الهاتفُ وتبدّلت الرسالة بلا توقّف.
  String? _lastRaw;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _popped = false;
  bool _busy = false;

  String? _flash;
  _Flash _flashKind = _Flash.ok;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(String text, _Flash kind) {
    _flashTimer?.cancel();
    setState(() {
      _flash = text;
      _flashKind = kind;
    });
    _flashTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final now = DateTime.now();
      if (raw == _lastRaw && now.difference(_lastAt) < const Duration(seconds: 2)) continue;
      _lastRaw = raw;
      _lastAt = now;
      if (_bags) {
        await _onBag(raw);
      } else {
        _onOrg(raw);
      }
    }
  }

  Future<void> _onBag(String raw) async {
    if (_busy) return;
    _busy = true;
    try {
      final t = ref.read(stringsProvider);
      final n = ref.read(driverProvider.notifier);
      final result = await n.markLoadedByScan(raw);
      if (!mounted) return;
      final bag = n.lastScannedStop?.bagLabel ?? '';
      switch (result) {
        case ScanResult.loaded:
          HapticFeedback.mediumImpact();
          _show(t.scanLoaded(bag), _Flash.ok);
        case ScanResult.alreadyLoaded:
          HapticFeedback.selectionClick();
          _show(t.scanAlready(bag), _Flash.warn);
        case ScanResult.unknown:
          HapticFeedback.heavyImpact();
          _show(t.scanUnknown, _Flash.bad);
        case ScanResult.invalid:
          HapticFeedback.heavyImpact();
          _show(t.scanInvalid, _Flash.bad);
      }
    } finally {
      _busy = false;
    }
  }

  void _onOrg(String raw) {
    if (_popped) return;
    final code = parseOrgCodeQr(raw);
    if (code == null) return; // نصٌّ آخر في مجال الكاميرا: ننتظر الرمزَ الصحيح
    _popped = true;
    HapticFeedback.mediumImpact();
    context.pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final group = _bags ? ref.watch(currentGroupProvider) : null;
    final (flashBg, flashFg) = switch (_flashKind) {
      _Flash.ok => (p.success, p.onSuccess),
      _Flash.warn => (p.warnSoft, p.warnText),
      _Flash.bad => (p.danger, p.onDanger),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_bags ? t.scanTitleBags : t.scanTitleOrg,
            style: const TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800)),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) => IconButton(
              tooltip: t.torch,
              onPressed: state.isRunning ? () => _controller.toggleTorch() : null,
              icon: Icon(state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraError(
                    message: error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? t.cameraDenied
                        : t.cameraError,
                  ),
                ),
                // إطارُ التوجيه: يعرف المندوبُ أين يضع الملصق.
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: p.onPrimary, width: 3),
                      ),
                    ),
                  ),
                ),
                if (_flash != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: flashBg, borderRadius: BorderRadius.circular(16)),
                      child: Text(_flash!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: flashFg)),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_bags ? t.scanHintBags : t.scanHintOrg,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: TextSizes.body, color: p.muted)),
                  if (group != null) ...[
                    const SizedBox(height: 12),
                    ProgressHeader(
                      title: t.loadedOf(group.loadedCount, group.total),
                      value: group.total == 0 ? 0 : group.loadedCount / group.total,
                      success: true,
                    ),
                  ],
                  if (_bags) ...[
                    const SizedBox(height: 12),
                    BigButton(label: t.done, icon: Icons.check, onPressed: () => context.pop()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      color: p.surface2,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 48, color: p.muted),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: TextSizes.body, height: 1.6, color: p.ink)),
        ],
      ),
    );
  }
}
