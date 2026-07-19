import 'package:drift/drift.dart';
import '../db/database.dart';
import 'api_client.dart';

class ProgressSyncResult {
  const ProgressSyncResult({
    required this.success,
    this.version,
    this.conflict,
    this.error,
  });

  final bool success;
  final int? version;
  final bool? conflict;
  final String? error;
}

class ProgressSyncService {
  ProgressSyncService({
    required ApiClient apiClient,
    required AppDatabase db,
  })  : _apiClient = apiClient,
        _db = db;

  final ApiClient _apiClient;
  final AppDatabase _db;

  /// Uploads local progress snapshot to backend (/v1/progress).
  Future<ProgressSyncResult> uploadProgress({int version = 1}) async {
    try {
      final userState = await _db.userState();
      final nodeProgressList = await _db.select(_db.nodeProgress).get();
      final reviewStatesList = await _db.select(_db.reviewStates).get();

      final payload = {
        'version': version,
        'clientUpdatedAt': DateTime.now().toUtc().toIso8601String(),
        'data': {
          'userState': {
            'hearts': userState.hearts,
            'xp': userState.xp,
            'level': userState.level,
            'streakCurrent': userState.streakCurrent,
            'streakLongest': userState.streakLongest,
            'streakFreezes': userState.streakFreezes,
            'lastActiveDay': userState.lastActiveDay?.toIso8601String(),
            'dailyGoalXp': userState.dailyGoalXp,
            'soundEnabled': userState.soundEnabled,
            'showHarakat': userState.showHarakat,
            'premium': userState.premium,
            'onboarded': userState.onboarded,
            'nickname': userState.nickname,
          },
          'nodeProgress': nodeProgressList
              .map((n) => {
                    'nodeId': n.nodeId,
                    'status': n.status,
                    'stars': n.stars,
                    'bestScore': n.bestScore,
                  },)
              .toList(),
          'reviewStates': reviewStatesList
              .map((r) => {
                    'itemKey': r.itemKey,
                    'itemType': r.itemType,
                    'stability': r.stability,
                    'difficulty': r.difficulty,
                    'due': r.due?.toIso8601String(),
                    'lastReview': r.lastReview?.toIso8601String(),
                    'reps': r.reps,
                    'lapses': r.lapses,
                    'phase': r.phase,
                  },)
              .toList(),
        },
      };

      final response = await _apiClient.put('/v1/progress', body: payload);

      if (response.isSuccess && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        return ProgressSyncResult(
          success: true,
          version: data['version'] as int?,
        );
      } else if (response.statusCode == 409) {
        return const ProgressSyncResult(
          success: false,
          conflict: true,
          error: 'version_conflict',
        );
      }

      return ProgressSyncResult(
        success: false,
        error: response.error ?? 'Unknown error',
      );
    } catch (e) {
      return ProgressSyncResult(success: false, error: e.toString());
    }
  }

  /// Downloads server snapshot (/v1/progress) and updates local database state.
  Future<bool> restoreProgress() async {
    try {
      final response = await _apiClient.get('/v1/progress');
      if (!response.isSuccess || response.data is! Map<String, dynamic>) {
        return false;
      }

      final data = response.data as Map<String, dynamic>;
      final snapshotData = data['data'];
      if (snapshotData is! Map<String, dynamic>) return false;

      // 1. Update UserState
      final us = snapshotData['userState'];
      if (us is Map<String, dynamic>) {
        await _db.updateUserState(
          UserStateTableCompanion(
            hearts: Value(us['hearts'] as int? ?? 5),
            xp: Value(us['xp'] as int? ?? 0),
            level: Value(us['level'] as int? ?? 1),
            streakCurrent: Value(us['streakCurrent'] as int? ?? 0),
            streakLongest: Value(us['streakLongest'] as int? ?? 0),
            streakFreezes: Value(us['streakFreezes'] as int? ?? 0),
            lastActiveDay: Value(us['lastActiveDay'] != null
                ? DateTime.tryParse(us['lastActiveDay'].toString())
                : null,),
            dailyGoalXp: Value(us['dailyGoalXp'] as int? ?? 30),
            soundEnabled: Value(us['soundEnabled'] as bool? ?? true),
            showHarakat: Value(us['showHarakat'] as bool? ?? true),
            premium: Value(us['premium'] as bool? ?? false),
            onboarded: Value(us['onboarded'] as bool? ?? true),
            nickname: Value(us['nickname'] as String?),
          ),
        );
      }

      // 2. Update NodeProgress
      final nodes = snapshotData['nodeProgress'];
      if (nodes is List) {
        for (final item in nodes) {
          if (item is Map<String, dynamic>) {
            final nodeId = item['nodeId'] as String?;
            if (nodeId == null) continue;
            await _db.into(_db.nodeProgress).insertOnConflictUpdate(
                  NodeProgressCompanion(
                    nodeId: Value(nodeId),
                    status: Value(item['status'] as String? ?? 'available'),
                    stars: Value(item['stars'] as int? ?? 0),
                    bestScore: Value(item['bestScore'] as int? ?? 0),
                  ),
                );
          }
        }
      }

      // 3. Update ReviewStates
      final reviews = snapshotData['reviewStates'];
      if (reviews is List) {
        for (final item in reviews) {
          if (item is Map<String, dynamic>) {
            final itemKey = item['itemKey'] as String?;
            if (itemKey == null) continue;
            await _db.into(_db.reviewStates).insertOnConflictUpdate(
                  ReviewStatesCompanion(
                    itemKey: Value(itemKey),
                    itemType: Value(item['itemType'] as String? ?? 'word'),
                    stability: Value((item['stability'] as num? ?? 0).toDouble()),
                    difficulty: Value((item['difficulty'] as num? ?? 0).toDouble()),
                    due: Value(item['due'] != null
                        ? DateTime.tryParse(item['due'].toString())
                        : null,),
                    lastReview: Value(item['lastReview'] != null
                        ? DateTime.tryParse(item['lastReview'].toString())
                        : null,),
                    reps: Value(item['reps'] as int? ?? 0),
                    lapses: Value(item['lapses'] as int? ?? 0),
                    phase: Value(item['phase'] as String? ?? 'newCard'),
                  ),
                );
          }
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
