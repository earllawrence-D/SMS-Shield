import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart';

class Msg {
  final int id, t; final String from, text; final Inference res;
  /// True once the user has undone a block on this message, so it can be blocked again from the inbox.
  bool restored = false;
  Msg(this.id, this.from, this.text, this.t) : res = infer(text);
}
class CallEntry {
  final String num, action, why; final int t;
  CallEntry(this.num, this.action, this.why, this.t);
factory CallEntry.fromJson(Map j) => CallEntry(j['num'] as String, j['a'] as String, j['why'] as String, (j['t'] as int));
}

/// Bridge to Kotlin (SMS queue, call-screening rules, role request).
class Native {
  static const _c = MethodChannel('shieldsms/native');
  static Future<T?> call<T>(String m, [dynamic a]) async {
    try { return await _c.invokeMethod<T>(m, a); } on MissingPluginException { return null; } on PlatformException { return null; }
  }
  static void onSms(Future<void> Function() h) => _c.setMethodCallHandler((c) async { if (c.method == 'smsArrived') await h(); });
}

typedef DemoNumber = ({String label, String num, bool saved});
/// Demo numbers used by the call simulator (real calls use the phone's address book).
const List<DemoNumber> demoNumbers = [
  (label: 'Mom (saved)', num: '+63 917 111 2222', saved: true),
  (label: 'Unsaved +63 928 555 9812', num: '+63 928 555 9812', saved: false),
  (label: 'Unsaved +1 800 555 0199', num: '+1 800 555 0199', saved: false),
];

class AppState extends ChangeNotifier {
  final inbox = <Msg>[], blocked = <Msg>[]; var calls = <CallEntry>[];
  int thr = 2, clockMin = 0, _id = 0; bool rej = true, smsOk = false, ctcOk = false, roleOk = false;
  String? _toast; late SharedPreferences _p;

  int get nowMs => DateTime.now().millisecondsSinceEpoch + clockMin * 60000;
  String? takeToast() { final t = _toast; _toast = null; return t; }
  void _say(String m) { _toast = m; }
  List<Msg> get all => [...inbox, ...blocked]..sort((a, b) => b.t.compareTo(a.t));

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    thr = _p.getInt('thr') ?? 2; rej = _p.getBool('rej') ?? true;
    final raw = _p.getString('msgs');
    if (raw != null) {
      for (final o in jsonDecode(raw) as List) {
        final m = Msg(o['id'], o['from'], o['text'], o['t'])..restored = o['r'] == true;
        _id = _id < m.id ? m.id : _id;
        (o['b'] == true ? blocked : inbox).add(m);
      }
    } else {
      _seedAll();
    }
    Native.onSms(drainSms);
    await refreshPerms(); await drainSms(); await loadCalls();
    await Native.call('setRejectEnabled', rej);
  }
  static const _seed = [
    ('BDO-Alert', 'URGENT: Your BDO online banking access has been locked due to suspicious activity. Verify identity within 12 hours at bit.ly/bdo-sec-login to avoid permanent closure.', 20),
    ('GCash-Notice', 'Congratulations! You won 5,000 PHP raffle prize. Claim bonus at gcash-rewards-claim.me', 1400),
    ('ExpressDelivery', 'Parcel PH9021 is awaiting customs fee payment. Click track-parcel.xyz/pay to release it.', 1500),
    ('SecurityBank', 'Your One-Time Password (OTP) is 849201 for purchase at SHOPEE. Valid for 5 minutes. Do not share.', 2900),
    ('Juan Dela Cruz', 'Hey bro, let me know if we can review the thesis presentation tomorrow morning.', 4300),
    ('Mom', 'Are you coming home for dinner tonight? Let me know!', 5800),
  ];
  void _seedAll() { for (final s in _seed) { receive(s.$1, s.$2, t: nowMs - s.$3 * 60000, quiet: true); } }

  /// Fig 3.10: receive -> separate sender/content -> lazy fuzzy inference -> compare with blocking threshold.
  void receive(String from, String text, {int? t, bool quiet = false}) {
    final m = Msg(++_id, from, text, t ?? nowMs), isBlocked = m.res.cls >= thr;
    (isBlocked ? blocked : inbox).add(m);
    inbox.sort((a, b) => b.t.compareTo(a.t)); blocked.sort((a, b) => b.t.compareTo(a.t));
    if (!quiet) _say(isBlocked ? 'Blocked: ${riskNames[m.res.cls]} (${m.res.score.toStringAsFixed(2)})' : 'Delivered to inbox: ${riskNames[m.res.cls]}');
    _save(); notifyListeners();
  }

  void undo(Msg m) {
    if (blocked.remove(m)) {
      m.restored = true;
      inbox.add(m);
      inbox.sort((a, b) => b.t.compareTo(a.t));
      _say('Message restored to inbox');
      _save(); notifyListeners();
    }
  }

  /// After undoing a block the message shows in Messages; the user can review it and block it again.
  void reblock(Msg m) {
    if (inbox.remove(m)) {
      m.restored = false;
      blocked.add(m);
      blocked.sort((a, b) => b.t.compareTo(a.t));
      _say('Message blocked again');
      _save(); notifyListeners();
    }
  }

  /// Inbox messages the filter would have blocked (restored ones, including older saved data) can be blocked again.
  bool canReblock(Msg m) => inbox.contains(m);
  
  Future<void> drainSms() async {
    final raw = await Native.call<String>('drainSms');
    if (raw == null) return;
    for (final o in jsonDecode(raw) as List) { receive(o['from'], o['text'], t: (o['t'] as num).toInt()); }
  }
  void setThr(int v) { thr = v; _p.setInt('thr', v); notifyListeners(); }
  Future<void> setRej(bool v) async {
    if (v && !roleOk) { _say('Call-screening role not granted: calls cannot be rejected. Grant it in Settings.'); notifyListeners(); return; }
    rej = v; _p.setBool('rej', v); await Native.call('setRejectEnabled', v); notifyListeners();
  }
  /// Fig 3.11 is implemented once, in Kotlin (CallRules), and shared by the real service and this simulator.
  Future<void> simulateCall(DemoNumber d) async {
    final r = await Native.call<String>('evaluateCall', {'num': d.num, 'now': nowMs, 'saved': d.saved});
    if (r == null) { _say('Native call rules unavailable (run on Android).'); notifyListeners(); return; }
    final j = jsonDecode(r); _say('${j['a']}: ${j['why']}'); await loadCalls();
  }
  Future<void> loadCalls() async {
    final raw = await Native.call<String>('getCalls');
    if (raw != null) calls = (jsonDecode(raw) as List).map((e) => CallEntry.fromJson(e)).toList().reversed.toList();
    notifyListeners();
  }
  void advance() { clockMin += 21; notifyListeners(); }
  Future<void> refreshPerms() async {
    try { smsOk = await Permission.sms.isGranted; ctcOk = await Permission.contacts.isGranted; } catch (_) {}
    roleOk = (await Native.call<bool>('hasCallScreeningRole')) ?? false;
    notifyListeners();
  }
  Future<void> askSms() async { try { await Permission.sms.request(); } catch (_) {} await refreshPerms(); }
  Future<void> askContacts() async { try { await Permission.contacts.request(); } catch (_) {} await refreshPerms(); }
  Future<void> askRole() async { await Native.call('requestCallScreeningRole'); await refreshPerms(); }
    /// Asks for everything once, on first launch. Settings stays available if the user declines.
  Future<void> askFirstRun() async {
    if (_p.getBool('asked') ?? false) return;
    await _p.setBool('asked', true);
    if (!smsOk) await askSms();
    if (!ctcOk) await askContacts();
    if (!roleOk) await askRole();
  }
  Future<void> reset() async {
    await _p.clear(); await Native.call('clearCalls'); inbox.clear(); blocked.clear(); calls = []; _id = 0; clockMin = 0;
    thr = 2; rej = true; _seedAll(); notifyListeners();
  }
  void _save() => _p.setString('msgs', jsonEncode([
    ...inbox.map((m) => {'id': m.id, 'from': m.from, 'text': m.text, 't': m.t, 'b': false, 'r': m.restored}),
    ...blocked.map((m) => {'id': m.id, 'from': m.from, 'text': m.text, 't': m.t, 'b': true, 'r': false}),
  ]));
}
final app = AppState();