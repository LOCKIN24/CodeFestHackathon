import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/page/ai_assistant/navigation_client.dart';
import 'package:town_pass/page/ai_assistant/safe_destinations.dart';
import 'package:town_pass/util/tp_route.dart';

NavigationResult result(
  String id, {
  bool eligible = true,
  String status = 'preview',
  String decision = 'matched',
  String intent = 'browse_or_navigate',
  bool action = false,
}) => NavigationResult(
  {
    'feature_id': id,
    'source': 'name_or_alias',
    'decision': decision,
    'intent': intent,
    'action_allowed': action,
  },
  {'feature_id': id, 'status': status, 'feature_route': 'https://evil.example'},
  navigationEligible: eligible,
);

void main() {
  test('only locally specified routes and exact safe requests pass', () {
    expect(
      safeAssistantDestination(result('language_settings'), '帶我去語言設定')?.route,
      TPRoute.language,
    );
    expect(
      safeAssistantDestination(
        result('activity_information', status: 'incomplete'),
        '我要看活動訊息',
      )?.route,
      TPRoute.activityList,
    );
    for (final q in ['我要看活動詳情', '我要看活動訊息並購買票券', '我要看活動訊息和股票價格']) {
      expect(
        safeAssistantDestination(
          result('activity_information', status: 'incomplete'),
          q,
        ),
        isNull,
      );
    }
    expect(
      safeAssistantDestination(result('settings'), 'Open account settings'),
      isNull,
    );
    for (final q in [
      '我要查空氣品質',
      '我要看股票價格',
      '請幫我完成付款',
      '我要查看票夾並購買票券',
      '我要看活動詳情',
      '帶我去語言設定並付款',
    ]) {
      expect(safeAssistantDestination(result('language_settings'), q), isNull);
    }
    expect(safeAssistantDestination(result('unknown'), '帶我去語言設定'), isNull);
    expect(
      safeAssistantDestination(
        result('language_settings', status: 'incomplete'),
        '帶我去語言設定',
      ),
      isNull,
    );
    expect(
      safeAssistantDestination(
        result('language_settings', decision: 'clarify'),
        '帶我去語言設定',
      ),
      isNull,
    );
    expect(
      safeAssistantDestination(
        result('language_settings', action: true),
        '帶我去語言設定',
      ),
      isNull,
    );
    expect(
      safeAssistantDestination(
        result('language_settings', eligible: false),
        '帶我去語言設定',
      ),
      isNull,
    );
  });
}
