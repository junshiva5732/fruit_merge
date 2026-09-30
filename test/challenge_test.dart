import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_merge/game/share_card.dart';
import 'package:fruit_merge/services/challenge.dart';

void main() {
  test('web link carries score, stage and stars', () {
    const c = Challenge(score: 15868, stage: 12, stars: 3);
    final uri = c.webLink;
    expect(uri.toString(), startsWith(Challenge.webBase));
    expect(uri.queryParameters, {'s': '15868', 'st': '12', 'r': '3'});
    expect(Challenge.fromQuery(uri.queryParameters), c);
  });

  test('app routes: path or full uri', () {
    const c = Challenge(score: 500);
    expect(Challenge.fromRoute('/challenge?s=500'), c);
    expect(Challenge.fromRoute('fruitmerge://fm/challenge?s=500'), c);
    expect(Challenge.fromRoute('/challenge?s=500&st=7&r=2'), const Challenge(score: 500, stage: 7, stars: 2));
    expect(Challenge.fromRoute('/'), isNull);
    expect(Challenge.fromRoute(null), isNull);
    expect(Challenge.fromRoute('/challenge'), isNull);
    expect(Challenge.fromRoute('/challenge?s=abc'), isNull);
  });

  test('bad values are rejected or clamped', () {
    expect(Challenge.fromQuery({'s': '-1'}), isNull);
    expect(Challenge.fromQuery({'s': '999999999'}), isNull);
    expect(Challenge.fromQuery({'s': '10', 'st': '99'}), const Challenge(score: 10));
    expect(Challenge.fromQuery({'s': '10', 'st': '3', 'r': '9'}), const Challenge(score: 10, stage: 3, stars: 3));
  });

  test('play store referrer (encoded or not)', () {
    expect(Challenge.fromReferrer('s=123&st=4'), const Challenge(score: 123, stage: 4));
    expect(Challenge.fromReferrer('s%3D123%26st%3D4'), const Challenge(score: 123, stage: 4));
    expect(Challenge.fromReferrer('utm_source=google-play&utm_medium=organic'), isNull);
    expect(Challenge.fromReferrer(null), isNull);
  });

  test('share card renders', () async {
    await TestAsyncUtils.guard(() async {
      const card = ShareCard(title: 'Fruit Merge', label: 'STAGE 12 CLEAR', score: 15868, stars: 2, fruit: 9, callToAction: 'Can you beat me?');
      final png = await card.toPng();
      expect(png.length, greaterThan(10000));
      Directory('build/previews').createSync(recursive: true);
      File('build/previews/share_card.png').writeAsBytesSync(png);
    });
  });
}
