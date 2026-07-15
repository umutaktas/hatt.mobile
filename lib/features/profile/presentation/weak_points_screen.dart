import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ottoman_text.dart';
import '../data/weak_points_repository.dart';

final weakPointsRepositoryProvider = Provider<WeakPointsRepository>(
  (ref) => WeakPointsRepository(ref.watch(databaseProvider)),
);

final weakestItemsProvider = FutureProvider.autoDispose<List<WeakPoint>>(
  (ref) => ref.watch(weakPointsRepositoryProvider).weakestItems(),
);

final exerciseStatsProvider =
    FutureProvider.autoDispose<List<ExerciseTypeStat>>(
  (ref) => ref.watch(weakPointsRepositoryProvider).exerciseTypeStats(),
);

/// Premium weak-point report (CLAUDE.md §6): the most-lapsed letters/words and
/// accuracy per exercise type, from local FSRS state + exercise log.
class WeakPointsScreen extends ConsumerWidget {
  const WeakPointsScreen({super.key});

  static const _typeNames = {
    'chooseMeaning': 'Anlam seçme',
    'chooseOttoman': 'Osmanlıca seçme',
    'distinguishLetter': 'Benzer harf ayrımı',
    'typeTransliteration': 'Transliterasyon yazma',
    'matchPairs': 'Eşleştirme',
    'readLine': 'Satır okuma',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(weakestItemsProvider);
    final stats = ref.watch(exerciseStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Zayıf Nokta Analizi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('En çok zorlandıkların',
              style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(height: 8),
          items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Hata: $e'),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Henüz yeterli veri yok. Birkaç ders tamamladıkça '
                      'zorlandığın harf ve kelimeler burada görünecek.',
                    ),
                  )
                : Column(
                    children: [for (final w in list) _WeakPointTile(w: w)],
                  ),
          ),
          const SizedBox(height: 24),
          Text('Egzersiz tipine göre doğruluk',
              style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(height: 8),
          stats.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Hata: $e'),
            data: (list) => Column(
              children: [
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 170,
                          child: Text(
                            _typeNames[s.exerciseType] ?? s.exerciseType,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: s.accuracy,
                              minHeight: 10,
                              backgroundColor:
                                  AppColors.locked.withValues(alpha: 0.25),
                              valueColor: AlwaysStoppedAnimation(
                                s.accuracy >= 0.8
                                    ? AppColors.success
                                    : s.accuracy >= 0.5
                                        ? AppColors.gold
                                        : AppColors.error,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('%${(s.accuracy * 100).round()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,),),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakPointTile extends StatelessWidget {
  const _WeakPointTile({required this.w});
  final WeakPoint w;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),),
                  Text('${w.lapses} hata / ${w.reps} tekrar',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.error),),
                ],
              ),
            ),
            OttomanText(w.ottoman, size: OttomanTextSize.standard),
          ],
        ),
      ),
    );
  }
}
