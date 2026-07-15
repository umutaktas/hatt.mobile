import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../content/content_models.dart';
import '../db/database.dart';

/// Seeds the local database from bundled JSON assets (CLAUDE.md §2: "içerik,
/// uygulama paketiyle gelen JSON + görsel asset'lerden seed edilir").
///
/// Content is versioned via curriculum.json's `version` field, stored in
/// `user_state.content_version`. On first launch a full seed runs; when an app
/// update ships a higher content version, the content tables are refreshed
/// while node progress is preserved (new nodes start locked, removed nodes'
/// progress is dropped).
class ContentSeeder {
  ContentSeeder(this.db, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AppDatabase db;
  final AssetBundle _bundle;

  Future<void> seedIfNeeded() async {
    final curriculum = await _loadCurriculum();
    if (!await db.isSeeded) {
      await _seed(curriculum, fresh: true);
      return;
    }
    final stored = (await db.userState()).contentVersion;
    if (stored < curriculum.version) {
      await _seed(curriculum, fresh: false);
    }
  }

  /// Full seed; equivalent to a fresh install (also used by tests).
  Future<void> seed() async => _seed(await _loadCurriculum(), fresh: true);

  Future<CurriculumDoc> _loadCurriculum() async {
    final json = jsonDecode(
      await _bundle.loadString('assets/content/curriculum.json'),
    ) as Map<String, dynamic>;
    return CurriculumDoc.fromJson(json);
  }

  Future<void> _seed(CurriculumDoc curriculum, {required bool fresh}) async {
    final letters = await _loadList('assets/content/letters.json')
        .then((l) => l.map((e) => LetterDto.fromJson(e)).toList());
    final words = await _loadList('assets/content/words.json')
        .then((l) => l.map((e) => WordDto.fromJson(e)).toList());
    final passages = await _loadList('assets/content/passages.json')
        .then((l) => l.map((e) => PassageDto.fromJson(e)).toList());

    await db.transaction(() async {
      // Snapshot existing progress before wiping content (upgrade path).
      final existingProgress = fresh
          ? <String, NodeProgressRow>{}
          : {
              for (final row in await db.select(db.nodeProgress).get())
                row.nodeId: row,
            };

      // Content tables are fully owned by the bundle — replace them.
      await db.delete(db.passageLines).go();
      await db.delete(db.readingPassages).go();
      await db.delete(db.words).go();
      await db.delete(db.letters).go();
      await db.delete(db.curriculumNodes).go();
      await db.delete(db.nodeProgress).go();

      await db.batch((b) {
        b.insertAll(
          db.letters,
          letters.map(
            (d) => LettersCompanion.insert(
              id: d.id,
              name: d.name,
              isolated: d.isolated,
              initialForm: d.initialForm,
              medialForm: d.medialForm,
              finalForm: d.finalForm,
              soundValue: d.soundValue,
              similarGroup: Value(d.similarGroup),
              exampleWord: Value(d.exampleWord),
            ),
          ),
        );
        b.insertAll(
          db.words,
          words.map(
            (d) => WordsCompanion.insert(
              id: d.id,
              ottoman: d.ottoman,
              transliteration: d.transliteration,
              meaningTr: d.meaningTr,
              frequencyRank: d.frequencyRank,
              level: d.level,
              root: Value(d.root),
              exampleSentence: Value(d.exampleSentence),
            ),
          ),
        );
        for (final p in passages) {
          b.insert(
            db.readingPassages,
            ReadingPassagesCompanion.insert(
              id: p.id,
              title: p.title,
              level: p.level,
              genre: p.genre,
              imageAssetPath: Value(p.imageAssetPath),
            ),
          );
          b.insertAll(
            db.passageLines,
            p.lines.map(
              (l) => PassageLinesCompanion.insert(
                id: l.id,
                passageId: p.id,
                ordinal: l.ordinal,
                ottoman: l.ottoman,
                transliteration: l.transliteration,
                simplifiedTr: l.simplifiedTr,
              ),
            ),
          );
        }

        var globalOrdinal = 0;
        var unlockNext = true; // first not-yet-completed node opens
        for (final unit in curriculum.units) {
          for (final node in unit.nodes) {
            b.insert(
              db.curriculumNodes,
              CurriculumNodesCompanion.insert(
                id: node.id,
                type: node.type,
                unitId: unit.id,
                unitTitle: unit.title,
                ordinal: globalOrdinal,
                title: node.title,
                contentRefs: jsonEncode(node.contentRefs),
              ),
            );

            // Preserve prior progress on upgrade; new nodes follow the same
            // unlock rule as a fresh path.
            final prior = existingProgress[node.id];
            final String status;
            if (prior != null && prior.status == 'completed') {
              status = 'completed';
            } else if (unlockNext) {
              status = 'available';
            } else {
              status = 'locked';
            }
            if (status != 'completed') unlockNext = false;

            b.insert(
              db.nodeProgress,
              NodeProgressCompanion.insert(
                nodeId: node.id,
                status: status,
                stars: Value(prior?.stars ?? 0),
                bestScore: Value(prior?.bestScore ?? 0),
              ),
            );
            globalOrdinal++;
          }
        }
      });

      await db.updateUserState(
        UserStateTableCompanion(contentVersion: Value(curriculum.version)),
      );
    });
  }

  Future<List<Map<String, dynamic>>> _loadList(String path) async {
    final raw = await _bundle.loadString(path);
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }
}
