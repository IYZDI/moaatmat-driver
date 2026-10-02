import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// لونُ المطعم من `org_color` («#RRGGBB») — هويّتُه تظهر في شعاره وحده، لا في
/// أزرار العمل (تلك ثابتةُ المعنى في كلّ المطاعم).
Color? orgColor(String? hex) {
  final h = (hex ?? '').replaceAll('#', '').trim();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// شعارُ المطعم من الشبكة، وإن غاب أو فشل فدائرةٌ بحرفه الأوّل بلونه.
class RestaurantLogo extends StatelessWidget {
  const RestaurantLogo({super.key, required this.profile, this.size = 44});

  final DriverProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final name = profile?.orgName.trim() ?? '';
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: orgColor(profile?.color) ?? p.primary, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '•' : name.characters.first,
        style: TextStyle(color: p.onPrimary, fontSize: size * 0.42, fontWeight: FontWeight.w800),
      ),
    );
    final url = profile?.logoUrl?.trim() ?? '';
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: p.surface,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

/// رأسُ «مساري اليوم»: شعارُ المطعم واسمُه، والعنوان والتاريخ، ثمّ الأزرار.
class RestaurantHeader extends StatelessWidget {
  const RestaurantHeader({super.key, required this.profile, required this.title, this.subtitle, this.actions = const []});

  final DriverProfile? profile;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        RestaurantLogo(profile: profile),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((profile?.orgName.trim() ?? '').isNotEmpty)
                Text(profile!.orgName.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w700, color: p.muted)),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: TextSizes.headline, fontWeight: FontWeight.w800, color: p.ink)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}
