import 'package:flutter/material.dart';
import 'package:town_pass/page/city_service/milk_route_view.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// The route action shares the outing card's visual language in the trip tab.
class MilkRouteEntryCard extends StatelessWidget {
  const MilkRouteEntryCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: TPColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TPColors.grayscale200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_outlined, color: TPColors.primary800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '放學順路領',
                style: TPTextStyles.h3SemiBold.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: TPColors.primary900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '把領奶，放進回家的路上。',
          style: TPTextStyles.h3SemiBold.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          '設定回家位置，自動尋找放學順路的門市。行程儲存在這台手機。',
          style: TPTextStyles.h3Regular,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: TPColors.primary700,
              foregroundColor: TPColors.white,
              minimumSize: const Size.fromHeight(56),
              textStyle: TPTextStyles.h3SemiBold,
            ),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const MilkRouteView()),
            ),
            icon: const Icon(Icons.route_outlined),
            label: const Text('找順路門市'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '帶上實體卡證，出發前確認門市營業時間。',
          style: TPTextStyles.caption.copyWith(color: TPColors.grayscale700),
        ),
      ],
    ),
  );
}
