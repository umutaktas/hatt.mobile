import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mascot/mascot_state.dart';
import '../../../core/mascot/mascot_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stat_header.dart';
import '../../lesson/presentation/lesson_screen.dart';
import '../data/path_models.dart';
import 'path_providers.dart';

/// Duolingo-style serpentine learning path (CLAUDE.md §4.1).
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(pathProvider);
    return Column(
      children: [
        const StatHeader(),
        Expanded(
          child: pathAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (units) => ListView.builder(
              padding: const EdgeInsets.only(bottom: 48),
              itemCount: units.length,
              itemBuilder: (context, i) => _UnitSection(
                unit: units[i],
                isFirstUnit: i == 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitSection extends StatelessWidget {
  const _UnitSection({
    required this.unit,
    required this.isFirstUnit,
  });

  final PathUnit unit;
  final bool isFirstUnit;

  @override
  Widget build(BuildContext context) {
    final activeNodeIndex = unit.nodes.indexWhere(
      (n) => n.status == NodeStatus.available,
    );

    return Column(
      children: [
        // Duolingo-style Unit Banner
        _UnitBanner(unit: unit),

        const SizedBox(height: 16),

        // Path Nodes with serpentine alignment
        ...unit.nodes.asMap().entries.map((entry) {
          final index = entry.key;
          final node = entry.value;

          // Serpentine path X offset (-70 to +70)
          final xOffset = math.sin(index * 0.8) * 70.0;
          final isActive = index == activeNodeIndex ||
              (activeNodeIndex == -1 && node.status == NodeStatus.available);
          final showMascotNextToNode = isActive;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(xOffset, 0),
                  child: _DuolingoNodeButton(
                    node: node,
                    isActive: isActive,
                  ),
                ),

                // Cheering Mascot sitting next to active node
                if (showMascotNextToNode)
                  Positioned(
                    left: xOffset > 0 ? null : (MediaQuery.of(context).size.width / 2) + xOffset + 48,
                    right: xOffset > 0 ? (MediaQuery.of(context).size.width / 2) - xOffset + 48 : null,
                    child: const MascotView(
                      state: MascotState.celebrating,
                      size: 72,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Duolingo-style Unit Header Banner
class _UnitBanner extends StatelessWidget {
  const _UnitBanner({required this.unit});

  final PathUnit unit;

  @override
  Widget build(BuildContext context) {
    final percent = unit.nodes.isEmpty
        ? 0.0
        : (unit.completedCount / unit.nodes.length).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.parchment,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${unit.completedCount} / ${unit.nodes.length} ders tamamlandı',
                      style: const TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: AppColors.goldLight,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Unit Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.inkSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tactile 3D Duolingo-style node button with press physics & floating START badge
class _DuolingoNodeButton extends StatefulWidget {
  const _DuolingoNodeButton({
    required this.node,
    required this.isActive,
  });

  final PathNode node;
  final bool isActive;

  @override
  State<_DuolingoNodeButton> createState() => _DuolingoNodeButtonState();
}

class _DuolingoNodeButtonState extends State<_DuolingoNodeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final locked = node.status == NodeStatus.locked;
    final completed = node.status == NodeStatus.completed;

    // Duolingo 3D Button Color Palette
    final baseColor = locked
        ? const Color(0xFFB0B9C2)
        : completed
            ? const Color(0xFF2E7D74) // Teal completed
            : const Color(0xFFD8B15A); // Gold active

    final darkBaseColor = locked
        ? const Color(0xFF7E8A97)
        : completed
            ? const Color(0xFF1E5650)
            : const Color(0xFF9E7720);

    const double buttonSize = 82.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating "BAŞLA" (START) Tooltip Badge above active node
        if (widget.isActive && !locked)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BAŞLA',
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.goldLight,
                  size: 16,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -4, duration: 800.ms, curve: Curves.easeInOut),

        // 3D Pressable Node Container
        GestureDetector(
          onTapDown: locked ? null : (_) => setState(() => _isPressed = true),
          onTapUp: locked ? null : (_) => setState(() => _isPressed = false),
          onTapCancel: locked ? null : () => setState(() => _isPressed = false),
          onTap: locked
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(node: node),
                    ),
                  ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: buttonSize,
            height: buttonSize,
            margin: EdgeInsets.only(top: _isPressed ? 6 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: darkBaseColor, // Bottom 3D shadow layer
            ),
            child: Stack(
              children: [
                // Top 3D Face
                Container(
                  width: buttonSize,
                  height: buttonSize - (_isPressed ? 2 : 7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor,
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: widget.isActive && !locked
                        ? [
                            BoxShadow(
                              color: baseColor.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      _iconFor(node.type, completed),
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Node Title Text
        SizedBox(
          width: 130,
          child: Text(
            node.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w600,
              color: locked ? AppColors.locked : AppColors.ink,
            ),
          ),
        ),

        // Star rating bar for completed nodes
        if (completed && node.stars > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Icon(
                i < node.stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 18,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static IconData _iconFor(NodeType t, bool completed) {
    if (completed) return Icons.check_rounded;
    return switch (t) {
      NodeType.letter => Icons.translate_rounded,
      NodeType.vocab => Icons.menu_book_rounded,
      NodeType.reading => Icons.article_rounded,
      NodeType.review => Icons.replay_rounded,
      NodeType.checkpoint => Icons.workspace_premium_rounded,
    };
  }
}
