// Hierarchical fuzzy inference with exact early exit and lazy feature extraction (Thesis Ch. 3).
import 'dart:math';

/// Tuned on the DEVELOPMENT split of the local dataset (60/20/20, seed 42) against the provisional Revised Risk Label.
/// Re-run tools/calibrate.py once the human Consensus_Label is available, then freeze these before touching the test split.
const double tau1 = 0.16, tau2 = 0.27;
const riskNames = ['Normal', 'Suspicious', 'Highly Suspicious'];
const charNames = {
  'C1': 'Shortened URL', 'C2': 'Suspicious URL structure', 'C3': 'Sensitive-information request',
  'C4': 'Call to action', 'C5': 'Organization impersonation', 'C6': 'Urgency / time limit', 'C7': 'Threat / reward lure',
};
class Sub { final String name; final List<String> chars; const Sub(this.name, this.chars); }
const subs = [Sub('Link', ['C1', 'C2']), Sub('Request', ['C3', 'C4', 'C5']), Sub('Pressure', ['C6', 'C7'])];

int riskOf(double s) => s < tau1 ? 0 : (s < tau2 ? 1 : 2);

const _org = r'bdo|bpi|gcash|maya|metrobank|unionbank|landbank|security ?bank|chase|paypal|lbc|j&t|dhl|globe|smart|dito|sss|philhealth|pag-?ibig|bir|lto|bank';
class _Cue { final RegExp re; final double w; _Cue(String p, this.w) : re = RegExp(p, caseSensitive: false); }

/// Text preprocessing step: fold look-alike Unicode, lowercase, strip zero-width characters, undo letter-splitting evasion
/// ("c-ash" -> "cash", "p@ssword" -> "password"), keep Filipino "i-" verb prefix ("i-claim" -> "i claim").
/// Returns the cleaned text and an evasion bonus (used by C7) when letter-splitting was detected.
/// Folds look-alike Unicode (math bold/italic/sans/monospace letters and digits, fullwidth forms) to plain ASCII,
/// a common smishing evasion trick (e.g. "𝖨𝗉𝖺𝗇𝖺𝗅𝗈"). Equivalent in effect to Unicode NFKC for these ranges.
String _fold(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x1D400 && r <= 0x1D6A3) { final k = (r - 0x1D400) % 52; b.writeCharCode(k < 26 ? 0x41 + k : 0x61 + k - 26); }
    else if (r >= 0x1D7CE && r <= 0x1D7FF) { b.writeCharCode(0x30 + (r - 0x1D7CE) % 10); }
    else if (r >= 0xFF01 && r <= 0xFF5E) { b.writeCharCode(r - 0xFEE0); }
    else { b.writeCharCode(r); }
  }
  return b.toString();
}

({String text, double evasion}) prep(String raw) {
  var t = _fold(raw).replaceAll(RegExp('[\u200b\u200c\u200d\ufeff]'), '').toLowerCase();
  final split = RegExp(r'\b([a-df-hj-z])-([a-z]{2,})\b');
  final ev = split.hasMatch(t) ? 0.3 : 0.0;
  t = t.replaceAllMapped(split, (m) => '${m[1]}${m[2]}');
  t = t.replaceAllMapped(RegExp(r'\bi-(?=[a-z])'), (_) => 'i ');
  const leet = {'0': 'o', '@': 'a', r'$': 's'};
  for (var i = 0; i < 2; i++) {
    t = t.replaceAllMapped(RegExp(r'([a-z])([0@$])([a-z])'), (m) => '${m[1]}${leet[m[2]]}${m[3]}');
  }
  return (text: t.replaceAll(RegExp(r'\s+'), ' '), evasion: ev);
}

/// Cue lists, weights and maximum weights w_max (tuned on the development split; see tools/calibrate.py).
final Map<String, ({double max, List<_Cue> cues})> _cues = {
  'C1': (max: 1, cues: [
    _Cue(r'\b(bit\.ly|tinyurl\.com|t\.co|goo\.gl|is\.gd|cutt\.ly|rb\.gy|shorturl\.at|ow\.ly|t\.ly|go\.ly|2me\.ph|ln1\.ch|shorten\.so|bp\.bingo|fb\.me)\b', 1)]),
  'C2': (max: 0.8, cues: [
    _Cue(r'https?://\d{1,3}(\.\d{1,3}){3}', 1),
    _Cue(r'\.apk\b', 1),
    _Cue(r'\b[a-z0-9-]+\.(uk|eu|de|cx|xyz|tw|wang|vip|fi|top|click|icu|cc|tk|ml|bid|win|live|site|online|club|pw|ws|lol|fun|buzz|cfd|pro|info|bet)\b', 0.8),
    _Cue(r'\b[a-z]*\d+[a-z]*\.(com|ph|net|co)\b', 0.6),
    _Cue(r'(bdo|bpi|gcash|maya|metrobank|unionbank|landbank|security ?bank|chase|paypal|lbc|j&t|dhl|globe|smart|dito|sss|philhealth|pag-?ibig|bir|lto|bank)[\w-]*(login|sec|verify|claim|reward|fix|auth|update|pay)', 0.7),
    _Cue(r'https?://[\w.]*-[\w.-]*\.', 0.4),
    _Cue(r'/(claim|verify|login|reward|secure|update|confirm)\b', 0.5)]),
  'C3': (max: 1, cues: [
    _Cue(r'(enter|provide|send|confirm|verify|ibigay|ilagay)\W+(\w+\W+){0,3}(password|otp|pin|cvv|credentials?|card|account number|identity|login|details)', 0.8),
    _Cue(r'password|\bpin\b|cvv|credentials?|card number|account number|mpin', 0.4),
    _Cue(r'\b(mobile|phone|contact) number\b', 0.5),
    _Cue(r'\b(transaction|account|personal|billing|bank) (details|information|info)\b', 0.5)]),
  'C4': (max: 3, cues: [
    _Cue(r'\b(click|tap|visit|open|pindutin|bisitahin|register|magregister|sumali|join|play|sign ?up|deposit|top ?up|claim|maclaim|makuha|download|apply|renew|subscribe|activate|log ?in|login|reply|call|text|txt|pay|shop|checkout|scroll|follow|invite|dial)\b', 0.5),
    _Cue(r'\b(enjoy|get|grab|catch|use|try|avail|pasok|tara|complete|verify|confirm|update|transfer|review)\b', 0.4),
    _Cue(r'\b(dito lang|only at|only on)\b', 0.4)]),
  'C5': (max: 3, cues: [
    _Cue(r'\b(bdo|bpi|gcash|maya|metrobank|unionbank|landbank|security ?bank|chase|paypal|lbc|j&t|dhl|globe|smart|dito|sss|philhealth|pag-?ibig|bir|lto|bank|shopee|lazada|tiktok|facebook|pagcor|ditozens?|tnt|gomo|pldt|nbi|dict)\b', 0.6),
    _Cue(r'gov|bureau|customs', 0.4),
    _Cue(r'\b(g ?cash|cash ?app|e-?wallet|wallet)\b', 0.4)]),
  'C6': (max: 3, cues: [
    _Cue(r'urgent|immediately|asap|agad|kaagad|ngayon na|last chance|final notice|act fast|within\s+\d+\s*(hours?|hrs?|h|minutes?|mins?|days?)', 0.5),
    _Cue(r'\b(last call|last \d+ days?|ends? (today|tonight|soon)|hurry|dont miss|don.t miss|tonight|ngayong araw)\b', 0.5),
    _Cue(r'\btoday\b', 0.4),
    _Cue(r'expire[sd]?|expiry|expiring|deadline|limited', 0.3),
    _Cue(r'\bngayon\b', 0.3),
    _Cue(r'\bnow\b', 0.15)]),
  'C7': (max: 0.5, cues: [
    _Cue(r'suspend|deactivat|locked|blocked|terminat|closure|penalty|legal action|arrest', 0.5),
    _Cue(r'won\b|prize|raffle|rewards?\b|cash ?back|congratulations|bonus|nanalo|premyo|ayuda|payout|free\b|libre|released|credited|approved|rebate|spins?|jackpot|panalo|angpao|credits?|cash ?out|winnings?|natanggap|refund|maswerte|giveaway', 0.5),
    _Cue(r'(php|₱|\bp)\s?\d[\d,]*(\.\d+)?', 0.3)]),
};
/// x = min(1, (sum of matched cue weights + evasion bonus for C7) / w_max). Expects text already passed through prep().
double cue(String text, String c, {double evasion = 0}) {
  final d = _cues[c]!;
  final extra = c == 'C7' ? evasion : 0.0;
  return min(1.0, (d.cues.fold<double>(0, (a, q) => a + (q.re.hasMatch(text) ? q.w : 0)) + extra) / d.max);
}

/// Triangular MFs Low(0,0,.5) Medium(0,.5,1) High(.5,1,1)
List<double> mu(double x) => x <= .5 ? [1 - 2 * x, 2 * x, 0] : [0, 2 - 2 * x, 2 * x - 1];

class Tsk { final double y; final List<int> top; final int rules; Tsk(this.y, this.top, this.rules); }
/// Zero-order TSK over the complete 3^n rule base; consequent c_r = sum(l_i) / (2n); product t-norm.
Tsk tsk(List<double> xs) {
  final n = xs.length, m = xs.map(mu).toList(), total = pow(3, n).toInt();
  double sw = 0, sc = 0, bw = -1; var best = <int>[];
  for (var i = 0; i < total; i++) {
    double w = 1; int s = 0, k = i; final lv = <int>[];
    for (var j = 0; j < n; j++) { final l = k % 3; k ~/= 3; w *= m[j][l]; s += l; lv.add(l); }
    sw += w; sc += w * s / (2 * n);
    if (w > bw) { bw = w; best = lv; }
  }
  return Tsk(sc / sw, best, total);
}

class Trace { final String name; final double y, lo, hi; final List<int> top;
  Trace(this.name, this.y, this.lo, this.hi, this.top); }
class Inference {
  final int cls; final double score; final bool early; final Map<String, double> ch; final List<Trace> trace; final int micros; final double full;
  Inference(this.cls, this.score, this.early, this.ch, this.trace, this.micros, this.full);
  int get n => ch.length;
  bool get agree => cls == riskOf(full);
}

/// Algorithm 3.1: sequential subsystems (Link, Request, Pressure), lazy cue extraction,
/// attainable bounds (unevaluated outputs = 0 for min, 1 for max), exact early exit.
Inference infer(String text) {
  final sw = Stopwatch()..start();
  final p = prep(text); // text preprocessing
  final out = <double?>[null, null, null], ch = <String, double>{}, tr = <Trace>[];
  int c = 0; double s = 0; bool early = false;
  for (var j = 0; j < 3; j++) {
    final xs = subs[j].chars.map((k) => ch[k] = cue(p.text, k, evasion: p.evasion)).toList();
    final r = tsk(xs); out[j] = r.y;
    final lo = tsk(out.map((v) => v ?? 0.0).toList()).y, hi = tsk(out.map((v) => v ?? 1.0).toList()).y;
    tr.add(Trace(subs[j].name, r.y, lo, hi, r.top));
    if (j < 2 && riskOf(lo) == riskOf(hi)) { c = riskOf(lo); s = (lo + hi) / 2; early = true; break; }
    if (j == 2) { s = tsk(out.map((v) => v!).toList()).y; c = riskOf(s); }
  }
  sw.stop();
  final full = tsk(subs.map((q) => tsk(q.chars.map((k) => cue(p.text, k, evasion: p.evasion)).toList()).y).toList()).y; // reference
  return Inference(c, s, early, ch, tr, sw.elapsedMicroseconds, full);
}

/// Grid check of monotonicity of the final subsystem + random check that bounds contain the full score.
({bool monotone, bool boundsOk, int rules}) verify() {
  const n = 11; final g = List.generate(n, (i) => i / 10);
  double f(double a, double b, double c) => tsk([a, b, c]).y;
  var mono = true, ok = true;
  for (final a in g) { for (final b in g) { for (var i = 1; i < n; i++) {
    if (f(a, b, g[i]) < f(a, b, g[i - 1]) - 1e-12 || f(a, g[i], b) < f(a, g[i - 1], b) - 1e-12 || f(g[i], a, b) < f(g[i - 1], a, b) - 1e-12) mono = false;
  } } }
  final rnd = Random(7);
  for (var i = 0; i < 500; i++) {
    final x = List.generate(3, (_) => rnd.nextDouble()), k = rnd.nextInt(4), v = f(x[0], x[1], x[2]);
    final lo = tsk(List.generate(3, (j) => j < k ? x[j] : 0.0)).y, hi = tsk(List.generate(3, (j) => j < k ? x[j] : 1.0)).y;
    if (v < lo - 1e-12 || v > hi + 1e-12) ok = false;
  }
  return (monotone: mono, boundsOk: ok, rules: 9 + 27 + 9 + 27);
}