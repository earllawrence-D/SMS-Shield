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
        ...app.all.map((m) => MessageItem(
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
    if (mounted) setState(() {});
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
      if (!widget.dark) ...[
        const _Glow(top: 100, left: -70, color: Color(0x447ab6ff)),
        const _Glow(top: 350, right: -90, color: Color(0x44d2a0ff)),
        const _Glow(bottom: 120, left: 80, color: Color(0x33ffc49c))
      ],
      if (widget.dark) ...[
        const _Glow(top: 100, right: -120, color: Color(0x18777777)),
        const _Glow(bottom: 80, left: -110, color: Color(0x12707070)),
      ],
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
                Text(active,
                    style: TextStyle(
                        color: ink, fontSize: 22, fontWeight: FontWeight.w400)),
                const SizedBox(height: 12),
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
                  Text('Messages blocked by ShieldSMS',
                      style: TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  for (final m in app.blocked)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _messageCard(MessageItem(
                            m.from,
                            m.text,
                            DateTime.fromMillisecondsSinceEpoch(m.t),
                            Risk.high))),
                  if (app.blocked.isEmpty)
                    Text('No blocked messages', style: TextStyle(color: muted)),
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
                                style: TextStyle(color: muted, fontSize: 12))
                          ])),
                      Text(call.action,
                          style: TextStyle(color: ink, fontSize: 12))
                    ])),
                  if (app.calls.isEmpty)
                    Text('No call activity yet',
                        style: TextStyle(color: muted)),
                ] else ...[
                  _glassPanel(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Android permissions',
                            style: TextStyle(color: ink, fontSize: 16)),
                        const SizedBox(height: 8),
                        _permissionRow('SMS access', app.smsOk, app.askSms),
                        _permissionRow('Contacts', app.ctcOk, app.askContacts),
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
          top: MediaQuery.paddingOf(context).top + 78,
          right: 16,
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
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: Colors.white.withOpacity(widget.dark ? .55 : .8)))),
        child: Row(children: [
          const _Shield(),
          const Spacer(),
          _themeSwitch(),
          const SizedBox(width: 24),
          IconButton(
              onPressed: () => setState(() => menu = !menu),
              tooltip: menu ? 'Close navigation menu' : 'Open navigation menu',
              icon: SizedBox(
                  width: 28,
                  height: 24,
                  child: CustomPaint(painter: _MenuPainter(ink)))),
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
                widget.dark ? Alignment.centerLeft : Alignment.centerRight,
            child: CircleAvatar(
              radius: 12,
              backgroundColor:
                  widget.dark ? const Color(0xff454545) : Colors.white,
              child: Icon(Icons.nightlight_round,
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

  Widget _dashboard() => _frosted(
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
                      : Border(left: BorderSide(color: ink.withOpacity(.45)))),
              child: Column(children: [
                Text(['Analyzed', 'Suspicious', 'Blocked'][i],
                    style: TextStyle(color: ink, fontSize: 14)),
                const SizedBox(height: 4),
                Text(['30', '5', '10'][i],
                    style: TextStyle(
                        color: ink, fontSize: 28, fontWeight: FontWeight.w400))
              ]),
            ))
        ]),
      ),
      22);
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

  void _showMessageDetails(MessageItem item) {
    Msg? original;
    for (final message in app.all) {
      if (message.from == item.sender &&
          message.text == item.body &&
          DateTime.fromMillisecondsSinceEpoch(message.t) == item.received) {
        original = message;
        break;
      }
    }
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

class _Glow extends StatelessWidget {
  final double? top, bottom, left, right;
  final Color color;
  const _Glow(
      {this.top, this.bottom, this.left, this.right, required this.color});
  @override
  Widget build(BuildContext context) => Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
          child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(color: color, blurRadius: 75, spreadRadius: 35)
                  ]))));
}

class _Shield extends StatelessWidget {
  const _Shield();
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 48, height: 52, child: CustomPaint(painter: _ShieldPainter()));
}

class _MenuPainter extends CustomPainter {
  final Color color;
  const _MenuPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final y in [size.height * .2, size.height * .5, size.height * .8]) {
      canvas.drawLine(Offset(1, y), Offset(size.width - 1, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _MenuPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(s.width * .5, 1)
      ..lineTo(s.width * .96, s.height * .18)
      ..lineTo(s.width * .91, s.height * .62)
      ..quadraticBezierTo(
          s.width * .83, s.height * .84, s.width * .5, s.height - 1)
      ..quadraticBezierTo(
          s.width * .17, s.height * .84, s.width * .09, s.height * .62)
      ..lineTo(s.width * .04, s.height * .18)
      ..close();
    c.drawPath(
        p,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xffffed9b), Color(0xffb78328)])
              .createShader(Offset.zero & s)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final crown = Path()
      ..moveTo(s.width * .32, s.height * .43)
      ..lineTo(s.width * .28, s.height * .29)
      ..lineTo(s.width * .40, s.height * .36)
      ..lineTo(s.width * .50, s.height * .24)
      ..lineTo(s.width * .60, s.height * .36)
      ..lineTo(s.width * .72, s.height * .29)
      ..lineTo(s.width * .68, s.height * .43)
      ..close();
    final gold = Paint()
      ..color = const Color(0xffffd875)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(crown, gold);
    c.drawLine(Offset(s.width * .34, s.height * .48),
        Offset(s.width * .66, s.height * .48), gold);
    c.drawLine(Offset(s.width * .50, s.height * .14),
        Offset(s.width * .50, s.height * .22), gold);
    c.drawLine(Offset(s.width * .45, s.height * .18),
        Offset(s.width * .55, s.height * .18), gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
