import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'engine.dart';
import 'state.dart';

const kOk = Color(0xFF16A36A), kWn = Color(0xFFE5A000), kBd = Color(0xFFDC4545), kAc = Color(0xFF2563EB),
    kNavy = Color(0xFF142B4A), kBg = Color(0xFFF7F9FC), kLn = Color(0xFFE5EAF0), kTx = Color(0xFF172338), kT2 = Color(0xFF718096);
const kRisk = [kOk, kWn, kBd];
TextStyle mono([double s = 11, Color c = kTx]) => GoogleFonts.jetBrainsMono(fontSize: s, color: c, fontWeight: FontWeight.w600);
TextStyle head([double s = 16, Color c = kTx]) => GoogleFonts.plusJakartaSans(fontSize: s, color: c, fontWeight: FontWeight.w700);
String hhmm(int t) { final d = DateTime.fromMillisecondsSinceEpoch(t); return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }
const _subTag = [(Color(0xFF0369A1), Color(0xFFF0F9FF)), (Color(0xFF4338CA), Color(0xFFEEF2FF)), (Color(0xFF6D28D9), Color(0xFFF5F3FF))];

Widget card(Widget child, {Color? stripe, VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kLn), borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (stripe != null) Container(width: 4, color: stripe),
          Expanded(child: Padding(padding: const EdgeInsets.all(14), child: child)),
        ])))));
Widget h2(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 8), child: Text(t.toUpperCase(), style: mono(11, kT2)));
Widget pill(int r) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: kRisk[r].withOpacity(.12), borderRadius: BorderRadius.circular(99)),
    child: Text(riskNames[r], style: TextStyle(color: kRisk[r], fontSize: 11, fontWeight: FontWeight.w600)));
Widget tag(String t, Color fg, Color bg) => Container(margin: const EdgeInsets.only(right: 4, top: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, border: Border.all(color: fg.withOpacity(.3)), borderRadius: BorderRadius.circular(6)), child: Text(t, style: mono(10, fg)));
Widget listPad(List<Widget> c) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: c);

class MsgCard extends StatelessWidget {
  final Msg m; final bool undo;
  const MsgCard(this.m, {super.key, this.undo = false});
  @override
  Widget build(BuildContext context) {
    final r = m.res;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(m.from, style: head(16), overflow: TextOverflow.ellipsis)), pill(r.cls)]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(hhmm(m.t), style: mono(11, kT2)), Text('${r.early ? '≈' : ''}${r.score.toStringAsFixed(2)}', style: mono(11, kRisk[r.cls]))]),
          Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10), width: double.infinity,
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
              child: Text(m.text, maxLines: 3, overflow: TextOverflow.ellipsis)),
          Wrap(children: [
            for (var i = 0; i < r.trace.length; i++) tag('${r.trace[i].name.toUpperCase()} ${r.trace[i].y.toStringAsFixed(2)}', _subTag[i].$1, _subTag[i].$2),
            if (r.early) tag('EARLY EXIT ${r.n}/7', kOk, Colors.white),
          ]),
        ]),
        stripe: kRisk[r.cls], onTap: () => showDetail(context, m)),
      if (undo) Padding(padding: const EdgeInsets.only(bottom: 12), child: OutlinedButton(onPressed: () => app.undo(m), child: const Text('Undo block · restore to inbox'))),
      if (app.canReblock(m)) Padding(padding: const EdgeInsets.only(bottom: 12), child: OutlinedButton.icon(onPressed: () => app.reblock(m), icon: const Icon(Icons.block), label: Text(m.restored ? 'Block again' : 'Block'))),
    ]);
  }
}

void showDetail(BuildContext ctx, Msg m) => showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: kBg, showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: .85, maxChildSize: .95, builder: (c, sc) => ListenableBuilder(listenable: app, builder: (_, __) {
      final r = m.res, isB = app.blocked.contains(m);
      return ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Text(m.from, style: head(18)),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [pill(r.cls), Text('${r.early ? '≈' : ''}${r.score.toStringAsFixed(2)}', style: mono(16, kRisk[r.cls]))]),
          const SizedBox(height: 8), Text(m.text), const SizedBox(height: 6),
          Text('Sender ID is not used in the score (content-only model).', style: mono(10, kT2)),
        ]), stripe: kRisk[r.cls]),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inference run', style: head(15)), const SizedBox(height: 6),
          Text(r.early ? 'EXACT EARLY EXIT after ${r.trace.length} of 3 subsystems' : 'Full hierarchical evaluation (3 of 3 subsystems)', style: mono(11, r.early ? kOk : kTx)),
          Text('Characteristics extracted (lazy): ${r.n}/7 · ${(r.micros / 1000).toStringAsFixed(2)} ms', style: mono(11)),
          Text('Full-evaluation reference: ${r.full.toStringAsFixed(2)} → ${riskNames[riskOf(r.full)]}  ${r.agree ? '✓ agrees' : '✗ MISMATCH'}', style: mono(11, r.agree ? kOk : kBd)),
          const SizedBox(height: 8),
          for (var i = 0; i < 3; i++) i < r.trace.length
              ? Text('${subs[i].name.toUpperCase()}  out ${r.trace[i].y.toStringAsFixed(2)}  S∈[${r.trace[i].lo.toStringAsFixed(2)}, ${r.trace[i].hi.toStringAsFixed(2)}]  top rule ${r.trace[i].top.map((l) => const ['Low', 'Med', 'High'][l]).join('/')}', style: mono(10, _subTag[i].$1))
              : Text('${subs[i].name.toUpperCase()}  skipped (not extracted)', style: mono(10, kT2)),
        ])),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Characteristics', style: head(15)),
          for (final e in charNames.entries) Padding(padding: const EdgeInsets.only(top: 8), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${e.key}: ${e.value}'), Text(r.ch[e.key]?.toStringAsFixed(2) ?? '—', style: mono())]),
            LinearProgressIndicator(value: r.ch[e.key] ?? 0, minHeight: 6, borderRadius: BorderRadius.circular(9), backgroundColor: kLn,
                color: (r.ch[e.key] ?? 0) > .66 ? kBd : (r.ch[e.key] ?? 0) > .33 ? kWn : kOk),
          ])),
        ])),
        if (isB) FilledButton(onPressed: () { app.undo(m); Navigator.pop(c); }, child: const Text('Undo block · restore to inbox')),
        if (app.canReblock(m)) FilledButton.icon(onPressed: () { app.reblock(m); Navigator.pop(c); }, icon: const Icon(Icons.block), label: Text(m.restored ? 'Block again' : 'Block')),
      ]);
    })));

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeState(); }
class _HomeState extends State<HomeScreen> {
  final from = TextEditingController(text: 'BDO-Alert'), txt = TextEditingController();
  static const samples = {
    'Smishing': 'URGENT: Your BDO account is locked. Verify your password within 12 hours at bit.ly/bdo-sec-login or face permanent closure.',
    'Parcel': 'Parcel PH9021 awaiting customs fee. Click track-parcel.xyz/pay to claim.',
    'OTP': 'G-492019 is your Google verification code. Do not share with anyone.',
    'Personal': 'Kain na tayo mamaya, see you at 7!',
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (_, __) {
        final a = app.all, early = a.where((m) => m.res.early).length;
        Widget stat(String l, int v, Color c) => Expanded(child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: mono(10, kT2)), Text('$v', style: head(26, c))])));
        return listPad([
          Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [kNavy, Color(0xFF0B1B33)]), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Shield Protection Active', style: head(18, Colors.white)), Text('LIVE', style: mono(10, kOk))]),
                const SizedBox(height: 6),
                Text('Hierarchical fuzzy inference analyzes each SMS. Auto-block at ${app.thr == 2 ? 'Highly Suspicious' : 'Suspicious and above'}.', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Text('Exact early exit on $early/${a.length} messages · 72 rules vs 2,187 flat', style: mono(10, Colors.white)),
              ])),
          Row(children: [stat('ANALYZED', a.length, kTx), const SizedBox(width: 8), stat('SUSPICIOUS', a.where((m) => m.res.cls == 1).length, kWn), const SizedBox(width: 8), stat('BLOCKED', app.blocked.length, kBd)]),
          h2('Simulate incoming SMS'),
          card(Column(children: [
            TextField(controller: from, decoration: const InputDecoration(labelText: 'Sender ID (not used in score)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: txt, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Message content', border: OutlineInputBorder())),
            Wrap(spacing: 6, children: [for (final e in samples.entries) ActionChip(label: Text(e.key), onPressed: () => txt.text = e.value)]),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
              if (txt.text.trim().isEmpty) return;
              app.receive(from.text.isEmpty ? 'Unknown' : from.text, txt.text.trim()); txt.clear();
            }, child: const Text('Receive SMS'))),
          ])),
          h2('Recent activity'), for (final m in a.take(4)) MsgCard(m),
        ]);
      });
}

class MessagesScreen extends StatefulWidget { const MessagesScreen({super.key}); @override State<MessagesScreen> createState() => _MsgState(); }
class _MsgState extends State<MessagesScreen> {
  int? f;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (_, __) {
        final l = app.inbox.where((m) => f == null || m.res.cls == f).toList();
        return listPad([
          Wrap(spacing: 6, children: [for (final e in {null: 'All', 0: 'Normal', 1: 'Suspicious', 2: 'Highly'}.entries)
            ChoiceChip(label: Text(e.value), selected: f == e.key, onSelected: (_) => setState(() => f = e.key))]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Inbox excludes blocked messages. You can block any message manually. Tap one for the fuzzy breakdown.', style: TextStyle(color: kT2))),
          if (l.isEmpty) const Text('No messages.', style: TextStyle(color: kT2)),
          for (final m in l) MsgCard(m),
        ]);
      });
}

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (_, __) => listPad([
        h2('Blocked messages (${app.blocked.length})'),
        if (app.blocked.isEmpty) const Text('Nothing blocked.', style: TextStyle(color: kT2)),
        for (final m in app.blocked) MsgCard(m, undo: true),
      ]));
}

class ProtectionScreen extends StatefulWidget { const ProtectionScreen({super.key}); @override State<ProtectionScreen> createState() => _ProtState(); }
class _ProtState extends State<ProtectionScreen> {
  DemoNumber sel = demoNumbers[1];
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (_, __) => listPad([
        card(Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reject calls from unsaved numbers', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Independent of the SMS fuzzy score', style: TextStyle(color: kT2))])),
          Switch(value: app.rej, onChanged: app.setRej)])),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Repeated-call exception', style: head(15)), const SizedBox(height: 8),
          Row(children: [for (var i = 1; i <= 4; i++) Expanded(child: Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: i == 4 ? kOk : kLn), borderRadius: BorderRadius.circular(10)),
              child: Text('Call $i\n${i == 4 ? 'Rings' : 'Rejected'}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: i == 4 ? kOk : kTx))))]),
          const SizedBox(height: 6), const Text('Applies if the 3 prior rejected calls fall within 20 minutes.', style: TextStyle(color: kT2, fontSize: 12)),
        ])),
        h2('Simulate incoming call'),
        card(Column(children: [
          DropdownButtonFormField<DemoNumber>(value: sel, decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [for (final d in demoNumbers) DropdownMenuItem(value: d, child: Text(d.label))], onChanged: (v) => setState(() => sel = v!)),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: FilledButton(onPressed: () => app.simulateCall(sel), child: const Text('Incoming call'))), const SizedBox(width: 8),
            OutlinedButton(onPressed: app.advance, child: const Text('+21 min'))]),
          Align(alignment: Alignment.centerLeft, child: Text('Virtual clock: +${app.clockMin} min', style: mono(10, kT2))),
        ])),
        h2('Call log'),
        for (final c in app.calls) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(c.num, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(c.action, style: TextStyle(color: c.action == 'Allowed' ? kOk : kBd, fontWeight: FontWeight.w600))]),
          Text('${c.why} · ${hhmm(c.t)}', style: const TextStyle(color: kT2, fontSize: 12))]), stripe: c.action == 'Allowed' ? kOk : kBd),
      ]));
}

class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key}); @override State<SettingsScreen> createState() => _SetState(); }
class _SetState extends State<SettingsScreen> {
  ({bool monotone, bool boundsOk, int rules})? v;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: kBg, title: Text('Settings', style: head(18))),
        body: ListenableBuilder(listenable: app, builder: (_, __) {
          Widget perm(String n, bool ok, VoidCallback ask) => ListTile(contentPadding: EdgeInsets.zero, title: Text(n),
              trailing: ok ? const Icon(Icons.check_circle, color: kOk) : TextButton(onPressed: ask, child: const Text('Grant')));
          Widget res(String l, bool ok) => Text('$l: ${ok ? 'PASS' : 'FAIL'}', style: mono(12, ok ? kOk : kBd));
          return listPad([
            h2('Blocking threshold'),
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<int>(segments: const [ButtonSegment(value: 2, label: Text('Highly Susp.')), ButtonSegment(value: 1, label: Text('Suspicious +'))],
                  selected: {app.thr}, onSelectionChanged: (s) => app.setThr(s.first)),
              const SizedBox(height: 6), Text('τ1=$tau1  τ2=$tau2 fixed · applies to new messages', style: mono(10, kT2))])),
            h2('Android roles and permissions'),
            card(Column(children: [
              perm('SMS (RECEIVE_SMS / READ_SMS)', app.smsOk, app.askSms),
              perm('Call-screening role', app.roleOk, app.askRole),
              perm('READ_CONTACTS', app.ctcOk, app.askContacts),
              const Text('If a role is missing, the app explains the limit and takes no action.', style: TextStyle(color: kT2, fontSize: 12))])),
            h2('Algorithm verification'),
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FilledButton(onPressed: () => setState(() => v = verify()), child: const Text('Run monotonicity + bounds test')),
              if (v != null) ...[const SizedBox(height: 8), Text('Rules: ${v!.rules} vs flat 2,187 (−96.7%)', style: mono(12)), res('Monotone on grid', v!.monotone), res('Bounds contain full score', v!.boundsOk),
                Text('Early-exit vs full agreement: ${app.all.where((m) => m.res.agree).length}/${app.all.length}', style: mono(12))],
            ])),
            OutlinedButton(onPressed: app.reset, child: const Text('Reset demo data')),
          ]);
        }));
}