import 'package:flutter/material.dart';

import '../theme.dart';

/// لونٌ واحدٌ لكلّ معنى (انظر theme.dart): نيليّ = ابدأ/تنقّل · أخضر = سُلِّم ·
/// أحمر = مشكلة. والمحايدُ للثانويّ.
enum Tone { primary, success, danger, neutral }

/// الزرُّ الرئيسيّ — ٥٦ بكسل: يُضغط بإبهامٍ واحد والسيّارةُ تهتزّ.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.tone = Tone.primary,
    this.outlined = false,
    this.busy = false,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Tone tone;
  final bool outlined;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (bg, fg, soft) = switch (tone) {
      Tone.primary => (p.primary, p.onPrimary, p.primaryText),
      Tone.success => (p.success, p.onSuccess, p.successText),
      Tone.danger => (p.danger, p.onDanger, p.dangerText),
      Tone.neutral => (p.surface2, p.ink, p.ink),
    };
    final child = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: outlined ? soft : fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w700)),
              ),
            ],
          );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final size = Size.fromHeight(height);
    final action = busy ? null : onPressed;
    if (outlined) {
      return OutlinedButton(
        onPressed: action,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          shape: shape,
          foregroundColor: soft,
          backgroundColor: p.surface,
          disabledForegroundColor: p.muted,
          side: BorderSide(color: action == null ? p.border : p.borderStrong, width: 1.5),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: action,
      style: FilledButton.styleFrom(
        minimumSize: size,
        shape: shape,
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: p.surface2,
        disabledForegroundColor: p.muted,
      ),
      child: child,
    );
  }
}

/// زرُّ فعلٍ بأيقونةٍ وتسميةٍ تحتها (اتصال · واتساب · محادثة · الملاحة).
/// حين لا يستطيع أن يفعل شيئًا يقول لماذا بدل التسمية — لا زرَّ يكذب.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.disabledLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// ما يُكتب حين يتعطّل («لا رقم»).
  final String? disabledLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final enabled = onPressed != null;
    final text = enabled ? label : (disabledLabel ?? label);
    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      excludeSemantics: true,
      child: Material(
        color: enabled ? p.primarySoft : p.surface2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: enabled ? p.primaryText : p.muted),
                const SizedBox(height: 4),
                Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: TextSizes.caption,
                        fontWeight: FontWeight.w700,
                        color: enabled ? p.primaryText : p.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زرٌّ مربّعٌ بأيقونةٍ وتسميةٍ صغيرة — «بصورة» بجانب «تم التسليم».
class SquareButton extends StatelessWidget {
  const SquareButton({super.key, required this.icon, required this.label, required this.onPressed, this.size = 56});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.successSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: size + 8,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: p.successText),
                Text(label,
                    style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w700, color: p.successText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
