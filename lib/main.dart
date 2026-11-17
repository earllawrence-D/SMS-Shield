import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart' show riskNames, verify;
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const MessagesApp());
  app.askFirstRun();
}

class MessageItem {
  final String sender, body;
  final DateTime received;
  final Risk risk;
  const MessageItem(this.sender, this.body, this.received, this.risk);
}

enum Risk { high, suspicious, normal }

class MessagesApp extends StatefulWidget {
  const MessagesApp({super.key});
  @override
  State<MessagesApp> createState() => _MessagesAppState();
}

class _MessagesAppState extends State<MessagesApp> {
  bool dark = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => dark = prefs.getBool('darkMode') ?? false);
    });
  }

  void _toggleTheme() {
    setState(() => dark = !dark);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('darkMode', dark));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            fontFamily: GoogleFonts.inter().fontFamily,
            scaffoldBackgroundColor: const Color(0xffeef2fb),
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xff8878de))),
        darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: GoogleFonts.inter().fontFamily,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xff090909),
            colorScheme: const ColorScheme.dark(
                primary: Color(0xffffd875), surface: Color(0xff171717))),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: MessagesHome(dark: dark, onTheme: _toggleTheme),
      );
}

class MessagesHome extends StatefulWidget {
  final bool dark;
  final VoidCallback onTheme;
  const MessagesHome({super.key, required this.dark, required this.onTheme});
  @override
  State<MessagesHome> createState() => _MessagesHomeState();
}

class _MessagesHomeState extends State<MessagesHome>
    with WidgetsBindingObserver {
  final search = TextEditingController();
  List<MessageItem> get messages => [
        ...app.inbox.map((m) => MessageItem(
            m.from,
            m.text,
            DateTime.fromMillisecondsSinceEpoch(m.t),
            switch (m.res.cls) {
              2 => Risk.high,
              1 => Risk.suspicious,
              _ => Risk.normal
            }))
      ]..sort((a, b) => b.received.compareTo(a.received));
  bool menu = false;
  String active = 'Messages';
  ({bool monotone, bool boundsOk, int rules})? verification;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_onMessagesChanged);
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    setState(() {});
    final message = app.takeToast();
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ));
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      app.refreshPerms();
      app.drainSms();
      app.loadCalls();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.removeListener(_onMessagesChanged);
    search.dispose();
    super.dispose();
  }

  Color get ink => widget.dark ? Colors.white : const Color(0xff17151d);
  Color get muted => ink.withOpacity(.60);
  Color get glass => widget.dark
      ? Colors.white.withOpacity(.09)
      : Colors.white.withOpacity(.58);
  Color get edge => widget.dark
      ? Colors.white.withOpacity(.25)
      : Colors.white.withOpacity(.85);
  Widget _frosted(Widget child, double radius) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.dark ? .28 : .12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: child),
        ),
      );
  String dateLabel(DateTime date) {
    final now = DateTime.now(),
        today = DateTime(now.year, now.month, now.day),
        day = DateTime(date.year, date.month, date.day);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
    if (day == today) return time;
    if (day == today.subtract(const Duration(days: 1)))
      return 'Yesterday, $time';
    if (!day.isBefore(today.subtract(const Duration(days: 7))))
      return '${[
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun'
      ][date.weekday - 1]}, $time';
    return '${[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][date.month - 1]} ${date.day}, ${date.year}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.toLowerCase();
    final visible = messages
        .where((m) => '${m.sender} ${m.body} ${dateLabel(m.received)}'
            .toLowerCase()
            .contains(q))
        .toList();
    return Scaffold(
        body: Stack(children: [
      Positioned.fill(
          child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: widget.dark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                              Color(0xff050505),
                              Color(0xff111111),
                              Color(0xff080808)
                            ])
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                              Color(0xffe8f2ff),
                              Color(0xfff1edff),
                              Color(0xfffff0e8)
                            ])))),
      SafeArea(
          child: Column(children: [
        _header(),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 640
              ? (constraints.maxWidth - 600) / 2
              : 20.0;
          final bottomPadding = active == 'Messages' ? 104.0 : 24.0;
          return RefreshIndicator(
              onRefresh: app.drainSms,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 8, horizontalPadding, bottomPadding),
                  children: [
                    if (active == 'Messages') ...[
                      _dashboard(),
                      const SizedBox(height: 18),
                      Text('Recent activity',
                          style: TextStyle(color: ink, fontSize: 18)),
                      const SizedBox(height: 10),
                      for (final m in visible)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _messageCard(m)),
                      if (visible.isEmpty)
                        Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                q.isEmpty
                                    ? 'No messages yet'
                                    : 'No matching messages',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted))),
                    ] else if (active == 'Blocked') ...[
                      const SizedBox(height: 12),
                      for (final m in app.blocked)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(children: [
                              _messageCard(MessageItem(
                                  m.from,
                                  m.text,
                                  DateTime.fromMillisecondsSinceEpoch(m.t),
                                  Risk.high)),
                              const SizedBox(height: 8),
                              _undoBlockCard(m),
                            ])),
                      if (app.blocked.isEmpty)
                        Text('No blocked messages',
                            style: TextStyle(color: muted)),
                    ] else if (active == 'Unknown calls') ...[
                      Text('Recent call screening activity',
                          style: TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 12),
                      for (final call in app.calls)
                        _glassPanel(Row(children: [
                          Icon(Icons.phone_disabled_outlined,
                              color: call.action == 'Allowed'
                                  ? const Color(0xff34c759)
                                  : const Color(0xffff3b30)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(call.num,
                                    style: TextStyle(color: ink, fontSize: 15)),
                                Text(call.why,
                                    style:
                                        TextStyle(color: muted, fontSize: 12))
                              ])),
                          Text(call.action,
                              style: TextStyle(color: ink, fontSize: 12))
                        ])),
                      if (app.calls.isEmpty)
                        Text('No call activity yet',
                            style: TextStyle(color: muted)),
                    ] else ...[
                      _glassPanel(Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Appearance',
                                  style: TextStyle(color: ink, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(widget.dark ? 'Dark mode' : 'Light mode',
                                  style: TextStyle(color: muted, fontSize: 13)),
                            ])),
                        _themeSwitch(),
                      ])),
                      const SizedBox(height: 12),
                      _glassPanel(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Android permissions',
                                style: TextStyle(color: ink, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                                'SMS access lets ShieldSMS analyze messages already in your inbox and new incoming texts.',
                                style: TextStyle(color: muted, fontSize: 12)),
                            const SizedBox(height: 4),
                            _permissionRow('SMS access', app.smsOk, app.askSms),
                            _permissionRow(
                                'Contacts', app.ctcOk, app.askContacts),
                            _permissionRow(
                                'Call screening', app.roleOk, app.askRole)
                          ])),
                      const SizedBox(height: 12),
                      _glassPanel(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Algorithm verification',
                                style: TextStyle(color: ink, fontSize: 16)),
                            const SizedBox(height: 10),
                            FilledButton(
                                onPressed: () =>
                                    setState(() => verification = verify()),
                                child: const Text('Run verification')),
                            if (verification != null) ...[
                              Text(
                                  'Monotonicity: ${verification!.monotone ? 'PASS' : 'FAIL'}',
                                  style: TextStyle(color: ink)),
                              Text(
                                  'Score bounds: ${verification!.boundsOk ? 'PASS' : 'FAIL'} · ${verification!.rules} rules',
                                  style: TextStyle(color: ink))
                            ]
                          ])),
                    ],
                  ]));
        })),
      ])),
      if (active == 'Messages')
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.paddingOf(context).bottom + 14,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _search(),
            ),
          ),
        ),
      if (menu)
        Positioned.fill(
            child: GestureDetector(
                onTap: () => setState(() => menu = false),
                child: Container(color: Colors.transparent))),
      Positioned(
          top: MediaQuery.paddingOf(context).top + 60,
          right: 22,
          child: IgnorePointer(
              ignoring: !menu,
              child: AnimatedOpacity(
                  opacity: menu ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: AnimatedScale(
                      scale: menu ? 1 : .94,
                      alignment: Alignment.topRight,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: _menuCard())))),
    ]));
  }

  Widget _header() => Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(children: [
          Text(active,
              style: TextStyle(
                  color: ink, fontSize: 22, fontWeight: FontWeight.w400)),
          const Spacer(),
          IconButton(
              onPressed: () => setState(() => menu = !menu),
              tooltip: menu ? 'Close navigation menu' : 'Open navigation menu',
              icon: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: menu ? 1 : 0),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutBack,
                builder: (context, progress, child) => SizedBox(
                  width: 28,
                  height: 24,
                  child: CustomPaint(
                    painter: _MenuPainter(ink, progress.clamp(0, 1)),
                  ),
                ),
              )),
        ]),
      );
  Widget _themeSwitch() => Tooltip(
      message: widget.dark ? 'Switch to light mode' : 'Switch to dark mode',
      child: GestureDetector(
        onTap: widget.onTheme,
        child: Container(
          width: 56,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: ink.withOpacity(.22),
              borderRadius: BorderRadius.circular(30)),
          child: Align(
            alignment:
                widget.dark ? Alignment.centerRight : Alignment.centerLeft,
            child: CircleAvatar(
              radius: 12,
              backgroundColor:
                  widget.dark ? const Color(0xff454545) : Colors.white,
              child: Icon(
                  widget.dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 15,
                  color: widget.dark ? Colors.white : const Color(0xff725e25)),
            ),
          ),
        ),
      ));
  Widget _glassPanel(Widget child) => _frosted(
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: glass,
          border: Border.all(color: edge),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.14),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: child,
      ),
      22);

  Widget _permissionRow(
          String label, bool granted, Future<void> Function() request) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: ink))),
          if (granted)
            const Icon(Icons.check_circle, color: Color(0xff34c759), size: 20)
          else
            TextButton(onPressed: request, child: const Text('Grant')),
        ]),
      );

  Widget _dashboard() {
    final analyzed = app.all.length;
    final suspicious = app.all.where((m) => m.res.cls > 0).length;
    final blocked = app.blocked.length;
    final counts = [analyzed, suspicious, blocked];
    return _frosted(
        Container(
          decoration: BoxDecoration(
              color: glass,
              border: Border.all(color: edge),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(.13),
                    blurRadius: 24,
                    offset: const Offset(0, 9))
              ],
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [glass, glass.withOpacity(.68)])),
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                  child: Container(
                decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(
                            left: BorderSide(color: ink.withOpacity(.45)))),
                child: Column(children: [
                  Text(['Analyzed', 'Suspicious', 'Blocked'][i],
                      style: TextStyle(color: ink, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${counts[i]}',
                      style: TextStyle(
                          color: ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w400))
                ]),
              ))
          ]),
        ),
        22);
  }

  Widget _messageCard(MessageItem m) {
    final color = switch (m.risk) {
      Risk.high => const Color(0xffff3b30),
      Risk.suspicious => const Color(0xffffb800),
      Risk.normal => const Color(0xff34c759)
    };
    final status = switch (m.risk) {
      Risk.high => 'Highly Suspicious',
      Risk.suspicious => 'Suspicious',
      Risk.normal => 'Normal'
    };
    return InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showMessageDetails(m),
        onLongPress: () {
          final message = _messageForItem(m);
          if (message != null && app.canReblock(message)) {
            _confirmBlock(m, message);
          }
        },
        child: _frosted(
            Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
                decoration: BoxDecoration(
                    color: glass,
                    border: Border.all(color: edge),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.14),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(m.sender,
                                style: TextStyle(color: ink, fontSize: 17))),
                        Text(m.risk == Risk.high ? '! ' : '',
                            style: TextStyle(
                                color: color,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        Text(status,
                            style: TextStyle(color: color, fontSize: 13))
                      ]),
                      const SizedBox(height: 10),
                      Text(m.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: ink, fontSize: 16, height: 1.25)),
                      const SizedBox(height: 9),
                      Align(
                          alignment: Alignment.centerRight,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.access_time, size: 12, color: muted),
                            const SizedBox(width: 4),
                            Text(dateLabel(m.received),
                                style: TextStyle(color: muted, fontSize: 12))
                          ]))
                    ])),
            22));
  }

  Widget _undoBlockCard(Msg message) => _frosted(
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => app.undo(message),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: glass,
                border: Border.all(color: edge),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                const Icon(Icons.block_rounded,
                    color: Color(0xffff3b30), size: 19),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Blocked message',
                        style: TextStyle(color: ink, fontSize: 13))),
                Icon(Icons.undo_rounded, color: ink, size: 18),
                const SizedBox(width: 6),
                Text('Undo block',
                    style: TextStyle(
                        color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        18,
      );

  Future<void> _confirmBlock(MessageItem item, Msg message) async {
    final shouldBlock = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: _frosted(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: widget.dark
                    ? const Color(0xff242126).withOpacity(.94)
                    : const Color(0xfff8f6fc).withOpacity(.94),
                border: Border.all(color: edge),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xffff3b30).withOpacity(.13),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: Color(0xffff3b30), size: 27),
                ),
                const SizedBox(height: 14),
                Text('Block this message?',
                    style: TextStyle(
                        color: ink, fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Move this message from ${item.sender} to Blocked?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: glass,
                    border: Border.all(color: edge),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(item.body,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ink, fontSize: 14, height: 1.35)),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffff3b30),
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text('Block message'),
                    ),
                  ),
                ]),
              ]),
            ),
            26,
          ),
        ),
      ),
    );
    if (shouldBlock == true && mounted && app.canReblock(message)) {
      app.reblock(message);
    }
  }

  Msg? _messageForItem(MessageItem item) {
    for (final message in app.all) {
      if (message.from == item.sender &&
          message.text == item.body &&
          DateTime.fromMillisecondsSinceEpoch(message.t) == item.received) {
        return message;
      }
    }
    return null;
  }

  void _showMessageDetails(MessageItem item) {
    final original = _messageForItem(item);
    if (original == null) return;
    final message = original;
    final status = riskNames[message.res.cls];
    final color = switch (message.res.cls) {
      2 => const Color(0xffff3b30),
      1 => const Color(0xffffb800),
      _ => const Color(0xff34c759),
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.dark ? const Color(0xff171717) : const Color(0xfff3f1f8),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(item.sender,
                          style: TextStyle(color: ink, fontSize: 20))),
                  Text(status,
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600))
                ]),
                const SizedBox(height: 12),
                Text(item.body,
                    style: TextStyle(color: ink, fontSize: 16, height: 1.4)),
                const SizedBox(height: 8),
                Text(dateLabel(item.received),
                    style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 18),
                Text('Message analysis',
                    style: TextStyle(
                        color: ink, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final name in const ['Link', 'Request', 'Pressure'])
                  _analysisRow(message, name),
              ]),
        ),
      ),
    );
  }

  Widget _analysisRow(Msg message, String name) {
    final matches = message.res.trace.where((entry) => entry.name == name);
    final trace = matches.isEmpty ? null : matches.first;
    final value = trace == null
        ? 'Not evaluated'
        : '${(trace.y * 100).round()}% risk cues';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(Icons.check_circle_outline, size: 17, color: muted),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name, style: TextStyle(color: ink, fontSize: 14))),
          Text(value, style: TextStyle(color: muted, fontSize: 13))
        ]));
  }

  Widget _search() => _frosted(
      Container(
        height: 50,
        padding: const EdgeInsets.only(left: 20, right: 12),
        decoration: BoxDecoration(
            color: glass,
            border: Border.all(color: edge),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.12),
                  blurRadius: 18,
                  offset: const Offset(0, 7))
            ]),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: ink),
                  decoration: InputDecoration(
                      hintText: 'Search messages...',
                      hintStyle: TextStyle(color: muted),
                      border: InputBorder.none,
                      isDense: true))),
          if (search.text.isEmpty)
            Icon(Icons.search, color: ink, size: 26)
          else
            IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  search.clear();
                  setState(() {});
                },
                icon: Icon(Icons.close, color: ink, size: 22))
        ]),
      ),
      40);
  Widget _menuCard() => _frosted(
      Container(
        width: 246,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: glass,
            border: Border.all(color: edge),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 35)
            ]),
        child: Column(children: [
          for (final e in const [
            (Icons.chat_bubble_outline, 'Messages'),
            (Icons.phone_disabled_outlined, 'Unknown calls'),
            (Icons.block, 'Blocked'),
            (Icons.settings_outlined, 'Settings')
          ])
            ListTile(
                dense: true,
                leading: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 18,
                      child: Center(
                          child: active == e.$2
                              ? Icon(Icons.circle, size: 8, color: ink)
                              : null)),
                  const SizedBox(width: 10),
                  Icon(e.$1, color: ink)
                ]),
                title: Text(e.$2, style: TextStyle(color: ink, fontSize: 15)),
                onTap: () {
                  setState(() {
                    active = e.$2;
                    menu = false;
                  });
                })
        ]),
      ),
      28);
}

class _MenuPainter extends CustomPainter {
  final Color color;
  final double progress;
  const _MenuPainter(this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final t = progress;
    Offset mix(Offset a, Offset b) => Offset(
          a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t,
        );
    canvas.drawLine(
      mix(Offset(1, size.height * .2), Offset(5, 4)),
      mix(Offset(size.width - 1, size.height * .2),
          Offset(size.width - 5, size.height - 4)),
      line,
    );
    final middleLine = Paint()
      ..color = color.withOpacity(1 - t)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(1, size.height * .5),
        Offset(size.width - 1, size.height * .5), middleLine);
    canvas.drawLine(
      mix(Offset(1, size.height * .8), Offset(5, size.height - 4)),
      mix(Offset(size.width - 1, size.height * .8), Offset(size.width - 5, 4)),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _MenuPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
