import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:town_pass/service/milk_route.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_card.dart';
import 'package:town_pass/util/tp_text_styles.dart';
import 'package:town_pass/util/milk_feature_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resolve the selected child’s school and search for a home address.
/// The schematic joining the two points is not a walking route.
class MilkRouteView extends StatefulWidget {
  const MilkRouteView({super.key, this.selectMode = false});
  final bool selectMode;
  @override
  State<MilkRouteView> createState() => _MilkRouteViewState();
}

class _MilkRouteViewState extends State<MilkRouteView> {
  final _map = MapController();
  LatLng? _school, _home;
  bool _loading = false, _saving = false;
  String? _schoolName;
  bool _ready = false, _searched = false, _restoring = true;
  int _revision = 0;
  String? _error, _notice;
  List<MilkRouteCandidate> _candidates = [];
  MilkRouteStop? _selected;
  MilkRoute? get _route => _school == null || _home == null
      ? null
      : MilkRoute(school: _school!, home: _home!);

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final saved = await MilkRouteStore.load();
      final children = await MilkFamilyStore.load();
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString(MilkFamilyStore.selectedKey);
      final matching = children.where((child) => child.id == selectedId);
      final child = matching.isNotEmpty
          ? matching.first
          : (children.isNotEmpty ? children.first : null);
      if (!mounted || revision != _revision) return;
      setState(() {
        _schoolName = child?.school;
        _home = saved?.home;
        _error = null;
      });
      LatLng? school;
      if (child != null) {
        final results = await _places(child.school);
        String normalize(String value) =>
            value.replaceAll('臺', '台').replaceAll(RegExp(r'\s+'), '');
        final matches = results.where(
          (item) =>
              normalize(item['name'] as String)
                  .contains(normalize(child.school)) &&
              MilkRoute.validPoint(_point(item)),
        );
        if (matches.length == 1) school = _point(matches.first);
      }
      if (!mounted || revision != _revision) return;
      setState(() {
        _schoolName = child?.school;
        _school = school;
        _home = saved?.home;
        if (child == null) {
          _error = '請先新增孩子及學校資料。';
        } else if (school == null) {
          _error = '無法確認學校位置，請檢查網路或學校資料後重試。';
        }
      });
      _fit();
      if (_route?.validationError == null && _route != null)
        unawaited(_search());
    } catch (_) {
      if (mounted) setState(() => _error = '無法讀取學校位置，請檢查網路後重試。');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  void dispose() {
    _revision++;
    _map.dispose();
    super.dispose();
  }

  void _fit() {
    if (!_ready || _school == null) return;
    if (_home == null) {
      _map.move(_school!, 15);
    } else if (_route!.validationError == null) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            _school!,
            if (_selected != null) _selected!.point,
            _home!,
          ]),
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
    }
  }

  Future<List<Map<dynamic, dynamic>>> _places(String query) async {
    final items = await const MethodChannel('townpass/place_search')
        .invokeListMethod<dynamic>('search', {'query': query})
        .timeout(const Duration(seconds: 20));
    return (items ?? [])
        .whereType<Map>()
        .where(
          (item) =>
              item['name'] is String &&
              item['latitude'] is num &&
              item['longitude'] is num,
        )
        .toList();
  }

  LatLng _point(Map item) => LatLng(
    (item['latitude'] as num).toDouble(),
    (item['longitude'] as num).toDouble(),
  );

  Future<void> _homeSearch() async {
    final controller = TextEditingController();
    final point = await showDialog<LatLng>(
      context: context,
      builder: (context) {
        List<Map<dynamic, dynamic>> results = [];
        bool loading = false;
        String? error;
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('搜尋回家位置'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: '地址或地點名稱'),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (controller.text.trim().isEmpty) return;
                            update(() {
                              loading = true;
                              error = null;
                              results = [];
                            });
                            try {
                              final found = await _places(
                                controller.text.trim(),
                              );
                              if (context.mounted)
                                update(() {
                                  results = found;
                                  if (found.isEmpty) error = '找不到地點，請試試完整地址。';
                                });
                            } catch (_) {
                              if (context.mounted)
                                update(() => error = '無法搜尋地點，請檢查網路後重試。');
                            } finally {
                              if (context.mounted)
                                update(() => loading = false);
                            }
                          },
                    child: Text(loading ? '搜尋中…' : '搜尋'),
                  ),
                  if (error != null) Text(error!),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final item in results)
                          ListTile(
                            title: Text(item['name'] as String),
                            subtitle: Text(item['address'] as String? ?? ''),
                            onTap: () => Navigator.pop(context, _point(item)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        );
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (!mounted || point == null) return;
    _revision++;
    setState(() {
      _home = point;
      _candidates = [];
      _searched = false;
      if (_school != null) _error = null;
    });
    _fit();
    if (_route?.validationError == null && _route != null) {
      if (await _save()) await _search();
    }
  }

  Future<void> _search() async {
    final route = _route;
    if (route == null || route.validationError != null) return;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
      _candidates = [];
      _selected = null;
      _searched = true;
    });
    try {
      final responses = await Future.wait(
        route.searchCenters.map(
          (center) => const MethodChannel('townpass/store_search')
              .invokeListMethod<dynamic>('search', {
                'latitude': center.latitude,
                'longitude': center.longitude,
              })
              .timeout(const Duration(seconds: 20)),
        ),
      );
      if (!mounted || revision != _revision) return;
      final shops = responses
          .expand((items) => items ?? [])
          .map(MilkRouteStop.fromSearch)
          .whereType<MilkRouteStop>();
      setState(() => _candidates = route.rank(shops).take(12).toList());
      _fit();
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = '無法搜尋門市，請檢查網路後再試一次。');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<bool> _save() async {
    final route = _route;
    if (route == null || route.validationError != null || _saving) return false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MilkRouteStore.save(route);
      if (mounted) setState(() => _notice = '放學行程已儲存，下次可以直接找順路門市。');
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = '無法儲存行程，請重試。');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    if (_saving) return;
    _revision++;
    setState(() {
      _saving = true;
      _loading = false;
      _error = null;
    });
    try {
      await MilkRouteStore.clear();
      if (mounted) {
        setState(() {
          _home = null;
          _candidates = [];
          _selected = null;
          _searched = false;
          _notice = '已清除這台手機儲存的放學行程。';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '無法清除行程，請重試。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _directions(MilkRouteStop stop) async {
    try {
      final opened = await launchUrl(
        Uri.https('maps.apple.com', '/', {
          'daddr': '${stop.latitude},${stop.longitude}',
          'dirflg': 'w',
        }),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('maps unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('無法開啟地圖，請稍後再試。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final valid = route != null && route.validationError == null;
    return MilkFeatureTheme(
      child: Scaffold(
        backgroundColor: TPColors.grayscale50,
        appBar: TPAppBar(title: widget.selectMode ? '選擇順路門市' : '放學順路領'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _RoutePanel(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        color: TPColors.primary800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '放學順路領',
                          style: TPTextStyles.h3SemiBold.copyWith(
                            fontSize: 21,
                            color: TPColors.primary900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '把領奶，放進回家的路上。',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: TPColors.primary800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _schoolName == null ? '請先新增孩子的學校資料。' : '學校：$_schoolName',
                  ),
                  const SizedBox(height: 8),
                  const Text('搜尋並設定回家位置，系統會自動尋找附近的領奶門市。'),
                  TextButton.icon(
                    onPressed: _restoring || _saving ? null : _homeSearch,
                    icon: const Icon(Icons.search),
                    label: Text(_home == null ? '搜尋回家位置' : '修改回家位置'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RoutePanel(
                children: [
                  Text(
                    '放學行程',
                    style: TPTextStyles.h3SemiBold.copyWith(
                      fontSize: 18,
                      color: TPColors.primary900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 280,
                      child: FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: const LatLng(25.0375, 121.5645),
                          initialZoom: 14,
                          onMapReady: () {
                            _ready = true;
                            _fit();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.quentinchih.townpass.preview',
                          ),
                          if (_school != null && _home != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    _school!,
                                    if (_selected != null) _selected!.point,
                                    _home!,
                                  ],
                                  color: TPColors.primary600,
                                  strokeWidth: 3,
                                  pattern: const StrokePattern.dotted(),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_school != null)
                                _marker(
                                  _school!,
                                  Icons.school,
                                  '學校',
                                  TPColors.primary800,
                                ),
                              if (_home != null)
                                _marker(
                                  _home!,
                                  Icons.home,
                                  '回家位置',
                                  TPColors.orange700,
                                ),
                              for (final candidate in _candidates)
                                _marker(
                                  candidate.stop.point,
                                  Icons.storefront,
                                  candidate.stop.name,
                                  TPColors.primary600,
                                ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (route?.validationError != null)
                    Text(
                      route!.validationError!,
                      style: const TextStyle(color: TPColors.red700),
                    ),
                  const Text(
                    '虛線顯示學校與回家位置，實際路線可在選定門市後查看。',
                    style: TextStyle(
                      fontSize: 14,
                      color: TPColors.grayscale700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RoutePanel(
                children: [
                  FilledButton.icon(
                    key: const Key('milk-route-search'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TPColors.primary700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: valid && !_loading && !_restoring && !_saving
                        ? _search
                        : null,
                    icon: Icon(_loading ? Icons.hourglass_top : Icons.route),
                    label: Text(_loading ? '尋找門市中…' : '找順路門市'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: valid && !_saving ? _save : null,
                        icon: const Icon(Icons.bookmark_border),
                        label: const Text('只儲存在這台手機'),
                      ),
                      TextButton(
                        onPressed: _restoring || _saving ? null : _clear,
                        child: const Text('清除行程'),
                      ),
                    ],
                  ),
                  if (_notice != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _notice!,
                        style: const TextStyle(color: TPColors.primary800),
                      ),
                    ),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: TPColors.red700),
                    ),
                    TextButton(
                      onPressed: !_loading
                          ? (valid ? _search : _restore)
                          : null,
                      child: const Text('重新搜尋'),
                    ),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
              if (_searched && !_loading && _error == null) ...[
                const SizedBox(height: 20),
                Text(
                  _candidates.isEmpty
                      ? '這段行程找不到合適的門市。試著修改回家位置。'
                      : '依直線增加距離排序・${_candidates.length} 間',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('依順路程度排序，選好門市後可開啟地圖查看路線。'),
                for (final candidate in _candidates)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _storeCard(candidate),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, String label, Color color) =>
      Marker(
        point: point,
        width: 48,
        height: 48,
        child: Semantics(
          label: label,
          child: Tooltip(
            message: label,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
        ),
      );

  Widget _storeCard(MilkRouteCandidate candidate) {
    final stop = candidate.stop;
    final distance = candidate.extraMetres < 1000
        ? '${candidate.extraMetres.round()} 公尺'
        : '${(candidate.extraMetres / 1000).toStringAsFixed(1)} 公里';
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: identical(_selected, stop)
              ? TPColors.primary700
              : TPColors.grayscale200,
          width: identical(_selected, stop) ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stop.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(stop.address.isEmpty ? '地址未提供' : stop.address),
            const SizedBox(height: 8),
            Text(
              '直線增加約 $distance',
              style: const TextStyle(
                color: TPColors.primary800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.selectMode)
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, stop),
                icon: const Icon(Icons.check),
                label: const Text('選這間，一起去'),
              ),
            if (!widget.selectMode)
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _selected = stop;
                    _notice = '已選擇 ${stop.name}。出發前記得帶上實體卡證。';
                  });
                  _fit();
                },
                icon: Icon(
                  identical(_selected, stop)
                      ? Icons.check_circle
                      : Icons.add_location_alt_outlined,
                ),
                label: Text(identical(_selected, stop) ? '已選為順路門市' : '選這間順路領'),
              ),
            TextButton.icon(
              onPressed: () => _directions(stop),
              icon: const Icon(Icons.directions_walk),
              label: const Text('開啟地圖前往門市'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => TPCard(
    cornerRadius: 16,
    padding: const EdgeInsets.all(20),
    child: DefaultTextStyle.merge(
      style: TPTextStyles.h3Regular.copyWith(
        color: TPColors.grayscale800,
        height: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}
