import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mascot/mascot_state.dart';
import '../../../core/mascot/mascot_view.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/league_service.dart';
import '../domain/league_logic.dart';

final leagueSnapshotProvider = FutureProvider<LeagueSnapshot?>(
  (ref) => ref.watch(leagueServiceProvider).currentSnapshot(),
);

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> {
  bool _checkedRollover = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRollover();
    });
  }

  Future<void> _checkRollover() async {
    if (_checkedRollover || !mounted) return;
    _checkedRollover = true;

    try {
      final lastResult = await ref.read(leagueServiceProvider).lastResult();
      if (lastResult == null || !mounted) return;

      final prefs = ref.read(sharedPreferencesProvider);
      final lastSeenWeek = prefs.getString('last_seen_week_rollover');
      if (lastSeenWeek == lastResult.weekId) {
        return; // Already seen this rollover result
      }

      // Mark as seen
      await prefs.setString('last_seen_week_rollover', lastResult.weekId);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => _LeagueRolloverDialog(result: lastResult),
        );
      }
    } catch (_) {
      // Fail silently if backend is unreachable or offline
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final flags = ref.watch(featureFlagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.leagueTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: !flags.backendEnabled
          ? _OfflineState(l10n: l10n)
          : ref.watch(leagueSnapshotProvider).when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (_, __) => _OfflineState(l10n: l10n),
                data: (snap) => snap == null
                    ? _OfflineState(l10n: l10n)
                    : _Standings(snapshot: snap),
              ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MascotView(state: MascotState.sleeping, size: 130),
            const SizedBox(height: 24),
            Text(
              l10n.leagueOffline,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.leagueOfflineBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueCountdown extends StatefulWidget {
  const _LeagueCountdown({required this.weekEnd});
  final DateTime weekEnd;

  @override
  State<_LeagueCountdown> createState() => _LeagueCountdownState();
}

class _LeagueCountdownState extends State<_LeagueCountdown> {
  late Timer _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _calculateTimeLeft();
        });
      }
    });
  }

  void _calculateTimeLeft() {
    _timeLeft = widget.weekEnd.difference(DateTime.now());
    if (_timeLeft.isNegative) {
      _timeLeft = Duration.zero;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) {
      return const Text(
        'Lig sona erdi! Sonuçlar hesaplanıyor...',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours.remainder(24);
    final minutes = _timeLeft.inMinutes.remainder(60);
    final seconds = _timeLeft.inSeconds.remainder(60);

    final String text;
    if (days > 0) {
      text = '$days gün $hours saat kaldı';
    } else {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      text = '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)} kaldı';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Standings extends StatelessWidget {
  const _Standings({required this.snapshot});
  final LeagueSnapshot snapshot;

  List<Color> _getTierGradient(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => [const Color(0xFF8C583C), const Color(0xFFB37350)],
      LeagueTier.silver => [const Color(0xFF8fa3ad), const Color(0xFFb5c5cc)],
      LeagueTier.gold => [const Color(0xFFB8892B), const Color(0xFFD8B15A)],
      LeagueTier.platinum => [const Color(0xFF1E524D), const Color(0xFF2E7D74)],
      LeagueTier.diamond => [const Color(0xFF382361), const Color(0xFF5B3F9C)],
    };
  }

  @override
  Widget build(BuildContext context) {
    final myStanding = snapshot.standings.firstWhere(
      (s) => s.isMe,
      orElse: () => const LeagueStanding(
        rank: 99,
        nickname: 'Siz',
        weeklyXp: 0,
        isMe: true,
      ),
    );

    final rank = myStanding.rank;
    final inPromoteZone = rank <= snapshot.promoteCount;
    final inRelegateZone = rank > snapshot.standings.length - snapshot.relegateCount;

    final mascotState = inPromoteZone
        ? MascotState.celebrating
        : (inRelegateZone ? MascotState.sad : MascotState.normal);

    return Column(
      children: [
        // Premium Tier Header Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getTierGradient(snapshot.tier),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.tier.trName.toUpperCase()} LİGİ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _LeagueCountdown(weekEnd: snapshot.weekEnd),
                    const SizedBox(height: 12),
                    Text(
                      inPromoteZone
                          ? 'Harika gidiyorsun! Terfi bölgesindesin.'
                          : (inRelegateZone
                              ? 'Düşme hattındasın! Birkaç alıştırma yap.'
                              : 'Güvenli bölgedesin. Sıralamanı koru!'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MascotView(state: mascotState, size: 90),
            ],
          ),
        ),

        // Standings List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: snapshot.standings.length,
            itemBuilder: (context, i) {
              final s = snapshot.standings[i];
              final isTop3 = s.rank <= 3;
              final isPromoting = s.rank <= snapshot.promoteCount;
              final isRelegating =
                  s.rank > snapshot.standings.length - snapshot.relegateCount;

              final Color rankBgColor;
              final Color rankTextColor;

              if (isTop3) {
                rankBgColor = s.rank == 1
                    ? const Color(0xFFFFD700) // Gold
                    : (s.rank == 2
                        ? const Color(0xFFC0C0C0) // Silver
                        : const Color(0xFFCD7F32)); // Bronze
                rankTextColor = Colors.black87;
              } else if (isPromoting) {
                rankBgColor = AppColors.success.withValues(alpha: 0.15);
                rankTextColor = AppColors.success;
              } else if (isRelegating) {
                rankBgColor = AppColors.error.withValues(alpha: 0.15);
                rankTextColor = AppColors.error;
              } else {
                rankBgColor = Colors.grey.shade100;
                rankTextColor = Colors.grey.shade700;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: s.isMe ? AppColors.parchment : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: s.isMe
                        ? AppColors.gold
                        : Colors.grey.shade200,
                    width: s.isMe ? 2.0 : 1.0,
                  ),
                  boxShadow: s.isMe
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: SizedBox(
                    width: 42,
                    height: 42,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rankBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: isTop3
                          ? Icon(
                              Icons.emoji_events,
                              color: s.rank == 1
                                  ? const Color(0xFF996515) // Deep Gold
                                  : (s.rank == 2
                                      ? const Color(0xFF6B7280) // Dark Grey
                                      : const Color(0xFF78350F)), // Dark Bronze
                              size: 20,
                            )
                          : Text(
                              '${s.rank}',
                              style: TextStyle(
                                color: rankTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        s.nickname,
                        style: TextStyle(
                          fontWeight:
                              s.isMe ? FontWeight.bold : FontWeight.w600,
                          color: s.isMe ? AppColors.ink : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      if (s.isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Siz',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${s.weeklyXp}',
                        style: TextStyle(
                          fontWeight:
                              s.isMe ? FontWeight.bold : FontWeight.bold,
                          color: s.isMe ? AppColors.gold : Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'XP',
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeagueRolloverDialog extends StatelessWidget {
  const _LeagueRolloverDialog({required this.result});
  final LeagueLastResult result;

  @override
  Widget build(BuildContext context) {
    final title = result.outcome == LeagueOutcome.promoted
        ? 'Tebrikler! 🎉'
        : (result.outcome == LeagueOutcome.relegated
            ? 'Küme Düştün 😢'
            : 'Ligi Tamamladın! 👏');

    final description = result.outcome == LeagueOutcome.promoted
        ? 'Muhteşem bir performansla ${result.tier.trName} Ligi\'nden ${result.nextTier.trName} Ligi\'ne yükseldin!'
        : (result.outcome == LeagueOutcome.relegated
            ? 'Bu hafta sıralamada geride kaldın ve ${result.nextTier.trName} Ligi\'ne düştün. Pes etmek yok, pratik yapmaya devam et!'
            : 'Ligi #${result.finalRank} sırada tamamladın ve ${result.tier.trName} Ligi\'ndeki yerini başarıyla korudun.');

    final mascotState = result.outcome == LeagueOutcome.promoted
        ? MascotState.celebrating
        : (result.outcome == LeagueOutcome.relegated
            ? MascotState.sad
            : MascotState.normal);

    return Dialog(
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            MascotView(state: mascotState, size: 120),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'FİNAL SIRASI',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${result.finalRank}',
                        style: const TextStyle(color: AppColors.goldLight, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 32, color: Colors.white10),
                  Column(
                    children: [
                      const Text(
                        'YENİ LİG',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.nextTier.trName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Harika! Devam Et',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ).animate().fade(duration: 300.ms).scale(delay: 100.ms),
      ),
    );
  }
}
