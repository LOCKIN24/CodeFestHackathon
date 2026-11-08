import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/service/milk_invitation_qr.dart';

void main() {
  test('QR carries only the private relay address and one-time code', () {
    final payload = const MilkInvitationQr(
      'http://192.168.1.20:8765',
      'ABCDEFGHJKLM',
    ).encode();
    final invitation = MilkInvitationQr.parse(payload);
    expect(invitation.address, 'http://192.168.1.20:8765');
    expect(invitation.code, 'ABCDEFGHJKLM');
    expect(payload, isNot(contains('student')));
    expect(payload, isNot(contains('0123456789012345')));
  });
  test('rejects invalid codes, extra fields and untrusted relay addresses', () {
    for (final value in [
      'https://example.com',
      'townpass-milk://invite?server=http%3A%2F%2F192.168.1.2%3A8765&code=bad',
      'townpass-milk://invite?server=http%3A%2F%2F8.8.8.8&code=ABCDEFGHJKLM',
      'townpass-milk://invite?server=http%3A%2F%2F192.168.1.2&code=ABCDEFGHJKLM&extra=x',
      'townpass-milk://invite?server=http%3A%2F%2F192.168.1.2&code=ABCDEFGHJKLM&code=ABCDEFGHJKLM',
    ]) {
      expect(() => MilkInvitationQr.parse(value), throwsFormatException);
    }
  });
}
