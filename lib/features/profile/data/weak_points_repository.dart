import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// One struggling item on the weak-point report (premium, CLAUDE.md §6).
class WeakPoint {
  const WeakPoint({
    required this.itemKey,
    required this.ottoman,
    required this.label,
    required this.lapses,
    required this.reps,
    required this.difficulty,
  });

  final String itemKey;
  final String ottoman;

  /// Turkish gloss (word meaning or letter name).
  final String label;
  final int lapses;
  final int reps;
  final double difficulty;

  double get errorRate => reps == 0 ? 0 : (lapses / reps).clamp(0, 1);
}

/// Accuracy per exercise kind, from the exercise log.
class ExerciseTypeStat {
  const ExerciseTypeStat({
    required this.exerciseType,
    required this.total,
    required this.correct,
  });

  final String exerciseType;
  final int total;
  final int correct;

  double get accuracy => total == 0 ? 0 : correct / total;
}

class WeakPointsRepository {
  WeakPointsRepository(this.db);

  final AppDatabase db;

  /// The most-lapsed items, hardest first.
  Future<List<WeakPoint>> weakestItems({int limit = 15}) async {
    final rows = await (db.select(db.reviewStates)
          ..where((t) => t.lapses.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm.desc(t.lapses),
            (t) => OrderingTerm.desc(t.difficulty),
          ])
          ..limit(limit))
        .get();

    final result = <WeakPoint>[];
    for (final row in rows) {
      final parts = row.itemKey.split(':');
      if (parts.length != 2) continue;
      final id = parts[1];
      String? ottoman;
      String? label;
      if (parts[0] == 'word') {
        final w = await (db.select(db.words)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        ottoman = w?.ottoman;
        label = w?.meaningTr;
      } else {
        final l = await (db.select(db.letters)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        ottoman = l?.isolated;
        label = l?.name;
      }
      if (ottoman == null || label == null) continue;
      result.add(WeakPoint(
        itemKey: row.itemKey,
        ottoman: ottoman,
        label: label,
        lapses: row.lapses,
        reps: row.reps,
        difficulty: row.difficulty,
      ),);
    }
    return result;
  }

  /// Accuracy grouped by exercise type.
  Future<List<ExerciseTypeStat>> exerciseTypeStats() async {
    final type = db.exerciseLog.exerciseType;
    final total = db.exerciseLog.id.count();
    final correct = db.exerciseLog.id.count(
      filter: db.exerciseLog.correct.equals(true),
    );
    final query = db.selectOnly(db.exerciseLog)
      ..addColumns([type, total, correct])
      ..groupBy([type])
      ..orderBy([OrderingTerm.asc(total)]);

    final rows = await query.get();
    return rows
        .map(
          (r) => ExerciseTypeStat(
            exerciseType: r.read(type)!,
            total: r.read(total) ?? 0,
            correct: r.read(correct) ?? 0,
          ),
        )
        .toList();
  }
}
