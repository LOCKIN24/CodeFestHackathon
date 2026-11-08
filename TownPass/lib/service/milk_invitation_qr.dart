import 'package:town_pass/service/milk_family_sync.dart';

class MilkInvitationQr {
  const MilkInvitationQr(this.address, this.code);
  final String address, code;

  String encode() => Uri(
    scheme: 'townpass-milk',
    host: 'invite',
    queryParameters: {
      'server': MilkFamilySync.validateAddress(address),
      'code': code,
    },
  ).toString();

  static MilkInvitationQr parse(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.scheme != 'townpass-milk' ||
        uri.host != 'invite' ||
        uri.path.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.queryParametersAll.length != 2 ||
        uri.queryParametersAll['server']?.length != 1 ||
        uri.queryParametersAll['code']?.length != 1) {
      throw const FormatException('這不是有效的家庭邀請 QR Code。');
    }
    final code = uri.queryParameters['code']!;
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{12}$').hasMatch(code)) {
      throw const FormatException('邀請碼格式不正確。');
    }
    return MilkInvitationQr(
      MilkFamilySync.validateAddress(uri.queryParameters['server']!),
      code,
    );
  }
}
