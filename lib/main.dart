import 'package:flutter/material.dart';
import 'screens.dart';
import 'state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const ShieldApp());
  app.askFirstRun();
}

class ShieldApp extends StatelessWidget {
  const ShieldApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ShieldSMS', debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: kBg,
            colorScheme: ColorScheme.fromSeed(seedColor: kAc, surface: kBg)),
        home: const Shell());
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellState(); }
class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) { app.refreshPerms(); app.drainSms(); app.loadCalls(); }
  }
  static const titles = ['Home', 'Messages', 'Blocked', 'Protection'];
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (ctx, _) {
        final t = app.takeToast();
        if (t != null) WidgetsBinding.instance.addPostFrameCallback((_) =>
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating)));
        return Scaffold(
          appBar: AppBar(backgroundColor: kBg, title: Text('ShieldSMS · ${titles[tab]}', style: head(18)),
              actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () =>
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SettingsScreen())))]),
          body: [const HomeScreen(), const MessagesScreen(), const BlockedScreen(), const ProtectionScreen()][tab],
          bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: [
            const NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Home'),
            const NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
            NavigationDestination(icon: Badge(isLabelVisible: app.blocked.isNotEmpty, label: Text('${app.blocked.length}'), child: const Icon(Icons.block)), label: 'Blocked'),
            const NavigationDestination(icon: Icon(Icons.phone_disabled_outlined), label: 'Protection'),
          ]));
      });
}
