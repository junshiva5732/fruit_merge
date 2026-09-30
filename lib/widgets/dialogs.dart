import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/board_painter.dart';
import '../game/world.dart';
import '../l10n/strings.dart';
import '../services/sound.dart';
import '../services/storage.dart';

const brown = Color(0xFF5D4037);

/// 과일 진화표: 체리 → … → 수박. [biggest] 보다 큰 과일은 흐리게 (최소 감까지는 선명).
class EvolutionChart extends StatelessWidget {
  final int biggest;
  final double size;
  const EvolutionChart({super.key, required this.biggest, required this.size});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Tooltip(
      message: s.evolution,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: Colors.white60, borderRadius: BorderRadius.circular(size)),
        child: FittedBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var l = 0; l <= maxLevel; l++)
                Opacity(opacity: l <= math.max(biggest, 4) ? 1 : 0.3, child: FruitIcon(l, size: size, face: false)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showHelpDialog(BuildContext context) {
  final s = S.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.howToPlay),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EvolutionChart(biggest: maxLevel, size: 30),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final p in const [pieceRainbow, pieceBomb, pieceStone]) FruitIcon(p, size: 40)],
            ),
            const SizedBox(height: 12),
            Text(s.helpBody),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
    ),
  );
}

Future<void> showLanguageDialog(BuildContext context) async {
  final s = S.of(context);
  final controller = LocaleController.of(context);
  final picked = await showDialog<Locale?>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(s.language),
      children: [
        RadioGroup<Locale?>(
          groupValue: controller.value,
          onChanged: (v) => Navigator.pop(ctx, v ?? const Locale('und')),
          child: Column(
            children: [
              for (final l in <Locale?>[null, ...S.supported])
                RadioListTile<Locale?>(value: l, title: Text(l == null ? s.systemLanguage : S.nativeName(l))),
            ],
          ),
        ),
      ],
    ),
  );
  if (picked == null) return;
  controller.value = picked.languageCode == 'und' ? null : picked;
}

/// 배경음악 · 효과음 · 진동 스위치.
class SoundSwitches extends StatefulWidget {
  final Storage storage;
  const SoundSwitches({super.key, required this.storage});

  @override
  State<SoundSwitches> createState() => _SoundSwitchesState();
}

class _SoundSwitchesState extends State<SoundSwitches> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = widget.storage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.music_note_rounded),
          title: Text(s.music),
          value: st.music,
          onChanged: (v) {
            st.setMusic(v);
            Sound.instance.setMusic(v);
            setState(() {});
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.volume_up_rounded),
          title: Text(s.soundEffects),
          value: st.sfx,
          onChanged: (v) {
            st.setSfx(v);
            Sound.instance.setSfx(v);
            Sound.instance.play('click');
            setState(() {});
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.vibration_rounded),
          title: Text(s.vibration),
          value: st.vibration,
          onChanged: (v) {
            st.setVibration(v);
            setState(() {});
          },
        ),
      ],
    );
  }
}

/// 지도 화면의 설정: 소리 스위치 + 언어 + 게임 방법.
Future<void> showSettingsDialog(BuildContext context, Storage storage) async {
  Sound.instance.play('click');
  final s = S.of(context);
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.settings, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoundSwitches(storage: storage),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.language_rounded),
            label: Text(s.language),
            onPressed: () => Navigator.pop(ctx, 'lang'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.help_outline_rounded),
            label: Text(s.howToPlay),
            onPressed: () => Navigator.pop(ctx, 'help'),
          ),
        ],
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'lang':
      await showLanguageDialog(context);
    case 'help':
      await showHelpDialog(context);
  }
}
