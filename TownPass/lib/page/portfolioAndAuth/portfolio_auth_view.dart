import 'package:flutter/material.dart';
import 'package:town_pass/page/local_service/local_service_view.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';

class PortfolioAndAuthView extends StatelessWidget {
  const PortfolioAndAuthView({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: const TPAppBar(
        title: '歷程與授權管理',
        bottom: TabBar(
          labelColor: TPColors.primary700,
          indicatorColor: TPColors.primary700,
          tabs: [
            Tab(text: '使用紀錄'),
            Tab(text: '授權管理'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: LocalServiceStore.load(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('無法讀取使用紀錄，請稍後重新開啟。'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final records = snapshot.data!;
              if (records.isEmpty) {
                return const Center(child: Text('使用服務後，紀錄會顯示在這裡。'));
              }
              return ListView(
                children: [
                  for (final record in records)
                    ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: TPColors.primary700,
                      ),
                      title: Text('${record['service']}'),
                      subtitle: Text(
                        '${record['choice']}\n${record['savedAt'].toString().substring(0, 10)}',
                      ),
                    ),
                ],
              );
            },
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('目前沒有第三方授權。你授權的服務會顯示在這裡。'),
            ),
          ),
        ],
      ),
    ),
  );
}
