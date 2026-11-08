import 'package:town_pass/service/local_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/page/bill/widget/bill_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_constant.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_text.dart';

// 熱門繳費項目的私有資料模型
class _PopularBillItem {
  final Widget icon;
  final String name;
  final String uri;

  const _PopularBillItem({
    required this.icon,
    required this.name,
    required this.uri,
  });
}

class BillView extends StatefulWidget {
  const BillView({super.key});
  @override
  State<BillView> createState() => _BillViewState();
}

class _BillViewState extends State<BillView> {
  List<String> bindings = [];
  static const _bindingsKey = 'local_bill_bindings_v1';
  @override
  void initState() {
    super.initState();
    _loadBindings();
  }

  Future<void> _loadBindings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => bindings = prefs.getStringList(_bindingsKey) ?? []);
    }
  }

  Future<void> _bindingSettings() async {
    String selected = '水費';
    final name = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          backgroundColor: TPColors.white,
          title: const Text('新增帳單綁定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: '帳單類型'),
                  items: const ['水費', '停車費', '地方稅', '學雜費']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) refresh(() => selected = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '帳單名稱（選填）',
                    hintText: '例如：家裡的水費',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialog,
                name.text.trim().isEmpty ? selected : name.text.trim(),
              ),
              child: const Text('新增綁定'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    if (result == null || !mounted) return;
    final updated = {...bindings, result}.toList();
    final prefs = await SharedPreferences.getInstance();
    try {
      await LocalPersistence.checked(
        prefs,
        prefs.setStringList(_bindingsKey, updated),
      );
      if (mounted) {
        setState(() => bindings = updated);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後重試。')));
      }
    }
  }

  Future<void> _manageBindings() async {
    final removed = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TPColors.white,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '我的帳單設定',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            if (bindings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('尚未綁定帳單，新增後可在這裡管理。'),
              ),
            for (final binding in bindings)
              ListTile(
                title: Text(binding),
                trailing: TextButton(
                  onPressed: () => Navigator.pop(sheet, binding),
                  child: const Text('解除綁定'),
                ),
              ),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheet, '__add__'),
              child: const Text('新增綁定'),
            ),
          ],
        ),
      ),
    );
    if (removed == null) return;
    if (removed == '__add__') {
      await _bindingSettings();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final updated = bindings.where((value) => value != removed).toList();
    try {
      await LocalPersistence.checked(
        prefs,
        prefs.setStringList(_bindingsKey, updated),
      );
      if (mounted) {
        setState(() => bindings = updated);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後重試。')));
      }
    }
  }

  // 熱門繳費項目列表。icon 是執行期建立的 widget，所以不能用 const
  static final List<_PopularBillItem> _popularBillItems = [
    _PopularBillItem(
      icon: Assets.svg.iconBillCar.svg(),
      name: '停車費',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/fee-5/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillWater.svg(),
      name: '水費',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/fee-6/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillLocalTax.svg(),
      name: '地方稅',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/tax-1/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillTuition.svg(),
      name: '學雜費',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/fee-7/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillPublicHousing.svg(),
      name: '國/社宅租金維管費',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/fee-8/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillHospital.svg(),
      name: '聯合醫院醫療費',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/fee-9/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillHousingMaintenance.svg(),
      name: '平價住宅維護費',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/fee-10/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillClass.svg(),
      name: '公訓處自費課程',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/detail/fee-11/',
    ),
    _PopularBillItem(
      icon: Assets.svg.iconBillOther.svg(),
      name: '其他',
      uri: 'https://taipei-pass-service.vercel.app/fee-payment/others/',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BillAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            explicitChildNodes: true,
            child: Row(
              children: [
                TPText(
                  '我的帳單',
                  style: TPTextStyles.h3SemiBold.copyWith(fontSize: 18),
                  color: TPColors.grayscale900,
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _manageBindings,
                  child: Row(
                    children: [
                      Assets.svg.iconSettings.svg(
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          TPColors.grayscale950,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const TPText(
                        '設定',
                        style: TPTextStyles.bodyRegular,
                        color: TPColors.grayscale950,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bindings.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12.0),
              itemBuilder: (_, index) {
                if (index > 0) {
                  return Card(
                    color: TPColors.white,
                    child: SizedBox(
                      width: 120 * goldenRatio,
                      child: ListTile(
                        title: Text(bindings[index - 1]),
                        subtitle: const Text('已綁定'),
                        onTap: _manageBindings,
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _bindingSettings,
                  child: SizedBox(
                    width: 120 * goldenRatio,
                    child: DottedBorder(
                      options: const RoundedRectDottedBorderOptions(
                        color: TPColors.grayscale200,
                        radius: Radius.circular(5.0),
                        strokeWidth: 1.5,
                        dashPattern: [4, 3],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              excludeSemantics: true,
                              child: Assets.svg.iconAdd.svg(),
                            ),
                            const TPText(
                              '新增綁定',
                              style: TPTextStyles.bodyRegular,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          TPText(
            '熱門繳費',
            style: TPTextStyles.h3SemiBold.copyWith(fontSize: 18),
            color: TPColors.grayscale900,
          ),
          const SizedBox(height: 12),
          // 使用 map 函式根據 _popularBillItems 列表來動態生成 _BillType 小部件
          ..._popularBillItems
              .map(
                (item) => _BillType(
                  icon: item.icon,
                  name: item.name,
                  onTap: () async => await TPRoute.openUri(uri: item.uri),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

class _BillType extends StatelessWidget {
  final Widget icon;
  final String name;
  final GestureTapCallback? onTap;

  const _BillType({required this.icon, required this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap?.call(),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 8),
            TPText(name, style: TPTextStyles.h3Regular),
          ],
        ),
      ),
    );
  }
}
