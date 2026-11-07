import 'package:town_pass/page/ai_assistant/navigation_client.dart';
import 'package:town_pass/util/tp_route.dart';

class AssistantDestination {
  const AssistantDestination(this.featureId, this.label, this.route);
  final String featureId;
  final String label;
  final String route;
}

const assistantDestinations = <String, AssistantDestination>{
  'activity_information': AssistantDestination(
    'activity_information',
    '活動訊息',
    TPRoute.activityList,
  ),
  'language_settings': AssistantDestination(
    'language_settings',
    '語言設定',
    TPRoute.language,
  ),
};

AssistantDestination? safeAssistantDestination(
  NavigationResult result,
  String query,
) {
  final c = result.choice;
  final p = result.preview;
  if (!result.navigationEligible ||
      c['decision'] != 'matched' ||
      c['intent'] != 'browse_or_navigate' ||
      c['action_allowed'] != false ||
      c['source'] != 'name_or_alias' ||
      p['feature_id'] != c['feature_id']) {
    return null;
  }
  final id = c['feature_id'];
  final normalized = query
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[!！。？?]'), '')
      .trim();
  final language = RegExp(
    r'^(?:請)?(?:帶我去|前往|打開|開啟|查看|我要看|我要去)語言(?:設定)?$|^(?:open|show|view|go to) (?:the )?language settings$',
  );
  final activity = RegExp(
    r'^(?:請)?(?:帶我去|前往|打開|開啟|查看|我要看|我要去|看看)活動(?:訊息|資訊|列表)$|^(?:open|show|view|go to) (?:the )?(?:activity|activities|events)(?: information| list)?$',
  );
  if (id == 'activity_information' &&
      p['status'] == 'incomplete' &&
      activity.hasMatch(normalized)) {
    return assistantDestinations[id];
  }
  if (id == 'language_settings' &&
      p['status'] == 'preview' &&
      language.hasMatch(normalized)) {
    return assistantDestinations[id];
  }
  return null;
}
