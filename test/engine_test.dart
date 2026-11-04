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

  test('regression: messages reported during testing', () {
    expect(infer('hi').cls, 0);
    expect(infer('PHP 789.00 Successful Released! A/C: 09****1493 Pwede mo i-transfer sa C-ash. Click now:').cls, greaterThanOrEqualTo(1));
    expect(infer('NOTICE: Your account has received PHP 5,250.00 in cashback rewards. Please review your transaction details and confirm your mobile number to complete the reward claim. Visit: https://rewards-example.com/claim').cls, 2);
    expect(infer('Your One-Time Password (OTP) is 849201 for purchase at SHOPEE. Valid for 5 minutes. Do not share.').cls, 0);
    expect(infer('BPI: You have received PHP 500.00 from Juan Dela Cruz. Ref 88121.').cls, 0);
  });
  test('dataset-style messages', () {
    expect(infer('Congrats! Register at cxlk.uk with this number, add P50, and get your cash from our 24/7 CS').cls, greaterThanOrEqualTo(1));
    expect(infer('𝖨𝗉𝖺𝗇𝖺𝗅𝗈 𝗄𝗂𝗍𝖺 𝗇𝗀 46𝗄 𝖻𝖺𝗌𝗍𝖺 𝖧𝖠𝖳𝖨 𝗍𝖺𝗒𝗈 𝗌𝖾𝗇𝖽 𝗆𝗈 𝗌𝖼𝗋𝖾𝖾𝗇𝗌𝗁0𝗍 𝗇𝗀 𝗍𝖾𝗑𝗍 𝗄𝗈').ch['C4'], greaterThan(0));
    expect(infer('Hi! You have 0.5GB remaining in your high speed data allowance. Thank you.').cls, 0);
  });
}