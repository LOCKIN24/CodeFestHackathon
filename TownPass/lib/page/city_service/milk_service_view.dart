import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:town_pass/service/milk_invitation_qr.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/milk_feature_theme.dart';
import 'package:town_pass/service/milk_reminder_service.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/page/city_service/milk_redemption_demo_view.dart';
import 'package:town_pass/page/city_service/milk_reminder_preview.dart';
import 'package:town_pass/page/city_service/milk_outing_card.dart';
import 'package:town_pass/page/city_service/milk_route_entry_card.dart';
import 'package:town_pass/page/city_service/milk_passport_view.dart';
import 'package:town_pass/page/city_service/milk_route_view.dart';
import 'package:town_pass/service/milk_route.dart';
import 'package:town_pass/service/milk_reminder_target.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:town_pass/util/tp_card.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text_styles.dart';

const _teal = TPColors.primary700;
const _pale = TPColors.primary50;

// A fixed UTC offset is used because Taipei has no daylight saving time.
DateTime taipeiNow() => DateTime.now().toUtc().add(const Duration(hours: 8));
DateTime weekStart(DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).subtract(Duration(days: date.weekday - 1));
String weekKey(DateTime date) =>
    weekStart(date).toIso8601String().substring(0, 10);
String displayDate(DateTime date) => '${date.month}/${date.day}';

/// Extract a 16-digit printed card number, allowing spaces or hyphens between groups.
String? findCardNumber(List<String> lines) {
  final pattern = RegExp(r'(?<!\d)(?:\d[\s-]*){15}\d(?!\d)');
  for (final line in lines) {
    final match = pattern.firstMatch(line);
    if (match != null) return match.group(0)!.replaceAll(RegExp(r'\D'), '');
  }
  return null;
}

extension on MilkChild {
  bool get redeemed => records.any((r) => r['week'] == weekKey(taipeiNow()));
}

class MilkServiceView extends StatelessWidget {
  const MilkServiceView({super.key, this.reminderTarget});
  final MilkReminderTarget? reminderTarget;
  @override
  Widget build(BuildContext context) => MilkFeatureTheme(
    child: _MilkServiceContent(reminderTarget: reminderTarget),
  );
}

class _MilkServiceContent extends StatefulWidget {
  const _MilkServiceContent({this.reminderTarget});
  final MilkReminderTarget? reminderTarget;
  @override
  State<_MilkServiceContent> createState() => _MilkServiceViewState();
}

class _MilkServiceViewState extends State<_MilkServiceContent>
    with WidgetsBindingObserver {
  MilkChild? data;
  List<MilkChild> children = [];
  bool loading = true;
  String? loadError;
  bool childMode = false;
  bool _syncing = false;
  bool _mutating = false;
  int _revision = 0;
  int _milkTab = 0;
  Timer? _timer;
  String? syncError;
  final _studentDetailKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _syncParent());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncParent();
  }

  Future<void> _load() async {
    try {
      final role = await MilkFamilySync.isChild;
      final requested = widget.reminderTarget;
      if (requested != null && requested.role != (role ? 'child' : 'parent')) {
        throw const FormatException('這則提醒與目前的帳號角色不符，請返回原本帳號查看。');
      }
      final loaded = role ? <MilkChild>[] : await MilkFamilyStore.load();
      if (!role &&
          requested != null &&
          !loaded.any((c) => c.id == requested.childId)) {
        throw const FormatException('這位子女已移除，這則提醒已失效。');
      }
      final prefs = await SharedPreferences.getInstance();
      final selected =
          requested?.childId ?? prefs.getString(MilkFamilyStore.selectedKey);
      if (mounted) {
        setState(() {
          childMode = role;
          loadError = null;
          children = loaded;
          data =
              loaded.where((child) => child.id == selected).firstOrNull ??
              (loaded.isEmpty ? null : loaded.first);
          loading = false;
        });
        if (!role) unawaited(_syncParent());
        if (!role && requested != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToStudent(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadError = e is FormatException ? e.message : '無法讀取學生資料，請重新開啟 App。';
          loading = false;
        });
      }
    }
  }

  Future<void> _save(MilkChild value) async {
    if (_mutating) return;
    _revision++;
    setState(() => _mutating = true);
    try {
      final updated = [...children];
      final index = updated.indexWhere((child) => child.id == value.id);
      if (index < 0) {
        updated.add(value);
      } else {
        updated[index] = value;
      }
      await MilkFamilyStore.save(updated);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MilkFamilyStore.selectedKey, value.id);
      if (mounted) {
        setState(() {
          children = updated;
          data = value;
        });
      }
      unawaited(MilkReminderService.refresh());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
    if (mounted) unawaited(_syncParent());
  }

  Future<void> _syncParent() async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent == false ||
        _syncing ||
        _mutating ||
        childMode ||
        loading) {
      return;
    }
    _syncing = true;
    final revision = _revision;
    try {
      // Returning from a notification-opened route must not reuse an older
      // family snapshot and restore a removed child or discard a new child.
      final stored = await MilkFamilyStore.load();
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent == false ||
          revision != _revision ||
          _mutating) {
        return;
      }
      if (jsonEncode(stored.map((c) => c.toJson()).toList()) !=
          jsonEncode(children.map((c) => c.toJson()).toList())) {
        final selected = data?.id;
        setState(() {
          children = stored;
          data =
              stored.where((c) => c.id == selected).firstOrNull ??
              stored.firstOrNull;
        });
      }
      if (children.isEmpty) return;
      final updated = await MilkFamilySync.syncParent(children);
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent == false ||
          updated == null ||
          revision != _revision) {
        return;
      }
      final previous = jsonEncode(children.map((c) => c.toJson()).toList());
      final next = jsonEncode(updated.map((c) => c.toJson()).toList());
      if (previous != next) {
        await MilkFamilyStore.save(updated);
        if (!mounted || revision != _revision) return;
        final selected = data?.id;
        setState(() {
          children = updated;
          data =
              updated.where((c) => c.id == selected).firstOrNull ??
              updated.first;
        });
        unawaited(MilkReminderService.refresh());
      }
      if (mounted && syncError != null) setState(() => syncError = null);
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(
          () => syncError = e is MilkSyncException && e.sessionExpired
              ? '家庭連線已失效。請在「邀請孩子」重新設定家庭連線，再產生新邀請碼。手機內的學生資料與紀錄仍保留。'
              : '無法連上家庭服務，資料暫存在手機，尚未同步。',
        );
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _selectChild(MilkChild child) async {
    if (_mutating) return;
    setState(() => data = child);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MilkFamilyStore.selectedKey, child.id);
  }

  Future<MilkRouteStop?> _chooseOutingStore() async {
    final store = await Navigator.push<_Store>(
      context,
      MaterialPageRoute(builder: (_) => const MilkStoresView(selectMode: true)),
    );
    if (store == null) return null;
    return MilkRouteStop(
      name: store.name,
      address: store.address,
      latitude: store.lat,
      longitude: store.lon,
    );
  }

  Future<void> _receiveOuting(Map<String, dynamic> profile) async {
    final updated = await MilkFamilyStore.mergeOuting(
      profile['id'] as String,
      profile['outing'] is Map
          ? Map<String, dynamic>.from(profile['outing'] as Map)
          : null,
    );
    if (!mounted) return;
    setState(() {
      children = updated;
      data = updated.where((c) => c.id == data?.id).firstOrNull;
    });
  }

  Future<void> _scrollToStudent() async {
    final context = _studentDetailKey.currentContext;
    if (mounted && context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  Future<void> _openReminder(MilkReminderTarget target) async {
    final child = children.where((c) => c.id == target.childId).firstOrNull;
    if (child == null || childMode || !mounted) return;
    setState(() => _milkTab = 0);
    await _selectChild(child);
    if (mounted) await _scrollToStudent();
  }

  Future<void> _beginSetup() async {
    final choice = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (pageContext) => _Page(
          title: '開始設定',
          children: [
            const _Heading('選擇使用方式'),
            const SizedBox(height: 16),
            _Panel(
              children: [
                const _Heading('我是家長'),
                const SizedBox(height: 8),
                const Text('新增孩子，管理每週領取與鮮奶護照。'),
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: '設定孩子資料',
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: () => Navigator.pop(pageContext, 'parent'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              children: [
                const _Heading('我是孩子'),
                const SizedBox(height: 8),
                const Text('使用家長的邀請碼，加入你的家庭。'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(pageContext, 'child'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('我是孩子，輸入邀請碼'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(pageContext, 'route'),
              icon: const Icon(Icons.route_outlined),
              label: const Text('先看看放學順路門市'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'parent':
        await _setup();
      case 'child':
        await _joinChild();
      case 'route':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const MilkRouteView()),
        );
    }
  }

  Future<void> _setup() async {
    final proceed = children.isNotEmpty
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('開始使用前'),
              content: const Text('加入孩子的學生資料，即可查看本週鮮奶、領取紀錄與收藏護照。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('我知道了'),
                ),
              ],
            ),
          );
    if (proceed != true || !mounted) return;
    final value = await Navigator.push<MilkChild>(
      context,
      MaterialPageRoute(builder: (_) => const _SetupPage()),
    );
    if (value != null) {
      if (children.any((child) => child.number == value.number)) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('這張學生證已加入，請勿重複新增。')));
        }
        return;
      }
      await _save(value);
    }
  }

  Future<void> _reset() async {
    if (_mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除資料？'),
        content: const Text('將清除這台手機上保存的學生卡號、資料與兌領紀錄。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除並重設'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _mutating) return;
    _revision++;
    setState(() => _mutating = true);
    try {
      final revoked = await MilkFamilySync.clearParent();
      await MilkFamilyStore.clear();
      await MilkReminderService.refresh();
      if (mounted) {
        setState(() {
          data = null;
          children = [];
          syncError = null;
        });
        if (!revoked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('部分裝置暫時無法解除連結，請恢復連線後再試。')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('無法清除本機資料，請重試。')));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _redeem() async {
    final current = data!;
    if (current.redeemed || _mutating) return;
    final record = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const _RedeemPage()),
    );
    if (record == null || !mounted || _mutating) return;
    final latest = children
        .where((child) => child.id == current.id)
        .firstOrNull;
    if (latest == null || latest.redeemed) return;
    await _save(
      MilkChild(
        id: current.id,
        number: current.number,
        name: current.name,
        school: current.school,
        outing: current.outing,
        records: [record, ...latest.records],
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('兌領紀錄已儲存'),
          action: SnackBarAction(
            label: '看看新印章',
            onPressed: () {
              if (mounted) {
                openMilkPassport(
                  context,
                  records: [record, ...latest.records],
                  replayLatest: true,
                );
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _joinChild() async {
    final joined = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _JoinChildPage()),
    );
    if (joined == true && mounted) setState(() => childMode = true);
  }

  Future<void> _share(MilkChild child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InvitePage(
          child: child,
          index: children.indexWhere((c) => c.id == child.id),
        ),
      ),
    );
    if (mounted) unawaited(_syncParent());
  }

  Future<void> _revoke(MilkChild child) async {
    if (!await MilkFamilySync.isShared(child.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('這位子女尚未連結兒童裝置。')));
      }
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解除兒童裝置連結？'),
        content: Text('將解除 ${child.name} 已連結的兒童裝置，需要網路連接。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除連結'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MilkFamilySync.revoke(child.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已解除連結')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('暫時無法連線，請稍後再試。')));
      }
    }
  }

  Future<void> _removeChild(MilkChild child) async {
    if (_mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除子女？'),
        content: Text('將移除 ${child.name} 的本機卡號與紀錄。若已分享，也會解除兒童裝置連結。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _mutating) return;
    _revision++;
    setState(() => _mutating = true);
    try {
      await MilkFamilySync.revoke(child.id);
      final updated = children.where((c) => c.id != child.id).toList();
      await MilkFamilyStore.save(updated);
      final prefs = await SharedPreferences.getInstance();
      if (updated.isEmpty) {
        await prefs.remove(MilkFamilyStore.selectedKey);
      } else {
        await prefs.setString(MilkFamilyStore.selectedKey, updated.first.id);
      }
      await MilkReminderService.refresh();
      if (mounted) {
        setState(() {
          children = updated;
          data = updated.isEmpty ? null : updated.first;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('暫時無法解除連結，請恢復連線後再試。')));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _familySettings() async {
    final selected = data;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TPColors.white,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Heading('家庭設定'),
                const SizedBox(height: 12),
                if (selected != null)
                  Text('${selected.name} · ${selected.school}'),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('新增子女'),
                  onTap: () => Navigator.pop(sheet, 'add'),
                ),
                if (selected != null) ...[
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: const Text('邀請孩子'),
                    onTap: () => Navigator.pop(sheet, 'invite'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: const Text('解除連結'),
                    onTap: () => Navigator.pop(sheet, 'unlink'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined),
                    title: const Text('移除子女'),
                    onTap: () => Navigator.pop(sheet, 'remove'),
                  ),
                ],
                const Divider(),
                if (children.isNotEmpty)
                  MilkReminderPreview(
                    targets: MilkReminderTarget.pending(
                      children.map((c) => c.toJson()),
                      role: 'parent',
                      now: taipeiNow(),
                    ),
                    enabled: !_mutating,
                    onOpen: (target) async {
                      Navigator.pop(sheet);
                      await _openReminder(target);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.local_drink_outlined),
                  title: const Text('領取鮮奶'),
                  subtitle: const Text('選擇孩子與飲品，完成本週領取'),
                  onTap: () =>
                      Navigator.pop(sheet, selected == null ? 'add' : 'demo'),
                ),
                if (selected != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('清除資料'),
                    onTap: () => Navigator.pop(sheet, 'reset'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'add':
        await _setup();
      case 'invite':
        if (selected != null) await _share(selected);
      case 'unlink':
        if (selected != null) await _revoke(selected);
      case 'remove':
        if (selected != null) await _removeChild(selected);
      case 'reset':
        await _reset();
      case 'demo':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => MilkRedemptionDemoView(
              familyMode: true,
              reminderChildId: selected?.id,
            ),
          ),
        );
        if (mounted) await _load();
    }
  }

  Future<void> _showPickupRecord(MilkChild child) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: TPColors.white,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('本週領取紀錄', style: TPTextStyles.h2SemiBold),
            const SizedBox(height: 12),
            Text(child.name, style: TPTextStyles.h3SemiBold),
            for (final record in child.records.where(
              (r) => r['week'] == weekKey(taipeiNow()),
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: TPColors.primary700,
                ),
                title: Text('${record['product']}'),
                subtitle: Text('${record['date']}'),
              ),
            const Text('這筆領取紀錄已儲存，也已收進孩子的鮮奶護照。'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _eligibilityInfo() => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: TPColors.white,
      title: const Text('領取資格說明'),
      content: const Text(
        '請使用孩子的有效學生卡證，每週一至週日可領取一瓶鮮奶或豆漿。出門時記得攜帶實體卡證；未使用的每週額度不會累積。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('我知道了'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final current = data;
    final now = taipeiNow();
    final start = weekStart(now);
    final end = start.add(const Duration(days: 6));
    if (childMode) {
      return _ChildMode(
        expectedChildId: widget.reminderTarget?.childId,
        onLeave: () async {
          await MilkFamilySync.leaveChild();
          await MilkReminderService.refresh();
          if (mounted) setState(() => childMode = false);
        },
        onReconnect: () async {
          await MilkFamilySync.leaveChild();
          await MilkReminderService.refresh();
          if (!mounted) return;
          setState(() => childMode = false);
          await _joinChild();
        },
      );
    }
    return _Page(
      title: '生生喝鮮乳',
      action: IconButton(
        tooltip: '家庭設定',
        onPressed: _mutating ? null : _familySettings,
        icon: const Icon(Icons.settings_outlined),
      ),
      children: [
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (loadError != null)
          _Panel(
            children: [
              Text(loadError!),
              TextButton(onPressed: _load, child: const Text('重試')),
            ],
          )
        else if (current == null) ...[
          const _Panel(
            children: [
              _Heading('開始設定學生資料'),
              SizedBox(height: 12),
              Text('幾個步驟，輕鬆查看本週鮮乳額度。'),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StepIcon(
                      icon: Icons.document_scanner_outlined,
                      label: '掃描卡號',
                    ),
                  ),
                  Icon(Icons.chevron_right, color: TPColors.grayscale400),
                  Expanded(
                    child: _StepIcon(
                      icon: Icons.fact_check_outlined,
                      label: '確認資料',
                    ),
                  ),
                  Icon(Icons.chevron_right, color: TPColors.grayscale400),
                  Expanded(
                    child: _StepIcon(
                      icon: Icons.local_drink_outlined,
                      label: '查看額度',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PrimaryButton(label: '開始設定', onPressed: _beginSetup),
        ] else ...[
          KeyedSubtree(
            key: _studentDetailKey,
            child: _Panel(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '目前孩子',
                        style: TPTextStyles.bodySemiBold.copyWith(
                          color: TPColors.grayscale700,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: '資格說明',
                      child: TextButton(
                        onPressed: _eligibilityInfo,
                        child: Text(
                          '領取資格',
                          style: TPTextStyles.bodySemiBold.copyWith(
                            color: _teal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Semantics(
                  container: true,
                  label: '選擇孩子',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TPColors.grayscale50,
                      border: Border.all(color: TPColors.grayscale200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('milk-child-selector'),
                          value: current.id,
                          isExpanded: true,
                          itemHeight: null,
                          dropdownColor: TPColors.white,
                          icon: ExcludeSemantics(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '切換',
                                  style: TPTextStyles.caption.copyWith(
                                    color: _teal,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.unfold_more,
                                  color: _teal,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          style: TPTextStyles.h3SemiBold.copyWith(
                            color: TPColors.primary900,
                            fontSize: 20,
                            height: 1.4,
                          ),
                          items: [
                            for (final child in children)
                              DropdownMenuItem<String>(
                                value: child.id,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(child.name),
                                ),
                              ),
                          ],
                          onChanged: _mutating
                              ? null
                              : (id) {
                                  final chosen = children
                                      .where((c) => c.id == id)
                                      .firstOrNull;
                                  if (chosen != null) {
                                    _selectChild(chosen);
                                  }
                                },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '學校',
                      style: TPTextStyles.bodyRegular.copyWith(
                        color: TPColors.grayscale700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        current.school,
                        style: TPTextStyles.bodyRegular.copyWith(
                          color: TPColors.grayscale900,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            key: const Key('milk-section-tabs'),
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('本週狀態'),
                icon: Icon(Icons.local_drink_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('一起出發'),
                icon: Icon(Icons.route_outlined),
              ),
            ],
            selected: {_milkTab},
            showSelectedIcon: false,
            onSelectionChanged: _mutating
                ? null
                : (selection) => setState(() => _milkTab = selection.single),
          ),
          if (_milkTab == 0) ...[
            const SizedBox(height: 16),
            _Panel(
              children: [
                Text(
                  '本週 · ${displayDate(start)} — ${displayDate(end)}',
                  style: TPTextStyles.bodyRegular.copyWith(
                    color: TPColors.grayscale700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _pale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.redeemed ? '本週已留下領取紀錄' : '本週鮮乳額度',
                        style: TPTextStyles.h3SemiBold.copyWith(color: _teal),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current.redeemed ? '本週已記錄' : '每週 1 瓶',
                        style: TPTextStyles.h2SemiBold.copyWith(
                          color: _teal,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current.redeemed ? '下週再來，繼續留下紀念' : '鮮奶或豆漿，選你喜歡的',
                        style: TPTextStyles.h3Regular,
                      ),
                    ],
                  ),
                ),
                if (!current.redeemed) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TPColors.grayscale100,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: TPColors.grayscale800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            now.weekday == DateTime.sunday
                                ? '今天截止，記得帶實體卡證'
                                : '本週日截止，記得帶實體卡證',
                            style: TPTextStyles.bodySemiBold.copyWith(
                              color: TPColors.grayscale800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _PrimaryButton(
                  label: '找附近門市',
                  icon: Icons.near_me_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MilkStoresView()),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _mutating
                        ? null
                        : current.redeemed
                        ? () => _showPickupRecord(current)
                        : _redeem,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(current.redeemed ? '查看本週領取紀錄' : '我已領取，留下紀錄'),
                  ),
                ),
              ],
            ),
            const Text(
              '領取後留下紀錄，收藏這一週的鮮奶印章。',
              textAlign: TextAlign.center,
              style: TPTextStyles.caption,
            ),
            if (syncError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  syncError!,
                  style: const TextStyle(color: TPColors.red700),
                ),
              ),
            const SizedBox(height: 24),
            const SizedBox(height: 16),
            MilkPassportCard(
              key: ValueKey('passport-${current.id}'),
              records: current.records,
            ),
            const SizedBox(height: 24),
            _Panel(
              children: [
                const _Heading('領取紀錄'),
                const SizedBox(height: 8),
                if (current.records.isEmpty)
                  const Text('本週還沒有紀錄。領取後，再回來留下紀念吧。')
                else
                  for (final record in current.records)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: _teal,
                      ),
                      title: Text(
                        record['store'] == null
                            ? '${record['product']}'
                            : '${record['product']}・${record['store']}',
                      ),
                      subtitle: Text('${record['date']}'),
                    ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 20),
            MilkOutingCard(
              key: ValueKey('parent-outing-${current.id}'),
              profile: current.toJson(),
              childMode: false,
              enabled: !_mutating && syncError == null,
              chooseNearby: _chooseOutingStore,
              onBusyChanged: (busy) {
                if (mounted) {
                  setState(() {
                    _revision++;
                    _mutating = busy;
                  });
                }
              },
              onChanged: _receiveOuting,
              onRefresh: _syncParent,
            ),
            const SizedBox(height: 16),
            const MilkRouteEntryCard(),
          ],
        ],
      ],
    );
  }
}

class _InvitePage extends StatefulWidget {
  const _InvitePage({required this.child, required this.index});
  final MilkChild child;
  final int index;
  @override
  State<_InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<_InvitePage> {
  final address = TextEditingController(
    text: const String.fromEnvironment(
      'MILK_DEMO_SERVER',
      defaultValue: 'http://127.0.0.1:8769',
    ),
  );
  bool busy = false;
  String? code;
  String? issuedAddress;
  Timer? expiryTimer;
  String? error;
  @override
  void initState() {
    super.initState();
    MilkFamilySync.parentUrl.then((url) {
      if (mounted && url != null) address.text = url;
    });
  }

  @override
  void dispose() {
    expiryTimer?.cancel();
    address.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    expiryTimer?.cancel();
    setState(() {
      busy = true;
      error = null;
      code = null;
      issuedAddress = null;
    });
    try {
      final base = address.text.trim();
      final value = await MilkFamilySync.invite(
        widget.child,
        base,
        widget.index,
      );
      if (!mounted) return;
      expiryTimer?.cancel();
      expiryTimer = Timer(const Duration(minutes: 10), () {
        if (mounted) {
          setState(() {
            code = null;
            issuedAddress = null;
            error = '邀請碼已過期，請產生新的邀請碼。';
          });
        }
      });
      if (mounted) {
        setState(() {
          code = value;
          issuedAddress = base;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : e is MilkSyncException && e.sessionExpired
              ? '家庭連線已失效，請先按「重新設定家庭連線」，再產生新邀請碼。'
              : e is MilkSyncException
              ? e.message
              : '無法完成家庭連結，請確認網路與邀請設定後重試。',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetConnection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新設定家庭連線？'),
        content: const Text(
          '原本的兒童裝置需要重新加入。如果舊服務已離線，請停止舊服務以解除所有舊連線。本機學生資料不會刪除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重新設定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await MilkFamilySync.clearParent();
      expiryTimer?.cancel();
      if (mounted) {
        setState(() {
          code = null;
          issuedAddress = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: '邀請孩子',
    keyboardDone: true,
    children: [
      _Panel(
        children: [
          _Heading('邀請 ${widget.child.name}'),
          const SizedBox(height: 12),
          const Text('讓孩子掃描下方的邀請碼，或在兒童版輸入邀請碼，就能一起查看鮮奶與行程。'),
          const SizedBox(height: 8),
          const Text(
            '連結後，孩子可以查看自己的領取紀錄，也能邀請你一起去領。',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '請將邀請碼交給要連結的孩子，避免分享給其他人。',
            style: TextStyle(fontSize: 14, color: TPColors.grayscale700),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Panel(
        children: [
          ExpansionTile(
            title: const Text('進階連線設定'),
            maintainState: true,
            children: [
              TextField(
                controller: address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '家庭連線位址',
                  hintText: 'http://192.168.1.2:8765',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: const TextStyle(color: TPColors.red700),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _PrimaryButton(
        label: busy ? '連線中…' : (code == null ? '產生邀請碼' : '產生新的邀請碼'),
        onPressed: busy ? null : _create,
      ),
      Center(
        child: TextButton(
          onPressed: busy ? null : _resetConnection,
          child: const Text('重新設定家庭連線'),
        ),
      ),
      if (code != null) ...[
        const SizedBox(height: 16),
        _Panel(
          children: [
            const _Heading('請孩子掃描或輸入邀請碼'),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: MilkInvitationQr(issuedAddress!, code!).encode(),
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              code!,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: _teal,
              ),
            ),
            const SizedBox(height: 8),
            const Text('邀請碼限使用一次，10 分鐘後失效。'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('邀請碼已複製')));
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('複製邀請碼'),
            ),
          ],
        ),
      ],
    ],
  );
}

class _JoinChildPage extends StatefulWidget {
  const _JoinChildPage();
  @override
  State<_JoinChildPage> createState() => _JoinChildPageState();
}

class _JoinChildPageState extends State<_JoinChildPage> {
  final address = TextEditingController(
    text: const String.fromEnvironment(
      'MILK_DEMO_SERVER',
      defaultValue: 'http://127.0.0.1:8769',
    ),
  );
  final code = TextEditingController();
  final name = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> _scanInvite() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _InviteScannerPage()),
    );
    if (raw == null || !mounted) return;
    try {
      final invite = MilkInvitationQr.parse(raw);
      setState(() {
        address.text = invite.address;
        code.text = invite.code;
        error = null;
      });
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  void dispose() {
    address.dispose();
    code.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await MilkFamilySync.join(
        address.text.trim(),
        code.text.trim(),
        displayName: name.text,
      );
      try {
        await MilkFamilySync.childProfile();
        unawaited(MilkReminderService.refresh());
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : e is MilkSyncException
              ? e.message
              : e is HttpException
              ? e.message
              : '無法完成連結，請確認邀請碼與網路後重試。',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: '加入兒童版',
    keyboardDone: true,
    children: [
      const _Panel(
        children: [
          _Heading('和家長連結'),
          SizedBox(height: 12),
          Text('掃描家長手機上的邀請碼，或輸入家長提供的邀請碼。'),
          SizedBox(height: 8),
          Text('完成連結後，就能查看自己的鮮奶與家庭行程。', style: TextStyle(fontSize: 14)),
        ],
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: busy ? null : _scanInvite,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('掃描家長邀請 QR Code'),
      ),
      const SizedBox(height: 16),
      _Panel(
        children: [
          ExpansionTile(
            title: const Text('進階連線設定'),
            maintainState: true,
            children: [
              TextField(
                controller: address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '家庭連線位址',
                  hintText: 'http://192.168.1.2:8765',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '邀請碼',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: '你的暱稱（選填）',
              helperText: '只儲存在這支手機',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: const TextStyle(color: TPColors.red700),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _PrimaryButton(
        label: busy ? '連線中…' : '加入',
        onPressed: busy ? null : _join,
      ),
    ],
  );
}

class _InviteScannerPage extends StatefulWidget {
  const _InviteScannerPage();
  @override
  State<_InviteScannerPage> createState() => _InviteScannerPageState();
}

class _InviteScannerPageState extends State<_InviteScannerPage> {
  bool done = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('掃描家庭邀請碼')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('請掃描家長手機上的邀請 QR Code。'),
        ),
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              if (done) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw == null) continue;
                try {
                  MilkInvitationQr.parse(raw);
                  done = true;
                  Navigator.pop(context, raw);
                  return;
                } on FormatException catch (_) {}
              }
            },
            errorBuilder: (context, error) =>
                const Center(child: Text('無法使用相機。請確認權限，或返回手動輸入邀請碼。')),
          ),
        ),
      ],
    ),
  );
}

class _ChildMode extends StatefulWidget {
  const _ChildMode({
    required this.onLeave,
    required this.onReconnect,
    this.expectedChildId,
  });
  final Future<void> Function() onLeave;
  final Future<void> Function() onReconnect;
  final String? expectedChildId;
  @override
  State<_ChildMode> createState() => _ChildModeState();
}

class _ChildModeState extends State<_ChildMode> with WidgetsBindingObserver {
  Map<String, dynamic>? profile;
  bool loading = true, syncing = false;
  bool recording = false, linkExpired = false;
  String? error;
  String localName = '';
  Timer? timer;
  final _childStatusKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(
          () => localName = prefs.getString('milk_child_local_name') ?? '',
        );
      }
    });
    _load();
    timer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (syncing || recording || linkExpired) return;
    setState(() => syncing = true);
    try {
      final value = await MilkFamilySync.childProfile();
      if (mounted) {
        if (widget.expectedChildId != null &&
            value['id'] != widget.expectedChildId) {
          setState(() {
            profile = null;
            error = '這則提醒不屬於目前連結的孩子。';
            loading = false;
          });
          return;
        }
        final changed = jsonEncode(profile) != jsonEncode(value);
        setState(() {
          profile = value;
          error = null;
          loading = false;
        });
        if (changed) unawaited(MilkReminderService.refresh());
      }
    } on MilkSyncException catch (e) {
      if (e.sessionExpired) {
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        await prefs.remove('milk_child_cache');
        unawaited(MilkReminderService.refresh());
        if (mounted) {
          setState(() {
            profile = null;
            linkExpired = true;
            error = '家庭連線已失效或已被家長解除。請向家長取得新邀請碼，重新加入。';
            loading = false;
          });
        }
      } else {
        await _showOffline();
      }
    } catch (_) {
      await _showOffline();
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> _showOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString('milk_child_cache');
    if (mounted) {
      setState(() {
        if (cache != null) {
          try {
            profile = jsonDecode(cache) as Map<String, dynamic>;
            if (widget.expectedChildId != null &&
                profile?['id'] != widget.expectedChildId) {
              profile = null;
            }
          } catch (_) {}
        }
        error = profile == null
            ? '目前離線，還沒有可顯示的資料。請恢復網路後重試。'
            : '目前離線，以下是上次同步的資料。本週狀態可能已變更，請連線後確認。';
        loading = false;
      });
    }
  }

  Future<void> _record() async {
    if (error != null || recording || syncing) return;
    // Keep polling paused from opening the form until the POST is complete.
    // Otherwise a delayed pre-record GET can overwrite the new cached status.
    setState(() => recording = true);
    try {
      final record = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const _RedeemPage()),
      );
      if (record == null || !mounted) return;
      try {
        final value = await MilkFamilySync.childRecord(record);
        if (mounted) {
          setState(() {
            profile = value;
            error = null;
          });
        }
        unawaited(MilkReminderService.refresh());
      } on MilkSyncException catch (e) {
        if (mounted) {
          if (e.sessionExpired) {
            final prefs = await SharedPreferences.getInstance();
            if (!mounted) return;
            await prefs.remove('milk_child_cache');
            if (!mounted) return;
            setState(() {
              profile = null;
              linkExpired = true;
              error = '家庭連線已失效或已被家長解除。請向家長取得新邀請碼，重新加入。';
            });
            unawaited(MilkReminderService.refresh());
          } else {
            setState(() => error = e.message);
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() => error = '尚未確認這筆紀錄是否同步，請重新連線後查看狀態。');
        }
      }
    } finally {
      if (mounted) setState(() => recording = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('離開兒童版？'),
        content: const Text('此裝置會移除連線資料，需要新的邀請碼才能再次加入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('離開'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onLeave();
  }

  @override
  Widget build(BuildContext context) {
    final records = (profile?['records'] as List? ?? []);
    final redeemed = records.any(
      (r) => r is Map && r['week'] == weekKey(taipeiNow()),
    );
    return _Page(
      title: '我的鮮奶',
      action: TextButton(
        onPressed: recording ? null : _leave,
        child: const Text('離開連結'),
      ),
      children: [
        if (loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (error != null) ...[
            _Panel(
              children: [
                Text(error!, style: const TextStyle(color: TPColors.red700)),
                TextButton(
                  onPressed: linkExpired ? widget.onReconnect : _load,
                  child: Text(linkExpired ? '輸入新邀請碼' : '重新連線'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (profile != null) ...[
            MilkReminderPreview(
              enabled: !recording && !syncing && error == null,
              targets: MilkReminderTarget.pending(
                [
                  {
                    ...profile!,
                    'name': localName.isEmpty ? profile!['alias'] : localName,
                  },
                ],
                role: 'child',
                now: taipeiNow(),
              ),
              onOpen: (target) async {
                if (profile?['id'] != target.childId) return;
                final context = _childStatusKey.currentContext;
                if (context != null) {
                  await Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 250),
                  );
                }
              },
            ),
            KeyedSubtree(
              key: _childStatusKey,
              child: _Panel(
                children: [
                  _Heading(
                    '嗨，${localName.isEmpty ? profile!['alias'] : localName}！',
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: TPColors.primary100,
                      child: Icon(
                        redeemed
                            ? Icons.check_circle_outline
                            : Icons.local_drink_outlined,
                        color: _teal,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      redeemed ? '這週已記錄' : '這週還有 1 瓶',
                      textAlign: TextAlign.center,
                      style: TPTextStyles.h2SemiBold.copyWith(color: _teal),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(child: Text('帶上學生證去領鮮奶！')),
                  const SizedBox(height: 16),
                  _PrimaryButton(
                    label: redeemed ? '這週已記錄' : (syncing ? '同步中…' : '我拿到了'),
                    onPressed: redeemed || error != null || recording || syncing
                        ? null
                        : _record,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '每週一瓶，記得和家人一起安排領取。',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MilkOutingCard(
              key: ValueKey('child-outing-${profile!['id']}'),
              profile: profile!,
              childMode: true,
              enabled: !recording && !syncing && error == null && !linkExpired,
              onBusyChanged: (busy) {
                if (mounted) setState(() => recording = busy);
              },
              onChanged: (value) async {
                if (mounted) setState(() => profile = value);
              },
              onRefresh: _load,
            ),
            const SizedBox(height: 16),
            MilkPassportCard(
              key: ValueKey('child-passport-${profile!['id']}'),
              records: (profile!['records'] as List)
                  .map((r) => Map<String, dynamic>.from(r as Map))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Panel(
              children: [
                const _Heading('附近門市'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MilkStoresView()),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('查看附近門市'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MilkRouteView()),
                  ),
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('放學順路領'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              children: [
                const _Heading('我的兌領紀錄'),
                const SizedBox(height: 8),
                if (records.isEmpty)
                  const Text('尚無兌領紀錄')
                else
                  for (final record in records)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: _teal,
                      ),
                      title: Text('${record['product']}'),
                      subtitle: Text('${record['date']}'),
                    ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _SetupPage extends StatefulWidget {
  const _SetupPage();
  @override
  State<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<_SetupPage> {
  final number = TextEditingController();
  final name = TextEditingController();
  String? district;
  String? school;
  Map<String, List<String>> schools = {};
  String? cardError;
  String? schoolError;
  final cardFocus = FocusNode();
  bool busy = false;
  bool cardLocked = false;
  bool showForm = false;
  String? message;
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/mock_data/taipei_schools.json').then((raw) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) {
        setState(
          () => schools = decoded.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          ),
        );
      }
    });
    cardFocus.addListener(() {
      if (!cardFocus.hasFocus &&
          number.text.isNotEmpty &&
          number.text.length != 16 &&
          mounted) {
        setState(() => cardError = '卡號須為 16 位數字，目前輸入 ${number.text.length} 位');
      }
    });
  }

  @override
  void dispose() {
    number.dispose();
    name.dispose();
    cardFocus.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    setState(() {
      busy = true;
      message = null;
    });
    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (photo == null) return;
      final lines =
          await const MethodChannel('townpass/card_ocr')
              .invokeListMethod<String>('recognize', {'path': photo.path}) ??
          [];
      final detected = findCardNumber(lines);
      if (!mounted) return;
      setState(() {
        showForm = true;
        if (detected != null) {
          number.text = detected;
          cardError = null;
          cardLocked = true;
          message = '已辨識，請仔細核對卡號。';
        } else {
          message = '未找到 16 位卡號，請重新拍攝或手動輸入。';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          showForm = true;
          message = '無法使用相機或辨識照片，請檢查相機權限或手動輸入。';
        });
      }
    } finally {
      if (photo != null) {
        try {
          await File(photo.path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => busy = false);
    }
  }

  void finish() {
    FocusScope.of(context).unfocus();
    final digits = number.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      cardError = digits.length == 16
          ? null
          : '卡號須為 16 位數字，目前輸入 ${digits.length} 位';
      schoolError = school == null ? '請先選擇行政區與學校' : null;
    });
    if (cardError != null || schoolError != null) return;
    Navigator.pop(
      context,
      MilkChild(
        id: MilkChild.newId(),
        number: digits,
        name: name.text.trim().isEmpty ? '學生' : name.text.trim(),
        school: school!,
      ),
    );
  }

  Future<void> chooseSchool() async {
    if (district == null) {
      setState(() => schoolError = '請先選擇行政區');
      return;
    }
    var query = '';
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final list = (schools[district] ?? [])
              .where((s) => s.contains(query))
              .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: false,
                      onChanged: (v) => update(() => query = v.trim()),
                      decoration: const InputDecoration(
                        labelText: '搜尋學校名稱',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('找不到學校，請換個關鍵字'))
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (context, i) => ListTile(
                              title: Text(list[i]),
                              onTap: () => Navigator.pop(context, list[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        school = selection;
        schoolError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: '設定學生資料',
    keyboardDone: true,
    children: [
      const _Panel(
        children: [
          _Heading('1　拍攝學生證卡號'),
          SizedBox(height: 8),
          Text('將卡片背面右下方的 16 位數字拍清楚，避免反光。卡號會在下一步供你核對。'),
          SizedBox(height: 8),
          Text('照片只在裝置上辨識，處理後刪除；確認的卡號保存在本機。'),
        ],
      ),
      const SizedBox(height: 12),
      _PrimaryButton(
        label: busy ? '辨識中…' : '拍攝學生證卡號',
        onPressed: busy ? null : scan,
        icon: Icons.camera_alt_outlined,
      ),
      Center(
        child: TextButton(
          onPressed: busy ? null : () => setState(() => showForm = true),
          child: const Text('手動輸入卡號'),
        ),
      ),
      if (showForm) ...[
        const SizedBox(height: 20),
        _Panel(
          children: [
            const _Heading('2　確認卡號與學生資料'),
            const SizedBox(height: 12),
            TextField(
              controller: number,
              focusNode: cardFocus,
              readOnly: cardLocked,
              onChanged: (value) => setState(
                () => cardError = value.isNotEmpty && value.length != 16
                    ? '卡號須為 16 位數字，目前輸入 ${value.length} 位'
                    : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: InputDecoration(
                labelText: '學生證卡號',
                hintText: '輸入 16 位數字',
                errorText: cardError,
                suffixIcon: cardLocked
                    ? TextButton(
                        onPressed: () {
                          setState(() => cardLocked = false);
                          cardFocus.requestFocus();
                        },
                        child: const Text('修改'),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message!, style: const TextStyle(color: _teal)),
              ),
            const SizedBox(height: 16),
            const Text(
              '請確認學生姓名與學校',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: '學生姓名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: district,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '行政區',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final d in schools.keys)
                  DropdownMenuItem(value: d, child: Text(d)),
              ],
              onChanged: (value) => setState(() {
                district = value;
                school = null;
                schoolError = null;
              }),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: chooseSchool,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '學校',
                  errorText: schoolError,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.search),
                ),
                child: Text(
                  school ?? '請選擇學校',
                  style: TextStyle(
                    color: school == null
                        ? TPColors.grayscale600
                        : TPColors.grayscale900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PrimaryButton(label: '確認並完成設定', onPressed: busy ? null : finish),
      ],
    ],
  );
}

class _RedeemPage extends StatefulWidget {
  const _RedeemPage();
  @override
  State<_RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends State<_RedeemPage> {
  String product = '鮮奶';
  @override
  Widget build(BuildContext context) => _Page(
    title: '留下領取紀錄',
    children: [
      const _Panel(
        children: [
          _Heading('已經在門市領取了嗎？'),
          SizedBox(height: 12),
          Text('選擇這次拿到的飲品，完成本週領取紀錄。'),
        ],
      ),
      const SizedBox(height: 20),
      _Panel(
        children: [
          const _Heading('選擇品項'),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final item in ['鮮奶', '豆漿'])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: item == '鮮奶' ? 8 : 0,
                      left: item == '豆漿' ? 8 : 0,
                    ),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(item, textAlign: TextAlign.center),
                      ),
                      selected: product == item,
                      selectedColor: TPColors.primary100,
                      labelStyle: const TextStyle(fontSize: 18),
                      onSelected: (_) => setState(() => product = item),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        label: '我已經拿到了',
        onPressed: () {
          final now = taipeiNow();
          Navigator.pop(context, {
            'week': weekKey(now),
            'product': product,
            'date':
                '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          });
        },
      ),
      const SizedBox(height: 12),
      const Text(
        '鮮奶和豆漿都能收藏一枚印章，漏一週也不會扣章。',
        style: TextStyle(fontSize: 15, color: TPColors.grayscale700),
      ),
    ],
  );
}

class MilkStoresView extends StatefulWidget {
  const MilkStoresView({super.key, this.selectMode = false});
  final bool selectMode;
  @override
  State<MilkStoresView> createState() => _MilkStoresViewState();
}

class _MilkStoresViewState extends State<MilkStoresView> {
  final mapController = MapController();
  LatLng center = const LatLng(25.0375, 121.5645);
  LatLng? currentLocation;
  List<_Store> stores = [];
  String filter = '全部門市', query = '';
  String? error;
  String? locationError;
  bool loading = true;
  bool locating = false;
  bool _mapReady = false;
  bool _simulatedDevice = false;
  int _searchRevision = 0;
  Timer? _mapSearchTimer;
  @override
  void initState() {
    super.initState();
    _search();
    unawaited(_checkLocationSource());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_locate(requestPermission: false));
    });
  }

  @override
  void dispose() {
    _searchRevision++;
    _mapSearchTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationSource() async {
    if (!Platform.isIOS) return;
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      if (mounted) setState(() => _simulatedDevice = !info.isPhysicalDevice);
    } catch (_) {
      // Location still works if device metadata is unavailable.
    }
  }

  Future<void> _search() async {
    _mapSearchTimer?.cancel();
    final revision = ++_searchRevision;
    final searchCenter = center;
    final distanceOrigin = currentLocation ?? searchCenter;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await const MethodChannel('townpass/store_search')
          .invokeListMethod<dynamic>('search', {
            'latitude': searchCenter.latitude,
            'longitude': searchCenter.longitude,
          })
          .timeout(const Duration(seconds: 20));
      if (!mounted || revision != _searchRevision) return;
      final unique = <String, _Store>{};
      for (final item in raw ?? []) {
        final data = Map<String, dynamic>.from(item as Map);
        final name = data['name'] as String? ?? '';
        final lat = (data['latitude'] as num).toDouble();
        final lon = (data['longitude'] as num).toDouble();
        final chain = _chain(name);
        if (chain == null ||
            Geolocator.distanceBetween(
                  searchCenter.latitude,
                  searchCenter.longitude,
                  lat,
                  lon,
                ) >
                6000) {
          continue;
        }
        unique['$name-${lat.toStringAsFixed(4)}-${lon.toStringAsFixed(4)}'] =
            _Store(name, data['address'] as String? ?? '', lat, lon, chain);
      }
      final list = unique.values.toList()
        ..sort(
          (a, b) =>
              Geolocator.distanceBetween(
                distanceOrigin.latitude,
                distanceOrigin.longitude,
                a.lat,
                a.lon,
              ).compareTo(
                Geolocator.distanceBetween(
                  distanceOrigin.latitude,
                  distanceOrigin.longitude,
                  b.lat,
                  b.lon,
                ),
              ),
        );
      setState(() => stores = list);
    } catch (_) {
      if (mounted && revision == _searchRevision) {
        setState(() {
          stores = [];
          error = '無法載入門市，請檢查網路並重試。';
        });
      }
    } finally {
      if (mounted && revision == _searchRevision) {
        setState(() => loading = false);
      }
    }
  }

  String? _chain(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('7-ELEVEN') ||
        upper.contains('7-11') ||
        upper.contains('統一超商')) {
      return '7-ELEVEN';
    }
    if (name.contains('全家') || upper.contains('FAMILYMART')) return '全家';
    if (upper.contains('OK')) return 'OK';
    if (name.contains('全聯')) return '全聯';
    if (name.contains('美廉社')) return '美廉社';
    if (name.contains('樂家康')) return '樂家康';
    if (name.contains('萊爾富') || upper.contains('HILIFE')) return '萊爾富';
    return null;
  }

  Future<void> _locate({bool requestPermission = true}) async {
    if (locating) return;
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(
            () => locationError =
                '定位服務未開啟，請先在系統設定開啟定位。'
                '${currentLocation == null ? '' : '藍點是上次取得的位置。'}',
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(
            () => locationError =
                '${permission == LocationPermission.deniedForever ? '定位權限已關閉，請在 App 的系統設定允許使用位置。' : '尚未取得位置。請點「使用目前位置」並允許定位權限。'}'
                '${currentLocation == null ? '' : '藍點是上次取得的位置。'}',
          );
        }
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw StateError('location permission unavailable');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      if (!pos.latitude.isFinite ||
          !pos.longitude.isFinite ||
          pos.latitude.abs() > 90 ||
          pos.longitude.abs() > 180) {
        throw StateError('invalid location');
      }
      setState(() {
        currentLocation = LatLng(pos.latitude, pos.longitude);
        center = currentLocation!;
      });
      if (_mapReady) mapController.move(center, 15);
      await _search();
    } on TimeoutException {
      if (mounted) {
        setState(
          () => locationError = currentLocation == null
              ? '定位逾時，尚未取得目前位置，請稍後重試。'
              : '無法更新位置，藍點為上次取得的位置，請重試。',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => locationError = currentLocation == null
              ? '無法取得位置，請確認定位權限後重試。'
              : '無法更新位置，藍點為上次取得的位置，請重試。',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _showStore(_Store store) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.name, style: TPTextStyles.h2SemiBold),
            const SizedBox(height: 12),
            Text(
              store.address.isEmpty ? '地址未提供' : store.address,
              style: TPTextStyles.h3Regular,
            ),
            const SizedBox(height: 8),
            const Text('是否可兌領請向門市確認。'),
            const SizedBox(height: 20),
            _PrimaryButton(
              label: '使用 Apple 地圖導航',
              icon: Icons.directions_outlined,
              onPressed: () async {
                final uri = Uri.https('maps.apple.com', '/', {
                  'daddr': '${store.lat},${store.lon}',
                  'dirflg': 'w',
                });
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (sheetContext.mounted && !opened) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('無法開啟地圖，請稍後再試。')),
                  );
                }
              },
            ),
            if (widget.selectMode)
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pop(context, store);
                },
                child: const Text('選擇這間門市'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceOrigin = currentLocation ?? center;
    final filtered = stores
        .where(
          (s) =>
              (filter == '全部門市' || s.chain == filter) &&
              (query.isEmpty ||
                  s.name.contains(query) ||
                  s.address.contains(query)),
        )
        .toList();
    return _Page(
      title: widget.selectMode ? '選擇門市' : '附近門市',
      children: [
        TextField(
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onChanged: (v) => setState(() => query = v.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '搜尋門市或地址',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final label in [
                '全部門市',
                '7-ELEVEN',
                '全家',
                'OK',
                '全聯',
                '美廉社',
                '樂家康',
                '萊爾富',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: filter == label,
                    selectedColor: _teal,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: filter == label
                          ? Colors.white
                          : TPColors.grayscale800,
                    ),
                    onSelected: (_) => setState(() => filter = label),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 280,
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onPositionChanged: (camera, hasGesture) {
                  if (!hasGesture) return;
                  _mapSearchTimer?.cancel();
                  _searchRevision++;
                  center = camera.center;
                  _mapSearchTimer = Timer(
                    const Duration(milliseconds: 700),
                    () {
                      if (mounted) _search();
                    },
                  );
                },
                onMapReady: () {
                  _mapReady = true;
                  if (currentLocation != null) mapController.move(center, 15);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.quentinchih.townpass.preview',
                ),
                MarkerLayer(
                  markers: [
                    for (final s in filtered)
                      Marker(
                        point: LatLng(s.lat, s.lon),
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: Semantics(
                          button: true,
                          label: '查看${s.name}路線',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showStore(s),
                            child: const Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.location_on, color: _teal, size: 42),
                                Positioned(
                                  top: 12,
                                  child: CircleAvatar(
                                    radius: 3,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation!,
                        width: 28,
                        height: 28,
                        child: Semantics(
                          key: const Key('milk-current-location'),
                          label: '目前位置',
                          child: Tooltip(
                            message: '目前位置',
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: locating ? null : () => _locate(),
                icon: const Icon(Icons.my_location),
                label: Text(locating ? '定位中…' : '使用目前位置'),
              ),
            ),
            Container(width: 1, height: 28, color: TPColors.grayscale200),
            Expanded(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: () {
                  center = mapController.camera.center;
                  _search();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('搜尋地圖範圍'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            locationError ??
                (currentLocation == null
                    ? '移動地圖後會自動搜尋附近門市。'
                    : (_simulatedDevice
                          ? '藍點是目前位置；移動地圖後會自動搜尋門市。'
                          : '藍點是裝置提供的位置；移動地圖後會自動搜尋門市。')),
            style: TextStyle(
              fontSize: 14,
              color: locationError == null
                  ? TPColors.grayscale700
                  : TPColors.red700,
            ),
          ),
        ),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Text(error!, style: const TextStyle(color: TPColors.red700))
        else ...[
          Text(
            '附近門市・共 ${filtered.length} 間',
            style: const TextStyle(color: _teal),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty) const _Panel(children: [Text('附近找不到符合條件的門市。')]),
          for (final s in filtered) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showStore(s),
              child: _Panel(
                children: [
                  _Heading(s.name),
                  const SizedBox(height: 6),
                  Text(s.address.isEmpty ? '地址未提供' : s.address),
                  const SizedBox(height: 6),
                  Text(
                    '${currentLocation == null ? '距搜尋中心' : '距目前位置'} ${(Geolocator.distanceBetween(distanceOrigin.latitude, distanceOrigin.longitude, s.lat, s.lon) / 1000).toStringAsFixed(1)} 公里',
                  ),
                  const SizedBox(height: 4),
                  const Text('查看門市與路線', style: TextStyle(color: _teal)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _Store {
  const _Store(this.name, this.address, this.lat, this.lon, this.chain);
  final String name, address, chain;
  final double lat, lon;
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.children,
    this.action,
    this.keyboardDone = false,
  });
  final String title;
  final List<Widget> children;
  final Widget? action;
  final bool keyboardDone;
  @override
  Widget build(BuildContext context) => Theme(
    data: MilkFeatureTheme.data(Theme.of(context)).copyWith(
      textTheme: MilkFeatureTheme.data(Theme.of(context)).textTheme
          .apply(fontFamily: 'PingFangTC', bodyColor: TPColors.grayscale800)
          .copyWith(
            bodyMedium: const TextStyle(
              fontFamily: 'PingFangTC',
              fontSize: 16,
              height: 1.5,
              color: TPColors.grayscale800,
            ),
            bodyLarge: const TextStyle(
              fontFamily: 'PingFangTC',
              fontSize: 18,
              height: 1.45,
              color: TPColors.grayscale800,
            ),
          ),
    ),
    child: Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: TPAppBar(
        title: title,
        actions: action == null ? null : [action!],
      ),
      bottomNavigationBar:
          keyboardDone && MediaQuery.viewInsetsOf(context).bottom > 0
          ? Material(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: TPCard(
      cornerRadius: 8,
      padding: const EdgeInsets.all(20),
      child: Material(
        color: TPColors.white,
        child: DefaultTextStyle.merge(
          style: TPTextStyles.h3Regular.copyWith(
            color: TPColors.grayscale800,
            height: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TPTextStyles.h3SemiBold.copyWith(
      fontSize: 20,
      height: 1.35,
      color: TPColors.grayscale900,
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: TPColors.primary700,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        textStyle: TPTextStyles.h3SemiBold.copyWith(fontSize: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon),
      label: Text(label),
    ),
  );
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 29,
        backgroundColor: TPColors.primary100,
        child: Icon(icon, size: 29, color: _teal),
      ),
      const SizedBox(height: 10),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TPTextStyles.bodySemiBold.copyWith(fontSize: 15),
      ),
    ],
  );
}
