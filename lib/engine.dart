// Hierarchical fuzzy inference with exact early exit and lazy feature extraction (Thesis Ch. 3).
import 'dart:math';

/// PLACEHOLDER thresholds: replace with your frozen tau1/tau2.
const double tau1 = 0.30, tau2 = 0.60;
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
/// PLACEHOLDER cue lists / weights / max weights: replace with your documented values.
final Map<String, ({double max, List<_Cue> cues})> _cues = {
  'C1': (max: 1.0, cues: [_Cue(r'\b(bit\.ly|tinyurl\.com|t\.co|goo\.gl|is\.gd|cutt\.ly|rb\.gy|shorturl\.at|ow\.ly)\b', 1)]),
  'C2': (max: 1.2, cues: [
    _Cue(r'https?://\d{1,3}(\.\d{1,3}){3}', 1), _Cue(r'\.(xyz|top|click|me|icu|cc|tk|ml)\b', .6), _Cue(r'\.apk\b', 1),
    _Cue('($_org)[\\w-]*(login|sec|verify|claim|reward|fix|auth|update|pay)', .7)]),
  'C3': (max: 1.0, cues: [
    _Cue(r'(enter|provide|send|confirm|verify|ibigay|ilagay)\W+(\w+\W+){0,3}(password|otp|pin|cvv|credentials?|card|account number|identity|login|details)', .8),
    _Cue(r'password|\bpin\b|cvv|credentials?|card number|account number|mpin', .4), _Cue(r'\botp\b', .2)]),
  'C4': (max: 1.0, cues: [_Cue(r'\bclick\b|\btap\b|pindutin', .4), _Cue(r'\bverify\b|\bconfirm\b', .35),
    _Cue(r'\bclaim\b|\bunlock\b|\bupdate\b', .35), _Cue(r'\breply\b|\bcall\b|log ?in', .3)]),
  'C5': (max: 1.0, cues: [_Cue('\\b($_org)\\b', .6), _Cue(r'gov|bureau|customs', .4)]),
  'C6': (max: 1.0, cues: [_Cue(r'urgent|immediately|asap|agad|ngayon na|last chance|final notice', .5),
    _Cue(r'within\s+\d+\s*(hours?|hrs?|h|minutes?|mins?|days?)', .5), _Cue(r'expire[sd]?|deadline|today only', .3)]),
  'C7': (max: 1.0, cues: [_Cue(r'suspend|deactivat|locked|blocked|terminat|closure|penalty|legal action|arrest', .5),
    _Cue(r'won\b|prize|raffle|reward|congratulations|bonus|nanalo|premyo|free\b', .5)]),
};
/// x = min(1, sum of distinct matched cue weights / w_max)
double cue(String text, String c) {
  final d = _cues[c]!;
  return min(1.0, d.cues.fold<double>(0, (a, q) => a + (q.re.hasMatch(text) ? q.w : 0)) / d.max);
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
  final out = <double?>[null, null, null], ch = <String, double>{}, tr = <Trace>[];
  int c = 0; double s = 0; bool early = false;
  for (var j = 0; j < 3; j++) {
    final xs = subs[j].chars.map((k) => ch[k] = cue(text, k)).toList();
    final r = tsk(xs); out[j] = r.y;
    final lo = tsk(out.map((v) => v ?? 0.0).toList()).y, hi = tsk(out.map((v) => v ?? 1.0).toList()).y;
    tr.add(Trace(subs[j].name, r.y, lo, hi, r.top));
    if (j < 2 && riskOf(lo) == riskOf(hi)) { c = riskOf(lo); s = (lo + hi) / 2; early = true; break; }
    if (j == 2) { s = tsk(out.map((v) => v!).toList()).y; c = riskOf(s); }
  }
  sw.stop();
  final full = tsk(subs.map((q) => tsk(q.chars.map((k) => cue(text, k)).toList()).y).toList()).y; // reference
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
