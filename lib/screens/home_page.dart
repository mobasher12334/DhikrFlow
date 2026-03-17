import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/dhikr_model.dart';
import '../models/custom_dhikr.dart';
import '../providers/counter_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dhikr_card.dart';
import 'counter_page.dart';
import 'stats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box<CustomDhikr> customBox;

  @override
  void initState() {
    super.initState();
    customBox = Hive.box<CustomDhikr>('custom_dhikrs');
    customBox.listenable().addListener(_onBoxChange);
  }

  @override
  void dispose() {
    customBox.listenable().removeListener(_onBoxChange);
    super.dispose();
  }

  void _onBoxChange() {
    setState(() {});
  }

  List<DhikrModel> _getDhikrs() {
    final all = List<DhikrModel>.from(DhikrPresets.all.where((d) => d.id != 'custom'));
    final customList = customBox.values.map((c) => c.toDhikrModel()).toList();
    all.addAll(customList);
    // Overwrite the original Custom model to act as an "Add" button
    all.add(DhikrPresets.custom.copyWith(arabicText: '+', name: 'إضافة ذكر جديد')); 
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          _buildGrid(context),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded, color: AppColors.textPrimary),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsPage()));
          },
          tooltip: 'الإحصائيات',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(right: 24, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السبحة الإلكترونية',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
            ),
            Text(
              'ألا بذكر الله تطمئن القلوب',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D1B2E), AppColors.darkBackground],
                ),
              ),
            ),
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x3011998E), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final dhikrmodels = _getDhikrs();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final dhikr = dhikrmodels[index];
            return DhikrCard(
              dhikr: dhikr,
              onTap: () {
                if (dhikr.id == 'custom' && dhikr.arabicText == '+') {
                  _addCustomDhikr();
                } else {
                  _openCounter(context, dhikr);
                }
              },
            );
          },
          childCount: dhikrmodels.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.9,
        ),
      ),
    );
  }

  void _addCustomDhikr() {
    final targetCtrl = TextEditingController(text: '100');
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('إضافة ذكر مخصص', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'نص الذكر',
                labelStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.emerald)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'الهدف',
                labelStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.emerald)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final target = int.tryParse(targetCtrl.text) ?? 100;
              final txt = nameCtrl.text.trim();
              if (txt.isNotEmpty) {
                final cd = CustomDhikr(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  arabicText: txt,
                  target: target,
                );
                customBox.add(cd);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _openCounter(BuildContext context, DhikrModel dhikr) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => ChangeNotifierProvider(
          create: (_) => CounterProvider(dhikr),
          child: const CounterPage(),
        ),
        transitionsBuilder: (ctx, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}
