import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/mascot/mascot_state.dart';
import '../../../core/mascot/mascot_view.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';

/// Premium paywall screen (CLAUDE.md §2, §6).
/// Features plan selection (Annual vs Monthly), benefit highlights,
/// high-contrast mascot spotlight, and working simulated purchase activation.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  int _selectedPlan = 0; // 0 = Annual, 1 = Monthly
  bool _isLoading = false;

  static const _benefits = [
    (
      Icons.favorite,
      'Sınırsız Can',
      'Hata yapma korkusu olmadan dilediğince pratik yap ve öğren.'
    ),
    (
      Icons.ac_unit,
      'Sınırsız Seri Koruması',
      'Yoğun günlerde çalışmayı kaçırsan bile serin (streak) asla bozulmaz.'
    ),
    (
      Icons.workspace_premium,
      'Sınırsız Checkpoint',
      'Bildiğin üniteleri sınavları geçerek hızlıca atla.'
    ),
    (
      Icons.insights,
      'Zayıf Nokta Analizi',
      'FSRS motorunun tespit ettiği zorlandığın kelimelere özel alıştırma yap.'
    ),
    (
      Icons.auto_awesome,
      'AI Kitabe Çözücü (Yakında)',
      'Fotoğrafını çektiğin Osmanlıca mektup ve kitabeleri yapay zeka ile oku.'
    ),
  ];

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);
    try {
      final entitlement = ref.read(entitlementProvider);
      final sound = ref.read(soundServiceProvider);

      await entitlement.purchasePremium();
      await sound.play(Sfx.levelUp);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.workspace_premium, color: AppColors.gold),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hokka Premium hesabınız başarıyla aktifleştirildi!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.ink,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final entitlement = ref.watch(entitlementProvider);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar with Close Button (No AppBar line artifact)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text(
                    'PREMİUM',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 2.0,
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 8),

                  // Mascot Header Card with Warm Parchment Backdrop & Ground Shadow (Figma Node 3:2)
                  Center(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        color: AppColors.parchment,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.35),
                            blurRadius: 25,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Soft Oval Ground Shadow under Hokka's feet (Figma 3:2 style)
                          Positioned(
                            bottom: 18,
                            child: Container(
                              width: 90,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const MascotView(
                            state: MascotState.celebrating,
                            size: 130,
                          ),
                        ],
                      ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Hokka Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ).animate().fade().slideY(begin: 0.2),
                  const SizedBox(height: 6),
                  const Text(
                    'Osmanlıca okuma yolculuğunu 3 kat hızlandırın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                  const SizedBox(height: 28),

                  // Plans Selection Cards
                  Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          title: 'Yıllık Plan',
                          price: '₺29.99 / ay',
                          subtitle: '₺359.99 / yıl faturalandırılır',
                          badge: '%50 İNDİRİM',
                          isSelected: _selectedPlan == 0,
                          onTap: () => setState(() => _selectedPlan = 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          title: 'Aylık Plan',
                          price: '₺59.99 / ay',
                          subtitle: 'Her ay yenilenir',
                          badge: null,
                          isSelected: _selectedPlan == 1,
                          onTap: () => setState(() => _selectedPlan = 1),
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                  const SizedBox(height: 28),

                  // Benefits List
                  const Text(
                    'PREMİUM AYRICALIKLARI',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._benefits.map(
                    (b) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(b.$1, color: AppColors.goldLight, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.$2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b.$3,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Bottom CTA Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: (entitlement.isPremium || _isLoading)
                          ? null
                          : _handlePurchase,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              entitlement.isPremium
                                  ? 'Zaten Premium Üyesiniz'
                                  : flags.purchasesEnabled
                                      ? '7 Gün Ücretsiz Dene & Başla'
                                      : 'Premium Test Et (Simüle Et)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    flags.purchasesEnabled
                        ? 'İstediğin zaman Ayarlar veya App Store üzerinden iptal edebilirsin.'
                        : 'Simülasyon modundasınız: Butona basarak Premium\'u anında aktif edebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String price;
  final String subtitle;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.gold : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? AppColors.goldLight : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
