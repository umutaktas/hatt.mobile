/// Mascot ("Mürekkep", the ink-bottle character with a pen-nib cap,
/// CLAUDE.md §4.3) emotional states. The enum abstracts state so artwork can
/// be swapped without touching call sites. Art source: Figma "Osmanlıca
/// E-Learning — Mürekkep Maskot" (poses: Neutral / Thinking / Celebrate /
/// Encourage / Sleeping — the last derived from Neutral with closed eyes).
enum MascotState {
  normal('assets/mascot/murekkep_neutral.png'),
  celebrating('assets/mascot/murekkep_celebrate.png'),
  sad('assets/mascot/murekkep_encourage.png'),
  sleeping('assets/mascot/murekkep_sleep.png');

  const MascotState(this.asset);

  /// Image asset path for this state.
  final String asset;
}

/// Closed-eyes frame matching the Neutral pose — used as the blink frame for
/// [MascotState.normal] and as the [MascotState.sleeping] art.
const String mascotClosedEyesAsset = 'assets/mascot/murekkep_sleep.png';
