import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mascot/mascot_state.dart';
import '../../../core/mascot/mascot_view.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ottoman_text.dart';

/// Redesigned multi-slide premium onboarding flow (CLAUDE.md §2, Phase 6).
/// Integrates custom page indicator, elegant slide animations, interactive preview cards,
/// and explicit GDPR/KVKK consent.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _consent = false;
  static const int _totalPages = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(userRepositoryProvider).setOnboarded(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Skip Button (hidden on the consent page)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: _page < _totalPages - 1
                    ? TextButton(
                        onPressed: () => _controller.animateToPage(
                          _totalPages - 1,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text(
                          'Geç',
                          style: TextStyle(
                            color: AppColors.locked,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox(height: 48),
              ),
            ),

            // Sliding pages
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  const _WelcomeSlide(),
                  const _MethodSlide(),
                  const _GamificationSlide(),
                  _ConsentSlide(
                    consent: _consent,
                    onChanged: (v) => setState(() => _consent = v),
                  ),
                ],
              ),
            ),

            // Page Indicator Dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _PageIndicator(count: _totalPages, current: _page),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _page < _totalPages - 1
                      ? () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          )
                      : (_consent ? _finish : null),
                  child: Text(
                    _page < _totalPages - 1 ? 'Devam Et' : 'Başla',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.gold
                : AppColors.locked.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotView(state: MascotState.celebrating, size: 190)
              .animate()
              .scale(duration: 400.ms, curve: Curves.easeOutBack)
              .shake(delay: 200.ms, hz: 4),
          const SizedBox(height: 32),
          const OttomanText(
            'حُقَّه',
            size: OttomanTextSize.reading,
            color: AppColors.gold,
          ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 12),
          Text(
            'Hokka\'ya Hoş Geldin',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          const Text(
            'Osmanlı Türkçesi okumayı adım adım, oyunlaştırılmış dersler ve gerçek tarihi metinlerle eğlenerek öğrenin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
              height: 1.5,
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _MethodSlide extends StatelessWidget {
  const _MethodSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotView(state: MascotState.normal, size: 130)
              .animate()
              .fade(duration: 300.ms)
              .slideX(begin: -0.2),
          const SizedBox(height: 24),
          // Interactive Preview Word Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.parchment,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OttomanText('مكتوب', size: OttomanTextSize.optionChip),
                SizedBox(width: 16),
                Icon(Icons.arrow_forward, color: AppColors.gold, size: 20),
                SizedBox(width: 16),
                Text(
                  'Mektup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: 200.ms).scale(curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          Text(
            'Tarihi Metinlerle Pratik',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          const Text(
            'Kitabeler, yazmalar ve basılı eserlerden alınmış orijinal örneklerle, dilin gerçek ruhunu hissederek okuma hızınızı geliştirin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
              height: 1.5,
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _GamificationSlide extends StatelessWidget {
  const _GamificationSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A cute stack representing a trophy and Hokka mascot
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MascotView(state: MascotState.celebrating, size: 120),
              SizedBox(width: 16),
              Icon(Icons.emoji_events, size: 64, color: AppColors.gold),
            ],
          ).animate().fade().scale(curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          Text(
            'Ligler ve Günlük Seri',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          const Text(
            'Her gün çalışarak serinizi (streak) koruyun, XP puanları toplayın ve haftalık liglerde diğer öğrencilerle tatlı bir rekabete girin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
              height: 1.5,
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _ConsentSlide extends StatelessWidget {
  const _ConsentSlide({required this.consent, required this.onChanged});
  final bool consent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotView(state: MascotState.sleeping, size: 130)
              .animate()
              .fade(duration: 400.ms),
          const SizedBox(height: 24),
          Text(
            'Gizlilik ve Rıza',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          const Text(
            'Hokka varsayılan olarak tamamen anonim çalışır, kişisel veri toplamaz. İlerlemeniz sadece cihazınızda saklanır ve rızanız olmadan sunucuya yedeklenmez.\n\nİstediğiniz zaman Ayarlar → "Hesabımı ve verilerimi sil" seçeneğiyle verilerinizi tamamen yok edebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.55,
            ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: consent,
            onChanged: (v) => onChanged(v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.gold,
            title: const Text(
              'Gizlilik politikasını okudum ve anonim kullanımı kabul ediyorum.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ).animate().fade(delay: 300.ms),
        ],
      ),
    );
  }
}
