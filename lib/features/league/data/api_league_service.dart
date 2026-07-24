import '../../../core/network/api_client.dart';
import '../domain/league_logic.dart';
import 'league_service.dart';

class ApiLeagueService implements LeagueService {
  ApiLeagueService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<LeagueSnapshot?> currentSnapshot() async {
    final response = await _apiClient.get('/v1/leagues/current');
    if (!response.isSuccess || response.data is! Map<String, dynamic>) {
      return null;
    }

    final data = response.data as Map<String, dynamic>;
    final tierStr = (data['tier'] as String? ?? 'bronze').toLowerCase();
    final tier = LeagueTier.values.firstWhere(
      (t) => t.name.toLowerCase() == tierStr,
      orElse: () => LeagueTier.bronze,
    );

    final standingsList = (data['standings'] as List? ?? []);
    final standings = standingsList.map((item) {
      final map = item as Map<String, dynamic>;
      return LeagueStanding(
        rank: map['rank'] as int? ?? 0,
        nickname: map['nickname'] as String? ?? 'Oyuncu',
        weeklyXp: map['weeklyXp'] as int? ?? 0,
        isMe: map['isMe'] as bool? ?? false,
      );
    }).toList();

    return LeagueSnapshot(
      tier: tier,
      weekId: data['weekId'] as String? ?? '',
      weekEnd: DateTime.tryParse(data['weekEnd'] as String? ?? '') ?? DateTime.now(),
      standings: standings,
      promoteCount: data['promoteCount'] as int? ?? 5,
      relegateCount: data['relegateCount'] as int? ?? 5,
    );
  }

  @override
  Future<void> submitWeeklyXp(int weeklyXp) async {
    // Server-authoritative design: XP is calculated on the server per completed lesson.
  }

  @override
  Future<LeagueLastResult?> lastResult() async {
    final response = await _apiClient.get('/v1/leagues/last-result');
    if (!response.isSuccess || response.data is! Map<String, dynamic>) {
      return null;
    }

    final data = response.data as Map<String, dynamic>;
    final tierStr = (data['tier'] as String? ?? 'bronze').toLowerCase();
    final tier = LeagueTier.values.firstWhere(
      (t) => t.name.toLowerCase() == tierStr,
      orElse: () => LeagueTier.bronze,
    );

    final nextTierStr = (data['nextTier'] as String? ?? 'bronze').toLowerCase();
    final nextTier = LeagueTier.values.firstWhere(
      (t) => t.name.toLowerCase() == nextTierStr,
      orElse: () => LeagueTier.bronze,
    );

    final outcomeStr = (data['outcome'] as String? ?? 'stayed').toLowerCase();
    final outcome = LeagueOutcome.values.firstWhere(
      (o) => o.name.toLowerCase() == outcomeStr,
      orElse: () => LeagueOutcome.stayed,
    );

    return LeagueLastResult(
      weekId: data['weekId'] as String? ?? '',
      tier: tier,
      finalRank: data['finalRank'] as int? ?? 1,
      outcome: outcome,
      nextTier: nextTier,
    );
  }

  /// Sends a verified lesson completion to award server-calculated XP to the user's weekly cohort.
  Future<int?> completeLesson({
    required String nodeId,
    required int totalExercises,
    required int correctFirstTry,
    required int totalWrong,
    required int maxCombo,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      '/v1/lessons/complete',
      idempotencyKey: idempotencyKey,
      body: {
        'nodeId': nodeId,
        'totalExercises': totalExercises,
        'correctFirstTry': correctFirstTry,
        'totalWrong': totalWrong,
        'maxCombo': maxCombo,
      },
    );

    if (response.isSuccess && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      return data['earnedXp'] as int?;
    }
    return null;
  }
}
