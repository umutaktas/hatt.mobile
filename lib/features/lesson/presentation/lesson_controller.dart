import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/gamification/lesson_result.dart';
import '../../../core/gamification/xp_calculator.dart';
import '../../../core/providers/app_providers.dart';
import '../../path/data/path_models.dart';
import '../../path/data/path_repository.dart';
import '../../profile/data/user_repository.dart';
import '../../review/data/review_repository.dart';
import '../../league/data/api_league_service.dart';
import '../data/lesson_repository.dart';
import '../domain/exercise.dart';

enum LessonPhase { loading, answering, feedback, outOfHearts, finished, empty }

class LessonSummary {
  const LessonSummary({
    required this.xp,
    required this.leveledUp,
    required this.newLevel,
    required this.streak,
    required this.stars,
    required this.result,
  });

  final int xp;
  final bool leveledUp;
  final int newLevel;
  final int streak;
  final int stars;
  final LessonResult result;
}

class LessonState {
  const LessonState({
    this.phase = LessonPhase.loading,
    this.exercises = const [],
    this.index = 0,
    this.hearts = 5,
    this.unlimitedHearts = false,
    this.lastCorrect,
    this.correctFirstTry = 0,
    this.wrong = 0,
    this.combo = 0,
    this.longestCombo = 0,
    this.summary,
  });

  final LessonPhase phase;
  final List<Exercise> exercises;
  final int index;
  final int hearts;
  final bool unlimitedHearts;
  final bool? lastCorrect;
  final int correctFirstTry;
  final int wrong;
  final int combo;
  final int longestCombo;
  final LessonSummary? summary;

  Exercise? get current =>
      index >= 0 && index < exercises.length ? exercises[index] : null;

  double get progress =>
      exercises.isEmpty ? 0 : (index / exercises.length).clamp(0, 1);

  LessonState copyWith({
    LessonPhase? phase,
    List<Exercise>? exercises,
    int? index,
    int? hearts,
    bool? unlimitedHearts,
    Object? lastCorrect = _sentinel,
    int? correctFirstTry,
    int? wrong,
    int? combo,
    int? longestCombo,
    LessonSummary? summary,
  }) {
    return LessonState(
      phase: phase ?? this.phase,
      exercises: exercises ?? this.exercises,
      index: index ?? this.index,
      hearts: hearts ?? this.hearts,
      unlimitedHearts: unlimitedHearts ?? this.unlimitedHearts,
      lastCorrect:
          identical(lastCorrect, _sentinel) ? this.lastCorrect : lastCorrect as bool?,
      correctFirstTry: correctFirstTry ?? this.correctFirstTry,
      wrong: wrong ?? this.wrong,
      combo: combo ?? this.combo,
      longestCombo: longestCombo ?? this.longestCombo,
      summary: summary ?? this.summary,
    );
  }

  static const _sentinel = Object();
}

class LessonController extends StateNotifier<LessonState> {
  LessonController(this._ref, this.node) : super(const LessonState()) {
    _init();
  }

  final Ref _ref;
  final PathNode node;

  /// Synthetic node id for hearts-earning practice sessions launched from the
  /// out-of-hearts screen; it has no curriculum row, so path progress is skipped.
  static const practiceNodeId = '_practice';

  bool _currentHadError = false;

  /// Prevents double-grading while the async side effects of [grade] run
  /// (double-tap on "Kontrol Et" would otherwise spend two hearts).
  bool _grading = false;

  /// Exercises re-queued by the error queue; answering them correctly later
  /// must not count as a first-try success.
  final Set<Exercise> _requeued = Set.identity();

  LessonRepository get _lessons => LessonRepository(
        _ref.read(databaseProvider),
        ReviewRepository(_ref.read(databaseProvider)),
      );
  ReviewRepository get _reviews => ReviewRepository(_ref.read(databaseProvider));
  UserRepository get _users => UserRepository(_ref.read(databaseProvider));
  PathRepository get _paths => PathRepository(_ref.read(databaseProvider));
  SoundService get _sound => _ref.read(soundServiceProvider);

  DateTime get _now => DateTime.now();

  Future<void> _init() async {
    final userRow = await _users.current();
    final heartsState = await _users.regenHearts(_now);

    // A lesson cannot be started without hearts; review/practice can — it is
    // how hearts are earned back (§4.3).
    if (node.type != NodeType.review &&
        !userRow.premium &&
        heartsState.current <= 0) {
      state = state.copyWith(
        phase: LessonPhase.outOfHearts,
        hearts: heartsState.current,
      );
      return;
    }

    final exercises = await _lessons.buildForNode(node, rng: Random(), now: _now);
    if (exercises.isEmpty) {
      state = state.copyWith(phase: LessonPhase.empty);
      return;
    }
    state = state.copyWith(
      phase: LessonPhase.answering,
      exercises: exercises,
      hearts: heartsState.current,
      unlimitedHearts: userRow.premium,
    );
    _ref.read(telemetryServiceProvider).trackEvent('lesson_started', {'node_id': node.id});
  }

  /// Grades the current exercise. [reviewKeys] are the FSRS items it exercised.
  Future<void> grade(bool correct, List<String> reviewKeys) async {
    if (state.phase != LessonPhase.answering || _grading) return;
    final ex = state.current;
    if (ex == null) return;
    _grading = true;

    try {
      await _lessons.logAnswer(
          nodeId: node.id, kind: ex.kind, correct: correct, now: _now,);
      for (final key in reviewKeys) {
        await _reviews.recordAnswer(key, correct: correct, now: _now);
      }

      if (correct) {
        final combo = state.combo + 1;
        await _sound.play(Sfx.correct);
        final firstTry = !_currentHadError && !_requeued.contains(ex);
        state = state.copyWith(
          phase: LessonPhase.feedback,
          lastCorrect: true,
          combo: combo,
          longestCombo: max(state.longestCombo, combo),
          correctFirstTry:
              firstTry ? state.correctFirstTry + 1 : state.correctFirstTry,
        );
      } else {
        _currentHadError = true;
        await _sound.play(Sfx.wrong);
        var hearts = state.hearts;
        if (!state.unlimitedHearts) {
          final next = await _users.spendHeart(_now);
          hearts = next.current;
        }
        state = state.copyWith(
          phase: LessonPhase.feedback,
          lastCorrect: false,
          combo: 0,
          wrong: state.wrong + 1,
          hearts: hearts,
        );
      }
    } finally {
      _grading = false;
    }
  }

  /// Penalizes a wrong pair selection inside a match exercise: costs a heart,
  /// logs the mistake and schedules the item as "again" in FSRS — without
  /// leaving the answering phase, so the learner keeps matching (§4.2.5).
  Future<void> penalizeMatchMistake(String reviewKey) async {
    if (state.phase != LessonPhase.answering || _grading) return;
    _grading = true;
    try {
      _currentHadError = true;
      await _lessons.logAnswer(
          nodeId: node.id,
          kind: ExerciseKind.matchPairs,
          correct: false,
          now: _now,);
      if (reviewKey.isNotEmpty) {
        await _reviews.recordAnswer(reviewKey, correct: false, now: _now);
      }
      await _sound.play(Sfx.wrong);
      var hearts = state.hearts;
      if (!state.unlimitedHearts) {
        final next = await _users.spendHeart(_now);
        hearts = next.current;
      }
      state = state.copyWith(
        combo: 0,
        wrong: state.wrong + 1,
        hearts: hearts,
        phase: !state.unlimitedHearts && hearts <= 0
            ? LessonPhase.outOfHearts
            : state.phase,
      );
    } finally {
      _grading = false;
    }
  }

  Future<void> advance() async {
    if (state.phase != LessonPhase.feedback) return;
    if (!state.unlimitedHearts && state.hearts <= 0) {
      state = state.copyWith(phase: LessonPhase.outOfHearts);
      return;
    }

    // Error queue: a wrongly answered exercise is re-asked at the end of the
    // lesson until it is answered correctly (Duolingo behaviour).
    var exercises = state.exercises;
    final current = state.current;
    if (state.lastCorrect == false && current != null) {
      _requeued.add(current);
      exercises = [...exercises, current];
    }

    final nextIndex = state.index + 1;
    if (nextIndex >= exercises.length) {
      await _finish();
      return;
    }
    _currentHadError = false;
    state = state.copyWith(
      exercises: exercises,
      index: nextIndex,
      phase: LessonPhase.answering,
      lastCorrect: null,
    );
  }

  Future<void> _finish() async {
    final result = LessonResult(
      totalExercises: state.exercises.length,
      correctFirstTry: state.correctFirstTry,
      wrongAnswers: state.wrong,
      longestCombo: state.longestCombo,
    );
    final premium = state.unlimitedHearts;
    final xp = const XpCalculator().compute(result, multiplier: premium ? 1.2 : 1.0);
    final stars = result.isFlawless ? 3 : (state.wrong <= 2 ? 2 : 1);

    final outcome = await _users.applyCompletion(xpGained: xp, now: _now);
    // Synthetic practice sessions have no curriculum row to complete/unlock.
    if (node.id != practiceNodeId) {
      await _paths.completeNode(node.id,
          stars: stars, score: state.correctFirstTry,);
    }

    // Review/practice lessons restore hearts (§4.3: "pratik yaparak kazan").
    if (node.type == NodeType.review) {
      await _users.refillHearts();
    }

    if (outcome.leveledUp) {
      await _sound.play(Sfx.levelUp);
    } else {
      await _sound.play(Sfx.lessonComplete);
    }

    // Today's activity is registered — push the streak reminder to tomorrow.
    final flags = _ref.read(featureFlagsProvider);
    if (flags.localNotificationsEnabled) {
      await _ref
          .read(streakReminderProvider)
          .reschedule(await _users.current(), now: _now);
    }

    // Server-verified league XP & cloud progress backup (CLAUDE.md §2, docs/ANALIZ-BACKEND-2026-07-16.md)
    if (flags.backendEnabled && node.id != practiceNodeId) {
      try {
        final leagueService = _ref.read(leagueServiceProvider);
        if (leagueService is ApiLeagueService) {
          final idempotencyKey =
              'complete_${node.id}_${_now.millisecondsSinceEpoch}';
          await leagueService.completeLesson(
            nodeId: node.id,
            totalExercises: state.exercises.length,
            correctFirstTry: state.correctFirstTry,
            totalWrong: state.wrong,
            maxCombo: state.longestCombo,
            idempotencyKey: idempotencyKey,
          );
        }

        if (flags.cloudBackupEnabled) {
          // Fire-and-forget background backup sync
          _ref.read(progressSyncServiceProvider).uploadProgress();
        }
      } catch (_) {}
    }

    _ref.read(telemetryServiceProvider).trackEvent('lesson_completed', {
      'node_id': node.id,
      'xp': '$xp',
      'stars': '$stars',
    });

    state = state.copyWith(
      phase: LessonPhase.finished,
      summary: LessonSummary(
        xp: xp,
        leveledUp: outcome.leveledUp,
        newLevel: outcome.newLevel,
        streak: outcome.streak,
        stars: stars,
        result: result,
      ),
    );
  }
}

/// Synthetic review node for hearts-earning practice sessions (§4.3: "pratik
/// yaparak kazan"). Content comes from the FSRS due queue like any review.
const practiceNode = PathNode(
  id: LessonController.practiceNodeId,
  type: NodeType.review,
  title: 'Pratik',
  contentRefs: [],
  status: NodeStatus.available,
  stars: 0,
  ordinal: -1,
);

final lessonControllerProvider = StateNotifierProvider.autoDispose
    .family<LessonController, LessonState, PathNode>(
  (ref, node) => LessonController(ref, node),
);
