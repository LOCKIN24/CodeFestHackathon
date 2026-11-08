import 'package:get/get.dart';
import 'package:town_pass/bean/subscription.dart';

class SubscriptionService extends GetxService {
  final RxList<SubscriptionItem> itemList = RxList();

  Future<SubscriptionService> init() async {
    return this;
  }

  /// 新增訂閱後的服務資訊與提醒。
  void addSubscription({required String title}) {
    final now = DateTime.now();
    itemList.addAll([
      SubscriptionItem(
        title: title,
        content: '你已訂閱$title，可在這裡查看相關服務資訊與提醒。',
        datetime: now,
      ),
      SubscriptionItem(
        title: title,
        content: '你可以隨時從訂閱設定調整$title的通知偏好。',
        datetime: now,
      ),
    ]);
  }

  void removeSubscription({required String title}) {
    itemList.removeWhere((item) => item.title == title);
  }
}
