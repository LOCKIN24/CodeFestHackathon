import 'package:town_pass/page/local_service/local_service_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum FeedbackType { register, login, cardUsage, perk, other }

class FeedbackViewController extends GetxController {
  final LayerLink dropdownMenuLayerLink = LayerLink();
  final OverlayPortalController overlayPortalController =
      OverlayPortalController();

  final String contactPhoneNumber = '02-27208889';

  List<FeedbackType> get feedbackTypeList => [
    FeedbackType.register,
    FeedbackType.login,
    FeedbackType.cardUsage,
    FeedbackType.perk,
    FeedbackType.other,
  ];

  final RxBool isDropdownOpened = RxBool(false);

  final Rxn<FeedbackType> feedbackType = Rxn<FeedbackType>(null);

  TextEditingController controller = TextEditingController();

  final sending = false.obs;

  Future<void> sendFeedback() async {
    if (sending.value) return;
    final text = controller.text.trim();
    if (feedbackType.value == null || text.isEmpty) {
      Get.snackbar('請完成內容', '請選擇問題類型並填寫內容。');
      return;
    }
    sending.value = true;
    try {
      await LocalServiceStore.save('意見回饋', text);
      if (isClosed) return;
      controller.clear();
      if (Get.context != null) {
        Get.snackbar('意見已儲存', '謝謝你的建議，可在使用紀錄查看。');
      }
    } catch (_) {
      if (Get.context != null) {
        Get.snackbar('儲存失敗', '內容已保留，請稍後重試。');
      }
    } finally {
      sending.value = false;
    }
  }

  @override
  void onClose() {
    controller.dispose();
    super.onClose();
  }

  void toggleDropdownMenu() {
    overlayPortalController.toggle();
    isDropdownOpened.value = !isDropdownOpened.value;
  }
}
