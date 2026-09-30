import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../game/share_card.dart';
import '../l10n/strings.dart';
import '../services/challenge.dart';
import '../services/sound.dart';
import 'dialogs.dart';

/// 자랑하기: 점수 카드 미리보기 + "카드와 함께 보내기" / "링크만 보내기".
/// 안드로이드 공유 창으로 보내므로 카카오톡·인스타·문자 등 어디로든 갈 수 있다.
Future<void> showShareSheet(BuildContext context, {required Challenge challenge, required int fruit}) async {
  Sound.instance.play('click');
  final s = S.of(context);
  final card = ShareCard(
    title: s.appTitle,
    label: challenge.stage == null ? s.cardEndless : s.cardStage(challenge.stage!),
    score: challenge.score,
    stars: challenge.stars,
    fruit: fruit,
    callToAction: s.cardCallToAction,
  );
  final png = card.toPng();
  final text =
      (challenge.stage == null ? s.shareTextEndless(challenge.score) : s.shareTextStage(challenge.stage!, challenge.stars)) +
      challenge.webLink.toString();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFFFF8E1),
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.brag, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brown)),
            const SizedBox(height: 12),
            FutureBuilder<Uint8List>(
              future: png,
              builder: (context, snap) => SizedBox(
                height: 280,
                child: snap.hasData
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(snap.data!, fit: BoxFit.contain))
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.image_rounded),
                label: Text(s.shareWithImage, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                onPressed: () async {
                  final box = ctx.findRenderObject() as RenderBox?;
                  final bytes = await png;
                  await SharePlus.instance.share(
                    ShareParams(
                      text: text,
                      files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'fruit_merge.png')],
                      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.link_rounded),
                label: Text(s.shareLinkOnly, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                onPressed: () async {
                  final box = ctx.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(
                    ShareParams(text: text, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.shareLinkHint, style: const TextStyle(fontSize: 12, color: brown)),
            ),
          ],
        ),
      ),
    ),
  );
}
