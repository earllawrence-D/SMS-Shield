import 'package:flutter_test/flutter_test.dart';
import 'package:shieldsms/engine.dart';

void main() {
  test('hierarchical rule count is 72 and flat is 2187', () {
    expect(tsk([0, 0]).rules + tsk([0, 0, 0]).rules * 2 + tsk([0, 0]).rules, 72);
    expect(tsk(List.filled(7, 0.0)).rules, 2187);
  });
  test('monotone and bounds valid', () {
    final r = verify();
    expect(r.monotone, isTrue);
    expect(r.boundsOk, isTrue);
  });
  test('early exit always agrees with full hierarchical evaluation', () {
    for (final t in ['hello po', 'URGENT verify password at bit.ly/bdo-sec-login within 12 hours or account locked',
      'Your OTP is 123456. Do not share.', 'Click http://1.2.3.4/a.apk to claim your prize', 'Kain tayo mamaya']) {
      expect(infer(t).agree, isTrue, reason: t);
    }
  });
  test('smishing is Highly Suspicious, personal is Normal', () {
    expect(infer('URGENT: Your BDO account is locked. Verify your password within 12 hours at bit.ly/bdo-sec-login or face permanent closure.').cls, 2);
    expect(infer('Kain na tayo mamaya, see you at 7!').cls, 0);
  });
}
