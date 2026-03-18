import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/history_entry.dart';
import '../theme/app_theme.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('الإحصائيات', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ValueListenableBuilder<Box<HistoryEntry>>(
        valueListenable: Hive.box<HistoryEntry>('history').listenable(),
        builder: (context, box, child) {
          final entries = box.values.toList();
          
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد إحصائيات بعد',
                style: TextStyle(color: AppColors.textMuted, fontSize: 16),
              ),
            );
          }

          int totalDhikrs = 0;
          for (var e in entries) {
            totalDhikrs += e.count;
          }
          int targetReachedCount = entries.where((e) => e.targetReached).length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      _buildStatCard('إجمالي الأذكار', totalDhikrs.toString(), AppColors.emerald),
                      const SizedBox(width: AppSpacing.md),
                      _buildStatCard('أهداف مكتملة', targetReachedCount.toString(), AppColors.indigo),
                      const SizedBox(width: AppSpacing.md),
                      _buildStatCard('إجمالي الجلسات', entries.length.toString(), AppColors.rose),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Text(
                    'سجل النشاطات',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Show newest first
                    final entry = entries[entries.length - 1 - index];
                    final fmt = DateFormat('MMM d, HH:mm');
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: entry.targetReached
                            ? AppColors.emerald.withAlpha(40)
                            : AppColors.cardBackground,
                        child: Icon(
                          entry.targetReached ? Icons.check : Icons.loop,
                          color: entry.targetReached ? AppColors.emerald : AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        entry.dhikrName,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${entry.count} / ${entry.target}  •  ${fmt.format(entry.completedAt)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: entry.targetReached
                          ? const Text('✓', style: TextStyle(color: AppColors.emerald, fontSize: 16))
                          : null,
                    );
                  },
                  childCount: entries.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
             Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
