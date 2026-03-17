import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/history_entry.dart';
import '../providers/counter_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/counter_ring.dart';

/// The main counting screen for a single Dhikr session.
///
/// Observes [CounterProvider] for state and exposes three FABs:
///   - Microphone toggle (voice recognition)
///   - Manual reset
///   - Progress history drawer
///
/// Implements [WidgetsBindingObserver] to stop the mic when the app
/// is backgrounded, satisfying the battery optimization requirement.
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Force-stop mic on screen dispose — battery optimization
    context.read<CounterProvider>().forceStopMicrophone();
    super.dispose();
  }

  /// Battery optimization: stop mic when app goes to background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<CounterProvider>().forceStopMicrophone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();
    final dhikr = provider.dhikr;
    final gradient = AppColors.cardGradients[dhikr.gradientIndex];
    final progress = provider.target > 0
        ? (provider.count / provider.target).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Hero(
          tag: 'dhikr_card_${dhikr.id}',
          flightShuttleBuilder: (_, __, ___, ____, _____) =>
              const SizedBox.shrink(),
          child: Text(
            dhikr.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Ambient gradient background
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    gradient.first.withAlpha(60),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _buildBody(context, provider, progress, gradient),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFabRow(context, provider),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CounterProvider provider,
    double progress,
    List<Color> gradient,
  ) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.xl),
            // Arabic text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                provider.dhikr.arabicText,
                style: const TextStyle(
                  fontSize: 36,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          // Counter ring
          GestureDetector(
            onTap: provider.increment,
            child: CounterRing(
              progress: progress,
              pulseTrigger: provider.pulseTrigger,
              child: _buildCounterText(context, provider),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Target indicator
          _buildTargetChip(context, provider),
          const Spacer(),
          // Completion banner
          if (provider.targetReached) _buildCompletionBanner(context, gradient),
          const SizedBox(height: 90),
        ],
      ),
      ),
    );
  }

  Widget _buildCounterText(BuildContext context, CounterProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '${provider.count}',
            key: ValueKey(provider.count),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 72,
                  letterSpacing: -2,
                ),
          ),
        ),
        Text(
          'من ${provider.target}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetChip(BuildContext context, CounterProvider provider) {
    return GestureDetector(
      onTap: () => _showTargetDialog(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'الهدف: ${provider.target}  •  اضغط للعد',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionBanner(
      BuildContext context, List<Color> gradient) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withAlpha(76),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'تم الوصول للهدف! ما شاء الله 🌟',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabRow(BuildContext context, CounterProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // History FAB
          _fab(
            icon: Icons.bar_chart_rounded,
            tooltip: 'السجل',
            color: AppColors.indigo,
            onTap: () => _showHistory(context, provider),
          ),
          // Mic FAB (primary — larger)
          GestureDetector(
            onTap: provider.toggleMicrophone,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: provider.micActive
                      ? [const Color(0xFFE74C3C), const Color(0xFFCC2B5E)]
                      : [const Color(0xFF2ECC71), const Color(0xFF1ABC9C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (provider.micActive
                            ? const Color(0xFFE74C3C)
                            : AppColors.emerald)
                        .withAlpha(102),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                provider.micActive ? Icons.mic : Icons.mic_off_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          // Reset FAB
          _fab(
            icon: Icons.refresh_rounded,
            tooltip: 'تصفير',
            color: AppColors.rose,
            onTap: () => _confirmReset(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _fab({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardBackground,
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(51),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showTargetDialog(BuildContext context, CounterProvider provider) {
    final controller =
        TextEditingController(text: provider.target.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('تحديد الهدف',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 22),
          decoration: const InputDecoration(
            hintText: 'مثال: ٣٣ أو ٩٩',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.emerald),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) provider.setTarget(val);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('تصفير العداد',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('هل أنت متأكد من تصفير العداد الحالي؟',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              provider.reset();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('تصفير'),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, CounterProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'سجل النشاط',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: provider.history.isEmpty
                  ? const Center(
                      child: Text('لا يوجد سجل بعد',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      itemCount: provider.history.length,
                      separatorBuilder: (_, __) => const Divider(
                          color: AppColors.cardBorder, height: 1),
                      itemBuilder: (_, i) =>
                          _historyTile(provider.history[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(HistoryEntry entry) {
    final fmt = DateFormat('MMM d, HH:mm');
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
        '${entry.count} / ${entry.target}',
        style: const TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        fmt.format(entry.completedAt),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: entry.targetReached
          ? const Text('✓', style: TextStyle(color: AppColors.emerald, fontSize: 16))
          : null,
    );
  }
}
