# Candidate control and modal source index

This mechanically extracted index is a review aid, not a complete semantic element map. Each row quotes its handler expression and exact source line. Dynamic labels, parent screen, destination, required state, and whether nonempty callbacks work still require human review. Reused components may appear in multiple screens. IDs derive from source path and line and are review references, not stable accessibility identifiers. Commented or multiline code may still produce false positives.

| Source | Line | Handler expression | Status |
|---|---:|---|---|
| `TownPass/lib/page/home/home_view.dart` | 26 | `onPressed: () => Get.toNamed(TPRoute.account),` | needs_review |
| `TownPass/lib/page/qr_code_scan/qr_code_scan_view.dart` | 30 | `onPressed: () => Get.back(),` | needs_review |
| `TownPass/lib/page/qr_code_scan/qr_code_scan_view.dart` | 82 | `onTap: () async => switch (await controller.scanFromImage()) {` | needs_review |
| `TownPass/lib/page/qr_code_scan/qr_code_scan_view.dart` | 96 | `onTap: () => TPDialog.showInfo(` | needs_review |
| `TownPass/lib/page/suspend_account/suspend_account_view.dart` | 72 | `onPressed: () {},` | not_implemented |
| `TownPass/lib/page/suspend_account/suspend_account_view.dart` | 102 | `onTap: _launchCustomerServiceMail, // 改為呼叫新建立的私有方法` | needs_review |
| `TownPass/lib/page/bill/bill_view.dart` | 94 | `onTap: () {},` | not_implemented |
| `TownPass/lib/page/bill/bill_view.dart` | 127 | `onTap: () {},` | not_implemented |
| `TownPass/lib/page/bill/bill_view.dart` | 170 | `onTap: () async => await TPRoute.openUri(uri: item.uri),` | needs_review |
| `TownPass/lib/page/bill/bill_view.dart` | 196 | `onTap: () => onTap?.call(),` | needs_review |
| `TownPass/lib/page/activity_detail/activity_detail_view.dart` | 75 | `onPressed: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/perk/perk_view.dart` | 23 | `onPressed: () => Get.toNamed(TPRoute.account),` | needs_review |
| `TownPass/lib/page/perk/perk_view.dart` | 31 | `onPressed: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/city_service_edit/city_service_edit_view.dart` | 40 | `onPressed: () => controller.cancelEdit(),` | needs_review |
| `TownPass/lib/page/city_service_edit/city_service_edit_view.dart` | 47 | `onPressed: () => controller.isEditMode.value =` | needs_review |
| `TownPass/lib/page/city_service_edit/city_service_edit_view.dart` | 56 | `onPressed: () {` | needs_review |
| `TownPass/lib/page/city_service_edit/city_service_edit_view.dart` | 116 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/basic_info_edit/basic_info_edit_view.dart` | 70 | `onPressed: () {` | needs_review |
| `TownPass/lib/page/message/message_view.dart` | 43 | `onPressed: () {},` | not_implemented |
| `TownPass/lib/page/feedback/feedback_view.dart` | 29 | `onTap: controller.toggleDropdownMenu,` | needs_review |
| `TownPass/lib/page/feedback/feedback_view.dart` | 53 | `onTap: () {` | needs_review |
| `TownPass/lib/page/feedback/feedback_view.dart` | 183 | `onPressed: controller.sendFeedback,` | needs_review |
| `TownPass/lib/page/city_service/city_service_view.dart` | 27 | `onPressed: () => Get.toNamed(TPRoute.account),` | needs_review |
| `TownPass/lib/page/city_service/city_service_view.dart` | 63 | `onTap: () => Get.toNamed(TPRoute.serviceEdit),` | needs_review |
| `TownPass/lib/page/basic_info/basic_info_view.dart` | 31 | `onTap: () {` | needs_review |
| `TownPass/lib/page/basic_info/basic_info_view.dart` | 53 | `onTap: () {` | needs_review |
| `TownPass/lib/page/basic_info/basic_info_view.dart` | 77 | `onTap: () {` | needs_review |
| `TownPass/lib/page/basic_info/basic_info_view.dart` | 98 | `onTap: () {` | needs_review |
| `TownPass/lib/page/basic_info/basic_info_view.dart` | 122 | `onTap: () {` | needs_review |
| `TownPass/lib/page/online_police/online_police_view.dart` | 26 | `onTap: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/online_police/online_police_view.dart` | 47 | `onTap: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/online_police/online_police_view.dart` | 76 | `onTap: () async => await launchUrl(Uri.parse('tel://110')),` | needs_review |
| `TownPass/lib/page/online_police/online_police_view.dart` | 90 | `onTap: () async => await launchUrl(Uri.parse('tel://119')),` | needs_review |
| `TownPass/lib/page/online_police/online_police_view.dart` | 110 | `onTap: () async => await launchUrl(Uri.parse('tel://165')),` | needs_review |
| `TownPass/lib/page/online_police/online_police_view.dart` | 124 | `onTap: () async => await launchUrl(Uri.parse('tel://113')),` | needs_review |
| `TownPass/lib/page/online_police/online_police_view.dart` | 160 | `onTap: () => onTap?.call(),` | needs_review |
| `TownPass/lib/page/activity_list/activity_list_view.dart` | 42 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/phone_call_user_agreement/phone_call_user_agreement_view.dart` | 35 | `onPressed: () async => await controller.agree(),` | needs_review |
| `TownPass/lib/page/portfolioAndAuth/portfolio_auth_view.dart` | 43 | `onPressed: (index) {` | needs_review |
| `TownPass/lib/page/account/account_view.dart` | 40 | `onTap: () async => await Get.toNamed(TPRoute.setting)?.then((value) => controller.syncAccount()),` | needs_review |
| `TownPass/lib/page/account/account_view.dart` | 58 | `onTap: () async => await Get.toNamed(TPRoute.setting)?.then((value) => controller.syncAccount()),` | needs_review |
| `TownPass/lib/page/account/account_view.dart` | 68 | `onTap: () => Get.toNamed(TPRoute.message),` | needs_review |
| `TownPass/lib/page/account/account_view.dart` | 73 | `onTap: () {},` | not_implemented |
| `TownPass/lib/page/account/account_view.dart` | 79 | `onTap: () {},` | not_implemented |
| `TownPass/lib/page/account/account_view.dart` | 84 | `onTap: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/account/account_view.dart` | 91 | `onTap: () => Get.toNamed(TPRoute.feedback),` | needs_review |
| `TownPass/lib/page/setting/setting_view.dart` | 28 | `onTap: () => Get.toNamed(TPRoute.basicInfo),` | needs_review |
| `TownPass/lib/page/setting/setting_view.dart` | 33 | `onTap: () => Get.toNamed(TPRoute.language),` | needs_review |
| `TownPass/lib/page/setting/setting_view.dart` | 38 | `onTap: () => Get.toNamed(TPRoute.settingStartPage),` | needs_review |
| `TownPass/lib/page/setting/setting_view.dart` | 45 | `onTap: () => Get.toNamed(TPRoute.invoiceReceipt),` | needs_review |
| `TownPass/lib/page/setting/setting_view.dart` | 54 | `onTap: () => Get.toNamed(TPRoute.suspendAccount),` | needs_review |
| `TownPass/lib/page/main/main_view.dart` | 47 | `onTap: (index) => controller.currentIndex.value = index,` | needs_review |
| `TownPass/lib/page/account/widget/account_app_bar.dart` | 48 | `onPressed: () => Get.back(),` | needs_review |
| `TownPass/lib/page/account/widget/account_view_footer.dart` | 25 | `onTap: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/account/widget/account_view_footer.dart` | 36 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/city_service/widget/pinned_service_item_widget.dart` | 24 | `onTap: onTap?.call ??` | needs_review |
| `TownPass/lib/page/city_service/widget/pinned_service_widget.dart` | 38 | `_AddMoreButton(onTap: onMoreTap),` | needs_review |
| `TownPass/lib/page/city_service/widget/pinned_service_widget.dart` | 52 | `onTap: switch (isEditMode) {` | needs_review |
| `TownPass/lib/page/city_service/widget/pinned_service_widget.dart` | 93 | `onTap: () => onTap?.call(),` | needs_review |
| `TownPass/lib/page/city_service/widget/trending_service_widget.dart` | 46 | `onTap: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/city_service/widget/trending_service_widget.dart` | 145 | `onTap: () => onTap?.call(),` | needs_review |
| `TownPass/lib/page/city_service/widget/official_service_card/official_service_card_top_right.dart` | 38 | `onTap: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/city_service/widget/official_service_card/official_service_card_top_right.dart` | 82 | `onTap: () async => await TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/city_service/widget/official_service_card/official_service_card_bottom_right.dart` | 14 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/city_service/widget/official_service_card/official_service_card_bottom_left.dart` | 38 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/city_service/widget/official_service_card/official_service_card_bottom_left.dart` | 82 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/city_service/widget/official_service_card/official_service_card_top_left.dart` | 18 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/message/widget/_message_list_row.dart` | 12 | `onTap: () => Get.toNamed(TPRoute.messageDetail, arguments: item),` | needs_review |
| `TownPass/lib/page/bill/widget/bill_app_bar.dart` | 67 | `onPressed: () => Get.toNamed(TPRoute.account),` | needs_review |
| `TownPass/lib/page/bill/widget/bill_app_bar.dart` | 79 | `onTap: () => TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/bill/widget/bill_app_bar.dart` | 86 | `onTap: () => TPRoute.openUri(` | needs_review |
| `TownPass/lib/page/bill/widget/bill_app_bar.dart` | 121 | `onTap: onTap,` | needs_review |
| `TownPass/lib/page/home/widget/city_news/city_news_widget.dart` | 22 | `onTap: () {},` | not_implemented |
| `TownPass/lib/page/home/widget/city_news/city_news_widget.dart` | 30 | `onTap: () {` | needs_review |
| `TownPass/lib/page/home/widget/city_news/city_news_widget.dart` | 56 | `onTap: onTap?.call,` | needs_review |
| `TownPass/lib/page/home/widget/subscription/subscription_item_widget.dart` | 21 | `onTap: () => Get.toNamed(` | needs_review |
| `TownPass/lib/page/home/widget/subscription/subscription_widget.dart` | 42 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/home/widget/subscription/subscription_widget.dart` | 69 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/home/widget/subscription/subscription_widget.dart` | 126 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/home/widget/activity_info/activity_banner_widget.dart` | 57 | `onTap: () => Get.toNamed(TPRoute.activityDetail, arguments: activity),` | needs_review |
| `TownPass/lib/page/home/widget/activity_info/activity_info_widget.dart` | 34 | `onTap: () async {` | needs_review |
| `TownPass/lib/page/home/widget/news/news_banner_widget.dart` | 58 | `onTap: () async => await TPRoute.openUri(uri: item.webUrl),` | needs_review |
| `TownPass-Services/src/views/CouponDetail.vue` | 67 | `<button @click="onBackButtonClick">` | needs_review |
| `TownPass-Services/src/views/CouponDetail.vue` | 133 | `@click.prevent="isMapDialogOpen = true"` | needs_review |
| `TownPass-Services/src/views/CouponDetail.vue` | 141 | `<BaseButton v-if="!route.query.needUse" @click="isStoreDialogOpen = true" :outline="true">` | needs_review |
| `TownPass-Services/src/views/CouponDetail.vue` | 145 | `@click="isUseDialogOpen = true"` | needs_review |
| `TownPass-Services/src/views/TopQnAListView.vue` | 45 | `@click="onPanelExpandClick(item.id)"` | needs_review |
| `TownPass-Services/src/views/TopQnAListView.vue` | 70 | `<BaseButton shape="rounded" @click="router.push(\`/qna/categories\`)">` | needs_review |
| `TownPass-Services/src/views/DisasterReportView.vue` | 47 | `<button class="search-button" @click="onSearchClick">` | needs_review |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 206 | `@click.prevent="checkLimit(seriesItem.id)"` | needs_review |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 221 | `@click.prevent="checkLimit(seriesItem.id)"` | needs_review |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 243 | `@click.stop="isLibrarySelectDialogOpen = true"` | needs_review |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 249 | `@click="onSubmitClick()"` | needs_review |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 289 | `@click.prevent="` | needs_review |
| `TownPass-Services/src/views/CouponListView.vue` | 78 | `<button class="search-button" @click="onSearchClick">` | needs_review |
| `TownPass-Services/src/views/FeePaymentOthersView.vue` | 50 | `@click="onExpandClick(item.name)"` | needs_review |
| `TownPass-Services/src/views/CounterCallingDetailView.vue` | 86 | `@click="toggleRegularlyUsedItem(subCounterItem)"` | needs_review |
| `TownPass-Services/src/views/CounterCallingDetailView.vue` | 98 | `@click="toggleRegularlyUsedItem(subCounterItem)"` | needs_review |
| `TownPass-Services/src/views/CounterCallingDetailView.vue` | 130 | `@click.prevent="isMapDialogOpen = true"` | needs_review |
| `TownPass-Services/src/views/CounterCallingDetailView.vue` | 138 | `@click="onPhoneCallClick(subCounterItem.info.tel)"` | needs_review |
| `TownPass-Services/src/views/DisasterReportFormView.vue` | 147 | `@click.prevent="isShowLocaionModal = true"` | needs_review |
| `TownPass-Services/src/views/DisasterReportFormView.vue` | 246 | `<BaseButton :disabled="isSubmitDisabled" @click="onSubmitClick">送出</BaseButton>` | needs_review |
| `TownPass-Services/src/views/FeePaymentResultView.vue` | 62 | `<a href="" @click.prevent="selectAllBills" class="text-primary-500 underline">全部繳清</a>` | needs_review |
| `TownPass-Services/src/views/FeePaymentResultView.vue` | 94 | `<BaseButton class="w-full" :disabled="paymentModel.length === 0" @click="onSubmitClick()">` | needs_review |
| `TownPass-Services/src/views/FeePaymentResultView.vue` | 110 | `@click="router.push({ name: 'fee-payment-others' })"` | needs_review |
| `TownPass-Services/src/views/FeePaymentFinishedView.vue` | 56 | `@click="router.push({ name: 'fee-payment-others' })"` | needs_review |
| `TownPass-Services/src/views/SubscriptionView.vue` | 80 | `@click="subscription.is_expand = !subscription.is_expand"` | needs_review |
| `TownPass-Services/src/views/SubscriptionView.vue` | 99 | `@click="onSubmitClick(subscription)"` | needs_review |
| `TownPass-Services/src/views/SubscriptionView.vue` | 108 | `@click="onSubmitClick(subscription)"` | needs_review |
| `TownPass-Services/src/views/FeePaymentStepView.vue` | 47 | `<button @click="router.back()">` | needs_review |
| `TownPass-Services/src/views/FeePaymentStepView.vue` | 80 | `@click="onWayClick('台北富邦信用卡')"` | needs_review |
| `TownPass-Services/src/views/FeePaymentStepView.vue` | 89 | `@click="onWayClick('悠遊付')"` | needs_review |
| `TownPass-Services/src/views/FeePaymentStepView.vue` | 95 | `@click="onWayClick('台北富邦信用卡')"` | needs_review |
| `TownPass-Services/src/views/FeePaymentStepView.vue` | 101 | `@click="onWayClick('智慧支付平台')"` | needs_review |
| `TownPass-Services/src/views/FeePaymentSearchView.vue` | 92 | `<button class="search-button" @click="onSearchClick">` | needs_review |
| `TownPass-Services/src/views/FeePaymentSearchView.vue` | 100 | `<a href="" class="ml-auto underline" @click.prevent="clearSearchHistory">清除</a>` | needs_review |
| `TownPass-Services/src/views/FeePaymentSearchView.vue` | 107 | `@click="saveKeywordClick(keyword)"` | needs_review |
| `TownPass-Services/src/views/TicketPayment.vue` | 32 | `<button @click="router.back()">` | needs_review |
| `TownPass-Services/src/views/TicketPayment.vue` | 65 | `@click="onWayClick('台北富邦信用卡')"` | needs_review |
| `TownPass-Services/src/views/TicketPayment.vue` | 74 | `@click="onWayClick('悠遊付')"` | needs_review |
| `TownPass-Services/src/views/TicketPayment.vue` | 80 | `@click="onWayClick('台北富邦信用卡')"` | needs_review |
| `TownPass-Services/src/views/TicketPayment.vue` | 86 | `@click="onWayClick('智慧支付平台')"` | needs_review |
| `TownPass-Services/src/views/QnAListView.vue` | 49 | `@click="currentCategory = category"` | needs_review |
| `TownPass-Services/src/views/QnAListView.vue` | 73 | `@click="onPanelExpandClick(item.id)"` | needs_review |
| `TownPass-Services/src/views/CitizenReportListView.vue` | 102 | `<button class="w-full flex justify-between" @click="onCategoryClick('CR-99')">` | needs_review |
| `TownPass-Services/src/views/FormView.vue` | 66 | `<form v-show="activeStep === 1" @submit.stop="">` | needs_review |
| `TownPass-Services/src/views/FormView.vue` | 78 | `<BaseButton @click="onSubmitClick">下一步</BaseButton>` | needs_review |
| `TownPass-Services/src/views/CitizenReportView.vue` | 151 | `@click="onServicePhoneClick"` | needs_review |
| `TownPass-Services/src/views/CitizenReportView.vue` | 168 | `<button class="search-button" @click="onSearchButtonClick">` | needs_review |
| `TownPass-Services/src/views/CitizenReportView.vue` | 174 | `<button class="search-button" @click="togglePopover">` | needs_review |
| `TownPass-Services/src/views/CitizenReportView.vue` | 187 | `<button class="search-button" @click="togglePopover">` | needs_review |
| `TownPass-Services/src/views/SurroundingServiceView.vue` | 383 | `<div v-if="isMapReady" class="gps" @click="getPositionClick">` | needs_review |
| `TownPass-Services/src/views/SurroundingServiceView.vue` | 391 | `@click="` | needs_review |
| `TownPass-Services/src/views/SurroundingServiceView.vue` | 417 | `<a class="text-primary-500" @click="isExpandList = true">展開列表</a>` | needs_review |
| `TownPass-Services/src/views/SurroundingServiceView.vue` | 461 | `<button class="text-primary-500 px-7 py-2 w-full" @click="isShowGeoError = false">` | needs_review |
| `TownPass-Services/src/views/HomeView.vue` | 149 | `<button class="search-button" @click="onSearchClick">` | needs_review |
| `TownPass-Services/src/views/HomeView.vue` | 166 | `@click="onExpandClick(item.name)"` | needs_review |
| `TownPass-Services/src/views/HomeView.vue` | 236 | `@click="activeSituation = 'apply'"` | needs_review |
| `TownPass-Services/src/views/HomeView.vue` | 243 | `@click="activeSituation = 'done'"` | needs_review |
| `TownPass-Services/src/views/CounterCallingView.vue` | 87 | `<a href="javascript:void(0)" @click="isEditOpen = true"> 變更 </a>` | needs_review |
| `TownPass-Services/src/views/CounterCallingView.vue` | 151 | `<BaseButton :shape="'rounded'" @click="onSubmitClick" class="mt-4 w-full">` | needs_review |
| `TownPass-Services/src/views/LibraryKeywordSearchView.vue` | 188 | `<button class="search-button" @click="onSearchClick">` | needs_review |
| `TownPass-Services/src/views/LibraryKeywordSearchView.vue` | 223 | `<a href="javascript:void(0)" class="ml-auto text-primary-500" @click="clearSearchHistory">` | needs_review |
| `TownPass-Services/src/views/LibraryKeywordSearchView.vue` | 232 | `@click="saveKeywordClick(keyword)"` | needs_review |
| `TownPass-Services/src/views/LibraryKeywordSearchView.vue` | 247 | `@click="saveKeywordClick(keyword)"` | needs_review |
| `TownPass-Services/src/views/TicketDetail.vue` | 43 | `<button @click="router.back()">` | needs_review |
| `TownPass-Services/src/views/TicketDetail.vue` | 85 | `@click.prevent="isMapDialogOpen = true"` | needs_review |
| `TownPass-Services/src/views/TicketDetail.vue` | 102 | `<button @click="isIllustrateExpand = !isIllustrateExpand">` | needs_review |
| `TownPass-Services/src/views/TicketDetail.vue` | 133 | `<button @click="isIntroduceExpand = !isIntroduceExpand">` | needs_review |
| `TownPass-Services/src/views/SubscriptionItemListView.vue` | 30 | `@click="item.is_read = true"` | needs_review |
| `TownPass-Services/src/views/PoliceReportView.vue` | 178 | `<BaseButton :disabled="!isAgree.length" @click="onAgreeClick" class="w-full mt-4">` | needs_review |
| `TownPass-Services/src/views/CitizenReportFormView.vue` | 84 | `@click.prevent="isShowLocaionModal = true"` | needs_review |
| `TownPass-Services/src/views/CitizenReportFormView.vue` | 138 | `<BaseButton :disabled="isAgree === 'N'" @click="onSubmitClick" class="w-full">` | needs_review |
| `TownPass-Services/src/views/CitizenReportSearchView.vue` | 37 | `<button class="search-button" @click="onSearchClick">` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 52 | `<button @click="router.back()">` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 87 | `@click="ticketCounts.adult--"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 98 | `@click="ticketCounts.adult++"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 114 | `@click="ticketCounts.concession--"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 125 | `@click="ticketCounts.concession++"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 141 | `@click="ticketCounts.citizen--"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 152 | `@click="ticketCounts.citizen++"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 168 | `@click="ticketCounts.group--"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 179 | `@click="ticketCounts.group++"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 188 | `@click="isUsagePeriodInformationModalOpen = true"` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 205 | `<BaseButton :disabled="totalPrice === 0" class="w-full mt-1" @click="onPaymentButtonClick">` | needs_review |
| `TownPass-Services/src/views/BuyTicketView.vue` | 236 | `@click="isUsagePeriodInformationModalOpen = false"` | needs_review |
| `TownPass-Services/src/views/HotSpotView.vue` | 77 | `@click.prevent="isMapDialogOpen = true"` | needs_review |
| `TownPass-Services/src/views/HotSpotView.vue` | 94 | `<button @click="isIntroduceExpand = !isIntroduceExpand">` | needs_review |
| `TownPass-Services/src/views/TicketExchange.vue` | 31 | `<button @click="onBackButtonClick" class="absolute top-1/2 -translate-y-1/2 left-4">` | needs_review |
| `TownPass-Services/src/views/LibraryNoticeListView.vue` | 70 | `@click="isDialogOpen = true"` | needs_review |
| `TownPass-Services/src/views/LibraryNoticeListView.vue` | 88 | `@click="isDialogOpen = true"` | needs_review |
| `TownPass-Services/src/components/molecules/FeePaymentForm.vue` | 240 | `<BaseButton class="w-full" @click="onSubmitClick()"> 查詢 </BaseButton>` | needs_review |
| `TownPass-Services/src/components/molecules/CollapseItem.vue` | 24 | `<button class="w-full flex justify-between" @click="onCategoryClick(item.id)">` | needs_review |
| `TownPass-Services/src/components/molecules/MessageModal.vue` | 16 | `<!-- <Button @click="$emit('confirm')"> 確認 </Button> -->` | needs_review |
| `TownPass-Services/src/components/molecules/DatePicker.vue` | 45 | `@click="togglePopover"` | needs_review |
| `TownPass-Services/src/components/molecules/LibraryTabs.vue` | 39 | `@click="activeTab = index"` | needs_review |
| `TownPass-Services/src/components/molecules/LibrarySelectDialog.vue` | 122 | `<button @click="isOpen = false" class="outline-none">` | needs_review |
| `TownPass-Services/src/components/molecules/PoliceReportGeneralForm.vue` | 252 | `<button class="text-grey-400 text-left pl-6" @click.prevent="onAgreeENClick">` | needs_review |
| `TownPass-Services/src/components/molecules/PoliceReportGeneralForm.vue` | 257 | `<BaseButton :disabled="!isAgree.length" @click="onNextStepClick">下一步</BaseButton>` | needs_review |
| `TownPass-Services/src/components/molecules/PoliceReportDetailForm.vue` | 116 | `@click.prevent="isShowLocaionModal = true"` | needs_review |
| `TownPass-Services/src/components/molecules/PoliceReportDetailForm.vue` | 205 | `<button class="text-grey-400 text-left pl-6" @click.prevent="onAgreeENClick">` | needs_review |
| `TownPass-Services/src/components/molecules/PoliceReportDetailForm.vue` | 210 | `<BaseButton :disabled="!isAgree.length" @click="onSubmitClick">送出</BaseButton>` | needs_review |
| `TownPass-Services/src/components/molecules/LibrarySelectTabs.vue` | 35 | `@click="activeTab = index"` | needs_review |
| `TownPass-Services/src/components/molecules/ApplyServiceInfoForm.vue` | 123 | `@click.prevent="isExpand = !isExpand"` | needs_review |
| `TownPass-Services/src/components/molecules/ApplyServiceInfoForm.vue` | 188 | `@click.prevent="onMultipleChangeClick(index)"` | needs_review |
| `TownPass-Services/src/components/molecules/UploadSection.vue` | 98 | `<button @click.prevent="isOpen = true">` | needs_review |
| `TownPass-Services/src/components/molecules/UploadSection.vue` | 150 | `<button class="absolute -top-3 -right-3" @click.prevent="onCancelClick(count)">` | needs_review |
| `TownPass-Services/src/components/molecules/UploadSection.vue` | 217 | `@click="isOpen = false"` | needs_review |
| `TownPass-Services/src/components/molecules/FixedTitleSection.vue` | 14 | `<button @click="router.back()" class="absolute left-[10px]">` | needs_review |
| `TownPass-Services/src/components/molecules/ServiceTabs.vue` | 35 | `@click="activeTab = index"` | needs_review |
| `TownPass-Services/src/components/molecules/FeePaymentTabs.vue` | 30 | `@click="activeTab = index"` | needs_review |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 146 | `@click="onPanelExpandClick(item.name)"` | needs_review |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 154 | `@click="` | needs_review |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 182 | `@click="onSelect(place)"` | needs_review |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 211 | `@click="onPanelExpandClick(item.name)"` | needs_review |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 232 | `@click="onSelect(place)"` | needs_review |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 259 | `@click="isShowClearHistory = false"` | needs_review |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 265 | `@click="` | needs_review |
| `TownPass-Services/src/components/molecules/GeneralInfoForm.vue` | 76 | `@click.prevent="isExpand = !isExpand"` | needs_review |
| `TownPass-Services/src/components/atoms/BaseButton.vue` | 44 | `@click.prevent="() => emit('click')"` | needs_review |
| `TownPass-Services/src/components/atoms/BaseDialog.vue` | 79 | `@click="onNegativeClick"` | needs_review |
| `TownPass-Services/src/components/atoms/BaseDialog.vue` | 86 | `@click="onPositiveClick"` | needs_review |
| `TownPass-Services/src/components/atoms/BaseMultipleSelect.vue` | 55 | `@click="isOpen = true"` | needs_review |
| `TownPass-Services/src/components/atoms/BaseMultipleSelect.vue` | 120 | `@click="onConfirmClick"` | needs_review |
| `TownPass-Services/src/components/organisms/LocationModal.vue` | 137 | `<button @click="isShowLocaionModal = false">` | needs_review |
| `TownPass-Services/src/components/organisms/LocationModal.vue` | 154 | `<button class="absolute top-1/2 -translate-y-1/2 right-2" @click="addressText = ''">` | needs_review |
| `TownPass-Services/src/components/organisms/LocationModal.vue` | 177 | `@click="onConfirmClick"` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMapView.vue` | 285 | `<div v-if="isMapReady" class="gps" @click="getPositionClick">` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMapView.vue` | 293 | `@click="` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMapView.vue` | 319 | `<a class="text-primary-500" @click="isExpandList = true">展開列表</a>` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMapView.vue` | 361 | `<button class="text-primary-500 px-7 py-2 w-full" @click="isShowGeoError = false">` | needs_review |
| `TownPass-Services/src/components/organisms/SpotListView.vue` | 40 | `@click="` | needs_review |
| `TownPass-Services/src/components/organisms/SpotListView.vue` | 96 | `@click="emit('update:isExpandList', false)"` | needs_review |
| `TownPass-Services/src/components/organisms/SpotListView.vue` | 107 | `@click="scrollToTop"` | needs_review |
| `TownPass-Services/src/components/organisms/FormPreview.vue` | 195 | `<BaseButton outline @click="emit('onModify')">修改</BaseButton>` | needs_review |
| `TownPass-Services/src/components/organisms/FormPreview.vue` | 196 | `<BaseButton :disabled="isAgree === 'N'" @click="onSubmitClick">送出</BaseButton>` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 135 | `@click="onExpandClick(item.name)"` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 176 | `@click.prevent="` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 190 | `@click.prevent="` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 207 | `@click.prevent="` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 294 | `@click.prevent="` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 313 | `<a href="" class="flex items-center" @click.prevent="sortHistoryRecords">` | needs_review |
| `TownPass-Services/src/components/organisms/SpotDetailView.vue` | 21 | `@click="emit('update:isExpandDetail', false)"` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryDetailView.vue` | 31 | `@click="emit('update:isExpandDetail', false)"` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryDetailView.vue` | 42 | `<a href="" @click.prevent="isMapDialogOpen = true">` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryDetailView.vue` | 50 | `@click="onPhoneCallClick(selectedLibrary.phone)"` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryListView.vue` | 38 | `@click="` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryListView.vue` | 68 | `@click="emit('update:isExpandList', false)"` | needs_review |
| `TownPass-Services/src/components/organisms/LibraryListView.vue` | 79 | `@click="scrollToTop"` | needs_review |

## Modal candidates

| Source | Line | Declaration |
|---|---:|---|
| `TownPass/lib/page/qr_code_scan/qr_code_scan_view.dart` | 83 | `null => await TPDialog.showError(title: '錯誤', content: '無法辨識 QR Code'),` |
| `TownPass/lib/page/qr_code_scan/qr_code_scan_view.dart` | 96 | `onTap: () => TPDialog.showInfo(` |
| `TownPass-Services/src/views/CouponDetail.vue` | 152 | `<BaseDialog` |
| `TownPass-Services/src/views/CouponDetail.vue` | 161 | `<BaseDialog` |
| `TownPass-Services/src/views/CouponDetail.vue` | 170 | `<BaseDialog` |
| `TownPass-Services/src/views/CouponDetail.vue` | 179 | `<BaseDialog` |
| `TownPass-Services/src/views/CouponDetail.vue` | 189 | `<BaseDialog` |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 255 | `<LibrarySelectDialog` |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 261 | `<BaseDialog` |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 269 | `<BaseDialog` |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 303 | `<BaseDialog` |
| `TownPass-Services/src/views/LibraryBookDetailView.vue` | 322 | `<BaseDialog` |
| `TownPass-Services/src/views/CounterCallingDetailView.vue` | 163 | `<BaseDialog` |
| `TownPass-Services/src/views/PoliceReportFormView.vue` | 60 | `<BaseDialog` |
| `TownPass-Services/src/views/DisasterReportFormView.vue` | 249 | `<LocationModal` |
| `TownPass-Services/src/views/DisasterReportFormView.vue` | 255 | `<BaseDialog` |
| `TownPass-Services/src/views/FeePaymentStepView.vue` | 108 | `<BaseDialog` |
| `TownPass-Services/src/views/TicketPayment.vue` | 93 | `<BaseDialog` |
| `TownPass-Services/src/views/FeePaymentScanView.vue` | 60 | `<BaseDialog` |
| `TownPass-Services/src/views/LibraryRankingListView.vue` | 64 | `<BaseDialog` |
| `TownPass-Services/src/views/SurroundingServiceView.vue` | 453 | `<MessageModal :is-show="isShowGeoError">` |
| `TownPass-Services/src/views/CounterCallingView.vue` | 125 | `<Dialog as="div" @close="isEditOpen = false" class="relative z-30">` |
| `TownPass-Services/src/views/TicketDetail.vue` | 176 | `<BaseDialog` |
| `TownPass-Services/src/views/CitizenReportFormView.vue` | 142 | `<BaseDialog` |
| `TownPass-Services/src/views/CitizenReportFormView.vue` | 149 | `<LocationModal` |
| `TownPass-Services/src/views/BuyTicketView.vue` | 209 | `<MessageModal :is-show="isUsagePeriodInformationModalOpen">` |
| `TownPass-Services/src/views/HotSpotView.vue` | 121 | `<BaseDialog` |
| `TownPass-Services/src/views/LibraryNoticeListView.vue` | 96 | `<BaseDialog` |
| `TownPass-Services/src/components/molecules/FeePaymentForm.vue` | 243 | `<BaseDialog` |
| `TownPass-Services/src/components/molecules/LibrarySelectDialog.vue` | 105 | `<Dialog as="div" @close="isOpen = false" class="relative z-30">` |
| `TownPass-Services/src/components/molecules/PoliceReportDetailForm.vue` | 212 | `<LocationModal` |
| `TownPass-Services/src/components/molecules/UploadSection.vue` | 170 | `<Dialog as="div" @close="isOpen = false" class="relative z-30">` |
| `TownPass-Services/src/components/molecules/FindPlace.vue` | 249 | `<MessageModal :is-show="isShowClearHistory">` |
| `TownPass-Services/src/components/atoms/BaseDialog.vue` | 36 | `<Dialog as="div" :open="isOpen" @close="setIsOpen" class="relative z-[9999]">` |
| `TownPass-Services/src/components/atoms/BaseMultipleSelect.vue` | 71 | `<Dialog as="div" @close="isOpen = false" class="relative z-30">` |
| `TownPass-Services/src/components/organisms/LocationModal.vue` | 131 | `<MessageModal ref="locationModal" :is-show="isShowLocaionModal" class="location-modal">` |
| `TownPass-Services/src/components/organisms/LocationModal.vue` | 183 | `<BaseDialog` |
| `TownPass-Services/src/components/organisms/LibraryMapView.vue` | 353 | `<MessageModal :is-show="isShowGeoError">` |
| `TownPass-Services/src/components/organisms/FormPreview.vue` | 198 | `<BaseDialog` |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 223 | `<BaseDialog` |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 233 | `<BaseDialog` |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 246 | `<BaseDialog` |
| `TownPass-Services/src/components/organisms/LibraryMyRecordsView.vue` | 257 | `<BaseDialog` |
| `TownPass-Services/src/components/organisms/LibraryDetailView.vue` | 70 | `<BaseDialog` |
