import 'package:flutter/material.dart';
import 'package:town_pass/page/city_service/milk_route_view.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/service/milk_outing.dart';
import 'package:town_pass/service/milk_route.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Uses the screen's existing six-second family refresh. Mutations pause that
/// refresh so an older GET cannot replace the just-confirmed plan.
class MilkOutingCard extends StatefulWidget {
  const MilkOutingCard({
    super.key,
    required this.profile,
    required this.childMode,
    required this.enabled,
    required this.onBusyChanged,
    required this.onChanged,
    required this.onRefresh,
    this.chooseNearby,
  });
  final Map<String, dynamic> profile;
  final bool childMode, enabled;
  final ValueChanged<bool> onBusyChanged;
  final Future<void> Function(Map<String, dynamic>) onChanged;
  final Future<void> Function() onRefresh;
  final Future<MilkRouteStop?> Function()? chooseNearby;

  @override
  State<MilkOutingCard> createState() => _MilkOutingCardState();
}

class _MilkOutingCardState extends State<MilkOutingCard> {
  bool busy = false;
  String? error;

  Future<void> _act(String action) async {
    if (busy || !widget.enabled) return;
    final snapshot = widget.profile;
    final outing = MilkOuting.fromProfile(snapshot);
    setState(() {
      busy = true;
      error = null;
    });
    widget.onBusyChanged(true);
    var refresh = false;
    try {
      if (!widget.childMode &&
          !await MilkFamilySync.isShared(snapshot['id'] as String)) {
        throw const FormatException('請先按「邀請孩子」完成家庭連結，再安排一起去領。');
      }
      MilkOutingPlan? plan;
      if (action == 'plan') {
        if (!mounted) return;
        plan = await Navigator.push<MilkOutingPlan>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MilkOutingPlanView(chooseNearby: widget.chooseNearby),
          ),
        );
        if (plan == null || !mounted) return;
      }
      final updated = await MilkFamilySync.updateOuting(
        childId: widget.childMode ? null : snapshot['id'] as String,
        action: action,
        expectedRevision: outing?.revision ?? 0,
        store: plan?.store.toJson(),
        plannedAt: plan?.plannedAt,
      );
      if (mounted) await widget.onChanged(updated);
    } on MilkSyncException catch (e) {
      refresh = true;
      if (mounted) {
        setState(
          () => error = e.statusCode == 409
              ? '行程剛剛有更新，已重新取得狀態，請確認後再操作。'
              : e.message,
        );
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      // A timeout may follow a successful write. Reload instead of claiming it
      // failed or automatically replaying a different plan.
      refresh = true;
      if (mounted) setState(() => error = '尚未確認是否送達。請連線後更新行程再確認。');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged(false);
        if (refresh) await widget.onRefresh();
      }
    }
  }

  Future<void> _directions(Map<String, dynamic> store) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${store['latitude']},${store['longitude']}',
      'travelmode': 'walking',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('map');
      }
    } catch (_) {
      if (mounted) setState(() => error = '無法開啟地圖，請稍後重試。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final outing = MilkOuting.fromProfile(widget.profile);
    final status = outing?.status;
    final recorded = (widget.profile['records'] as List? ?? []).any(
      (r) => r is Map && r['week'] == milkOutingWeek(DateTime.now()),
    );
    final done = status == 'completed' || recorded;
    final active = status == 'requested' || status == 'planned';
    final canAct = widget.enabled && !busy;
    final title = done
        ? '本週領取已完成'
        : switch (status) {
            'requested' => widget.childMode ? '已邀請家長陪你去' : '孩子想和你一起去！',
            'planned' => '約好了，一起去領！',
            'canceled' => '行程已取消，可以再約',
            _ => widget.childMode ? '找家人一起去領吧' : '把這週的鮮奶，變成一起的小旅行',
          };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TPColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TPColors.grayscale200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.diversity_1_outlined, color: TPColors.primary800),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '一起去領',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: TPColors.primary900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (status == 'planned' && !done) ...[
            Text(
              outing!.store?['name']?.toString() ?? '已選門市',
              style: const TextStyle(fontSize: 18),
            ),
            Text(outing.whenLabel, style: const TextStyle(fontSize: 16)),
            if (outing.store?['address'] is String &&
                (outing.store!['address'] as String).isNotEmpty)
              Text(outing.store!['address'] as String),
            const SizedBox(height: 8),
            const Text('出發時記得帶上孩子的實體卡證。'),
            TextButton.icon(
              onPressed: () => _directions(outing.store!),
              icon: const Icon(Icons.directions_walk),
              label: const Text('開啟前往門市的路線'),
            ),
          ] else if (!done)
            Text(
              widget.childMode
                  ? '按一下，讓家長知道你想找人陪。家長選好門市與時間後，這裡就會更新。'
                  : '孩子可以在兒童版邀請你；你也能主動選好門市與時間。',
            ),
          if (!done) ...[
            const SizedBox(height: 12),
            if (widget.childMode && !active)
              FilledButton.icon(
                onPressed: canAct ? () => _act('request') : null,
                icon: const Icon(Icons.favorite_border),
                label: Text(busy ? '傳送中…' : '陪我去領'),
              ),
            if (!widget.childMode)
              FilledButton.icon(
                onPressed: canAct ? () => _act('plan') : null,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(
                  busy
                      ? '處理中…'
                      : status == 'planned'
                      ? '更改門市與時間'
                      : '安排一起去',
                ),
              ),
            if (active)
              TextButton(
                onPressed: canAct ? () => _act('cancel') : null,
                child: Text(status == 'requested' ? '取消邀請' : '取消行程'),
              ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: TPColors.red700)),
          ],
          const SizedBox(height: 8),
          Text(
            busy
                ? '正在更新行程…'
                : widget.enabled
                ? '和家人約好時間，一起順路領。'
                : '行程暫時無法更改，請稍後再試。',
            style: const TextStyle(fontSize: 13, color: TPColors.grayscale700),
          ),
        ],
      ),
    );
  }
}

class MilkOutingPlan {
  const MilkOutingPlan(this.store, this.plannedAt);
  final MilkRouteStop store;
  final DateTime plannedAt;
}

class MilkOutingPlanView extends StatefulWidget {
  const MilkOutingPlanView({super.key, this.chooseNearby});
  final Future<MilkRouteStop?> Function()? chooseNearby;
  @override
  State<MilkOutingPlanView> createState() => _MilkOutingPlanViewState();
}

class _MilkOutingPlanViewState extends State<MilkOutingPlanView> {
  MilkRouteStop? store;
  late DateTime day;
  late TimeOfDay time;
  String? error;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    var next = milkTaipeiDate(now.add(const Duration(minutes: 30)));
    if (milkOutingWeek(now) !=
        milkOutingWeek(now.add(const Duration(minutes: 30)))) {
      final today = milkTaipeiDate(now);
      next = DateTime.utc(today.year, today.month, today.day, 23, 59);
    }
    day = DateTime(next.year, next.month, next.day);
    time = TimeOfDay(hour: next.hour, minute: next.minute);
  }

  Future<void> _choose(bool route) async {
    final picked = route
        ? await Navigator.push<MilkRouteStop>(
            context,
            MaterialPageRoute(
              builder: (_) => const MilkRouteView(selectMode: true),
            ),
          )
        : await widget.chooseNearby?.call();
    if (mounted && picked != null) {
      setState(() {
        store = picked;
        error = null;
      });
    }
  }

  void _finish() {
    if (store == null) {
      setState(() => error = '請先選擇一起去的門市。');
      return;
    }
    final instant = DateTime.utc(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    ).subtract(const Duration(hours: 8));
    final now = DateTime.now();
    if (!instant.isAfter(now) ||
        milkOutingWeek(instant) != milkOutingWeek(now)) {
      setState(() => error = '請選擇本週尚未到來的時間。');
      return;
    }
    Navigator.pop(context, MilkOutingPlan(store!, instant));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('安排一起去')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '選一站，再約一個時間',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: TPColors.primary900,
            ),
          ),
          const SizedBox(height: 10),
          const Text('選好門市與時間，讓孩子知道這次一起去哪裡。'),
          const SizedBox(height: 24),
          const Text(
            '1．一起去哪裡？',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (store != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront, color: TPColors.primary700),
              title: Text(store!.name),
              subtitle: Text(store!.address),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => _choose(true),
            icon: const Icon(Icons.route_outlined),
            label: const Text('找放學順路的門市'),
          ),
          if (widget.chooseNearby != null)
            TextButton.icon(
              onPressed: () => _choose(false),
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('從附近門市選擇'),
            ),
          const SizedBox(height: 24),
          const Text(
            '2．什麼時候出發？',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final today = milkTaipeiDate(DateTime.now());
              final first = DateTime(today.year, today.month, today.day);
              final last = first.add(Duration(days: 7 - today.weekday));
              final picked = await showDatePicker(
                context: context,
                initialDate: day.isBefore(first)
                    ? first
                    : day.isAfter(last)
                    ? last
                    : day,
                firstDate: first,
                lastDate: last,
              );
              if (mounted && picked != null) setState(() => day = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('${day.month}/${day.day}'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (mounted && picked != null) setState(() => time = picked);
            },
            icon: const Icon(Icons.schedule),
            label: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}（台北時間）',
            ),
          ),
          const SizedBox(height: 24),
          const Text('確認後，已連結的孩子也會看到這次行程。'),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: const TextStyle(color: TPColors.red700),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.check),
            label: const Text('確認並分享行程'),
          ),
        ],
      ),
    ),
  );
}
