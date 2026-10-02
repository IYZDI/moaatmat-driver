import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/undo_bar.dart';

/// سُئل الاسمَ في هذه الجلسة؟ — مرّةً واحدة: «لاحقًا» تعني لاحقًا لا بعد ثانية.
///
/// ⚠ «الجلسة» جلسةُ دخول لا عمرُ التطبيق: يُصفَّر مع كلّ تغيّرٍ في حالة الدخول،
///   وإلّا دخل مندوبٌ ثانٍ بلا اسمٍ بعد خروج الأوّل فلم يُسأل، ورآه فريقُ المطعم بلا اسم.
final namePromptedProvider = StateProvider<bool>((ref) {
  ref.watch(driverProvider.select((s) => s.auth));
  return false;
});

/// ============================================================================
/// إطارُ التبويبات الثلاثة (مساري · سجلّي · حسابي) وشريطُ التراجع فوقها.
/// ----------------------------------------------------------------------------
/// الشريطُ هنا لا في «مساري»: فعلٌ من الماسح أو من ورقةٍ يُتراجع عنه من أيّ
/// تبويبٍ يكون فيه المندوبُ حين يتذكّر خطأه.
/// ============================================================================
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskName());
  }

  /// أوّلُ دخولٍ ولا اسمَ في لوحة المطعم ⇒ نسأله مرّة. يُسأل هنا لا في شاشة
  /// الدخول لأنّ المُوجِّه ينقل المندوبَ لحظةَ الدخول فتُقتلع الورقةُ معها.
  Future<void> _maybeAskName() async {
    if (!mounted || ref.read(namePromptedProvider)) return;
    final profile = ref.read(driverProvider).profile;
    if (profile == null || profile.name.trim().isNotEmpty) return;
    ref.read(namePromptedProvider.notifier).state = true;
    await showModalBottomSheet<void>(
      context: context,
      // فوق شريط التبويبات وشريط التراجع — لا تحتهما.
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _NameSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    // الملفُّ يصل بعد الدخول بلحظة — فالسؤالُ ينتظره.
    ref.listen(driverProvider.select((s) => s.profile?.name), (_, _) => _maybeAskName());
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: widget.shell),
          const Positioned(left: 0, right: 0, bottom: 0, child: UndoBar()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.route_outlined), selectedIcon: const Icon(Icons.route), label: t.tabRoute),
          NavigationDestination(icon: const Icon(Icons.history), label: t.tabHistory),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t.tabProfile),
        ],
      ),
    );
  }
}

class _NameSheet extends ConsumerStatefulWidget {
  const _NameSheet();

  @override
  ConsumerState<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends ConsumerState<_NameSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final t = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _saving = true);
    final ok = await ref.read(driverProvider.notifier).setName(name);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(t.nameNotSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.askNameTitle, style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: p.ink)),
              const SizedBox(height: 4),
              Text(t.askNameBody, style: TextStyle(fontSize: TextSizes.body, color: p.muted)),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(hintText: t.fullName),
              ),
              const SizedBox(height: 14),
              BigButton(label: t.save, busy: _saving, onPressed: _save),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(t.later, style: const TextStyle(fontSize: TextSizes.body)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
