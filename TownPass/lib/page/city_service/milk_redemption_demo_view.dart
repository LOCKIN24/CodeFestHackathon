import 'dart:async';

import 'package:flutter/material.dart';
import 'package:town_pass/service/milk_reminder_service.dart';
import 'package:town_pass/service/milk_redemption_demo.dart';
import 'package:town_pass/page/city_service/milk_passport_view.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text_styles.dart';
import 'package:town_pass/util/tp_card.dart';
import 'package:town_pass/util/milk_feature_theme.dart';
import 'package:town_pass/service/milk_reminder_target.dart';
import 'package:town_pass/page/city_service/milk_reminder_preview.dart';

class MilkRedemptionDemoView extends StatefulWidget {
  const MilkRedemptionDemoView({
    super.key,
    this.reminderChildId,
    this.familyMode = false,
  });
  final String? reminderChildId;
  final bool familyMode;
  @override
  State<MilkRedemptionDemoView> createState() => _MilkRedemptionDemoViewState();
}

class _MilkRedemptionDemoViewState extends State<MilkRedemptionDemoView> {
  final address = TextEditingController(
    text: const String.fromEnvironment(
      'MILK_POS_DEMO_SERVER',
      defaultValue: 'local',
    ),
  );
  MilkDemoSession? session;
  String? selected, error, outcome;
  Map<String, dynamic>? lastEvent;
  String product = '鮮奶';
  bool busy = true;

  @override
  void initState() {
    super.initState();
    _openSaved();
  }

  Future<void> _openSaved() async {
    try {
      final url = await MilkRedemptionDemo.savedUrl();
      if (!mounted) return;
      if (url != null) address.text = url;
    } catch (_) {
      /* The rebuild action can replace invalid demo preferences. */
    }
    if (widget.familyMode) address.text = "family-local";
    if (mounted) await _connect();
  }

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  String _error(Object e) => e is MilkSyncException
      ? (e.sessionExpired ? '連線已失效，請重新連線。' : e.message)
      : e is FormatException
      ? '資料暫時無法讀取，請重新整理。'
      : '暫時無法取得領取資料，請稍後再試。';

  Future<void> _connect({bool fresh = false}) async {
    setState(() {
      busy = true;
      error = null;
      outcome = null;
    });
    try {
      final value = widget.familyMode
          ? await MilkRedemptionDemo.openFamily()
          : await MilkRedemptionDemo.open(address.text, fresh: fresh);
      if (value.children.isEmpty) {
        if (mounted) {
          setState(() {
            session = value;
            selected = null;
            lastEvent = null;
          });
        }
        return;
      }
      final requested =
          !fresh && selected == null && widget.reminderChildId != null
          ? value.children
                .where((c) => c['id'] == widget.reminderChildId)
                .firstOrNull
          : null;
      if (!fresh &&
          selected == null &&
          widget.reminderChildId != null &&
          requested == null) {
        throw const FormatException('這則提醒已失效，請返回查看最新狀態。');
      }
      final card = fresh || !value.children.any((c) => c['cardRef'] == selected)
          ? (requested ?? value.children.first)['cardRef'] as String
          : selected!;
      final event = await MilkRedemptionDemo.lastEvent(value, card);
      if (mounted) {
        setState(() {
          session = value;
          selected = card;
          lastEvent = event;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _choose(String cardRef) async {
    if (busy) return;
    setState(() {
      selected = cardRef;
      lastEvent = null;
      outcome = null;
      busy = true;
    });
    try {
      final event = await MilkRedemptionDemo.lastEvent(session!, cardRef);
      if (mounted) setState(() => lastEvent = event);
    } catch (e) {
      if (mounted) setState(() => error = _error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit({bool repeat = false}) async {
    if (busy || session == null || selected == null) return;
    setState(() {
      busy = true;
      error = null;
      outcome = null;
    });
    try {
      final result = await MilkRedemptionDemo.redeem(
        session!,
        selected!,
        product,
        repeat: repeat,
      );
      if (widget.familyMode) unawaited(MilkReminderService.refresh());
      if (mounted) {
        setState(() {
          session = session!.replaceChild(result.child);
          outcome = switch (result.result) {
            'accepted' => '領取完成，已更新本週狀態。',
            'duplicate_transaction' => '這筆領取已完成。',
            _ => '這位孩子本週已經領取。',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '暫時無法確認領取結果。${_error(e)}重試不會重複領取。');
      }
    } finally {
      try {
        final event = await MilkRedemptionDemo.lastEvent(session!, selected!);
        if (mounted) setState(() => lastEvent = event);
      } catch (e) {
        if (mounted && error == null) setState(() => error = _error(e));
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  Future<void> _rebuild() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => MilkFeatureTheme(
        child: AlertDialog(
          backgroundColor: TPColors.white,
          title: const Text('重建展示家庭？'),
          content: const Text('將建立全新的虛構家庭，方便重新演示。原有學生資料、卡號與家庭連線不會變更。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重建展示資料'),
            ),
          ],
        ),
      ),
    );
    if (yes == true && mounted) await _connect(fresh: true);
  }

  String _weekKey() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .toIso8601String()
        .substring(0, 10);
  }

  Map<String, dynamic>? _thisWeek(Map<String, dynamic> child) {
    final week = _weekKey();
    for (final r in child['records'] as List) {
      if (r['week'] == week) return Map<String, dynamic>.from(r as Map);
    }
    return null;
  }

  Future<void> _settings() async {
    var working = false;
    Future<void> run(
      Future<void> Function() action,
      StateSetter refresh,
      BuildContext dialog,
    ) async {
      if (working || busy) return;
      refresh(() => working = true);
      try {
        await action();
      } finally {
        if (dialog.mounted) refresh(() => working = false);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MilkFeatureTheme(
        child: StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            backgroundColor: TPColors.white,
            title: const Text('展示設定'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('黑客松展示版本，可使用本機模擬資料或區域網路 API。此設定不會改變家長帳戶資料。'),
                    const SizedBox(height: 16),
                    if (widget.familyMode) const Text('資料來源：這台手機的家庭資料'),
                    if (!widget.familyMode)
                      TextField(
                        controller: address,
                        enabled: !widget.familyMode && !busy && !working,
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: '資料來源（local 或服務網址）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (!widget.familyMode && address.text != 'local')
                      const Text('手機請使用同一 Wi-Fi 電腦的區網網址。'),
                    TextButton(
                      onPressed: busy || working
                          ? null
                          : () async {
                              await run(() => _connect(), refresh, context);
                            },
                      child: const Text('連線／更新狀態'),
                    ),
                    if (!widget.familyMode)
                      TextButton(
                        onPressed: widget.familyMode || busy || working
                            ? null
                            : () async {
                                await run(_rebuild, refresh, context);
                              },
                        child: const Text('重建展示家庭'),
                      ),
                    if (lastEvent?['week'] == _weekKey())
                      TextButton(
                        onPressed: busy || working
                            ? null
                            : () async {
                                await run(
                                  () => _submit(repeat: true),
                                  refresh,
                                  context,
                                );
                              },
                        child: const Text('重送同筆交易（測試防重複）'),
                      ),
                    if (session != null)
                      MilkReminderPreview(
                        enabled: !busy && !working && error == null,
                        targets: MilkReminderTarget.pending(
                          session!.children,
                          role: 'demo',
                          now: DateTime.now().toUtc().add(
                            const Duration(hours: 8),
                          ),
                        ),
                        onOpen: (target) async {
                          Navigator.pop(dialogContext);
                          await Navigator.push<void>(
                            this.context,
                            MaterialPageRoute(
                              builder: (_) => MilkRedemptionDemoView(
                                reminderChildId: target.childId,
                                familyMode: widget.familyMode,
                              ),
                            ),
                          );
                          if (mounted) await _connect();
                        },
                      ),
                    if (outcome != null)
                      Text(
                        outcome!,
                        style: const TextStyle(color: TPColors.primary800),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: TPColors.red700),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(int step, String label) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: TPColors.primary100,
          child: Text(
            '$step',
            style: TPTextStyles.bodySemiBold.copyWith(
              color: TPColors.primary800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TPTextStyles.h3SemiBold.copyWith(fontSize: 18),
          ),
        ),
      ],
    ),
  );

  Widget _choice({
    required String label,
    required String detail,
    required bool checked,
    required bool enabled,
    required VoidCallback onTap,
    IconData? icon,
    Key? key,
  }) {
    final color = enabled ? TPColors.primary700 : TPColors.grayscale600;
    return Semantics(
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      key: key,
      label: '$label，$detail',
      checked: checked,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      button: true,
      child: Material(
        color: checked ? TPColors.primary50 : TPColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: checked ? TPColors.primary700 : TPColors.grayscale200,
            width: checked ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 22,
                    height: 22,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TPColors.white,
                      border: Border.all(
                        color: checked
                            ? TPColors.primary700
                            : TPColors.grayscale500,
                        width: 2,
                      ),
                    ),
                    child: checked
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: TPColors.primary700,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Icon(icon, color: color, size: 28),
                        ),
                      Text(
                        label,
                        style: TPTextStyles.h3SemiBold.copyWith(
                          fontSize: 18,
                          color: TPColors.grayscale950,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: TPTextStyles.bodyRegular.copyWith(
                          color: TPColors.grayscale700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvent = lastEvent?['week'] == _weekKey() ? lastEvent : null;
    final current = session?.children
        .where((c) => c['cardRef'] == selected)
        .firstOrNull;
    final record = current == null ? null : _thisWeek(current);
    final shownProduct = (visibleEvent?['product'] ?? product) as String;
    return MilkFeatureTheme(
      child: Scaffold(
        backgroundColor: TPColors.grayscale50,
        appBar: AppBar(
          backgroundColor: TPColors.white,
          foregroundColor: TPColors.grayscale950,
          title: const Text('領取鮮奶'),
          actions: [
            IconButton(
              tooltip: '展示設定',
              onPressed: busy ? null : _settings,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TPColors.grayscale100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: TPColors.grayscale800),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '每週一瓶，鮮奶與豆漿自由選擇',
                        style: TextStyle(color: TPColors.grayscale800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '今天想喝什麼？',
                style: TPTextStyles.h2SemiBold.copyWith(
                  color: TPColors.grayscale950,
                ),
              ),
              const SizedBox(height: 8),
              const Text('選擇孩子與飲品，確認後即可完成領取。'),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TPCard(
                    cornerRadius: 12,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '暫時無法確認，請稍後再試。',
                          style: TextStyle(color: TPColors.red700),
                        ),
                        if (session != null) const Text('目前顯示上次取得的體驗資料。'),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => visibleEvent != null
                                    ? _submit(repeat: true)
                                    : _connect(),
                          child: Text(visibleEvent != null ? '重試原交易' : '重新連線'),
                        ),
                        TextButton(
                          onPressed: busy ? null : _settings,
                          child: const Text('檢查展示設定'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (session != null && session!.children.isEmpty)
                TPCard(
                  cornerRadius: 12,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '先新增孩子，再選擇飲品。',
                        style: TPTextStyles.h3SemiBold,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回家庭設定'),
                      ),
                    ],
                  ),
                ),
              if (session != null && session!.children.isNotEmpty) ...[
                _section(1, '選擇孩子'),
                for (final child in session!.children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _choice(
                      key: ValueKey('demo-child-${child['id']}'),
                      label: child['alias'] as String,
                      detail: _thisWeek(child) == null ? '本週尚未領取' : '本週已領取',
                      checked: child['cardRef'] == selected,
                      enabled: !busy,
                      onTap: () => _choose(child['cardRef'] as String),
                    ),
                  ),
                _section(2, '選擇飲品'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        MediaQuery.textScalerOf(context).scale(16) > 23;
                    final width = stacked
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in ['鮮奶', '豆漿'])
                          SizedBox(
                            width: width,
                            child: _choice(
                              key: ValueKey('demo-drink-$item'),
                              label: item,
                              detail: '1 瓶',
                              icon: item == '鮮奶'
                                  ? Icons.local_drink_outlined
                                  : Icons.coffee_outlined,
                              checked: shownProduct == item,
                              enabled:
                                  !busy &&
                                  visibleEvent == null &&
                                  record == null,
                              onTap: () => setState(() => product = item),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                _section(3, '確認領取'),
                TPCard(
                  cornerRadius: 12,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${current?['alias'] ?? ''} · $shownProduct 1 瓶',
                        style: TPTextStyles.h3SemiBold,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed:
                            busy ||
                                selected == null ||
                                record != null ||
                                error != null
                            ? null
                            : () => _submit(),
                        icon: Icon(
                          record != null
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward,
                        ),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            record != null ? '本週已領取' : '領取 1 瓶$shownProduct',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '每位孩子每週可領取一瓶，完成後可在鮮奶護照查看印章。',
                        style: TextStyle(
                          color: TPColors.grayscale700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (outcome != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        record != null ? '領取完成，護照已收藏這一週的印章。' : outcome!,
                        style: TPTextStyles.h3SemiBold.copyWith(
                          color: TPColors.primary800,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (current != null)
                  MilkPassportCard(
                    key: ValueKey('demo-passport-${current['id']}'),
                    isDemo: true,
                    records: (current['records'] as List)
                        .map((r) => Map<String, dynamic>.from(r as Map))
                        .toList(),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: Text(
                    '領取紀錄',
                    style: TPTextStyles.h3SemiBold.copyWith(fontSize: 18),
                  ),
                ),
                TPCard(
                  cornerRadius: 12,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (current != null &&
                          (current['records'] as List).isEmpty)
                        const Text('還沒有領取紀錄'),
                      if (current != null)
                        for (final r in current['records'] as List)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle_outline,
                              color: TPColors.primary700,
                            ),
                            title: Text(
                              '${r['product']} · ${r['source'] == 'demo_transaction' ? '已領取' : '家人已記錄'}',
                            ),
                            subtitle: Text('${r['date']}'),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
