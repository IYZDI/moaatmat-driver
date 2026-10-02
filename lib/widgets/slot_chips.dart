import 'package:flutter/material.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';

/// رقاقاتُ الفترات «صباحًا (6 - 9 ص) · 12» — تظهر حين في اليوم أكثرُ من مسار.
class SlotChips extends StatelessWidget {
  const SlotChips({super.key, required this.groups, required this.selectedKey, required this.onSelect, required this.t});

  final List<RouteGroupView> groups;
  final String? selectedKey;
  final ValueChanged<String> onSelect;
  final L t;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final g in groups)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                selected: g.key == selectedKey,
                onSelected: (_) => onSelect(g.key),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                backgroundColor: p.surface,
                selectedColor: p.primarySoft,
                side: BorderSide(color: g.key == selectedKey ? p.primary : p.border),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // مسارٌ انتهى يحمل علامةً — يرى المندوبُ ما بقي من يومه.
                    if (g.phase == RoutePhase.done) ...[
                      Icon(Icons.check_circle, size: 16, color: p.success),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${g.slotLabel ?? t.noSlot} · ${g.total}',
                      style: TextStyle(
                        fontSize: TextSizes.small,
                        fontWeight: FontWeight.w700,
                        color: g.key == selectedKey ? p.primaryText : p.ink2,
                      ),
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
