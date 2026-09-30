import 'package:flutter/material.dart';

import '../game/board_painter.dart';
import '../game/stages.dart';
import '../l10n/strings.dart';
import '../services/challenge.dart';
import '../services/sound.dart';
import '../services/storage.dart';
import '../widgets/dialogs.dart';
import '../widgets/outlined_text.dart';
import 'game_screen.dart';

/// 친구의 도전 링크로 앱이 열렸을 때: 친구 기록을 보여 주고 도전을 시작한다.
class ChallengeScreen extends StatelessWidget {
  final Storage storage;
  final Challenge challenge;
  const ChallengeScreen({super.key, required this.storage, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = challenge.stage;
    final locked = st != null && st > storage.unlockedStage;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE0B2), Color(0xFFFF8A65)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 8,
                top: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.white70, foregroundColor: brown),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mail_rounded, size: 64, color: Colors.white),
                      FittedBox(fit: BoxFit.scaleDown, child: OutlinedText(s.challengeTitle, size: 32)),
                      const SizedBox(height: 20),
                      Container(
                        width: 320,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFA1887F), width: 4),
                        ),
                        child: Column(
                          children: [
                            FruitIcon(st == null ? 10 : Stage.of(st).goal == GoalType.fruit ? Stage.of(st).target : 7, size: 110),
                            Text(
                              st == null ? s.cardEndless : s.cardStage(st),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: brown, fontSize: 16),
                            ),
                            Text(s.friendScore, style: const TextStyle(color: brown)),
                            OutlinedText('${challenge.score}', size: 52),
                            if (challenge.stars > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Icon(
                                      Icons.star_rounded,
                                      size: 40,
                                      color: i < challenge.stars ? const Color(0xFFFFB300) : Colors.black12,
                                    ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            if (locked)
                              Text(s.challengeStageLocked(st), textAlign: TextAlign.center, style: const TextStyle(color: brown))
                            else ...[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF43A047),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: const Icon(Icons.sports_esports_rounded),
                                  label: Text(s.acceptChallenge, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                  onPressed: () {
                                    Sound.instance.play('click');
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => GameScreen(
                                          storage: storage,
                                          stage: st == null ? null : Stage.of(st),
                                          friendScore: challenge.score,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (st == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(s.challengeNewGame, style: const TextStyle(fontSize: 12, color: brown)),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
