import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatt/core/db/database.dart';
import 'package:hatt/core/seed/content_seeder.dart';

/// AssetBundle that reads the real bundled content files from disk so the seed
/// pipeline is exercised end-to-end against the shipping JSON.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      File(key).readAsString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting());
  tearDown(() => db.close());

  test('seeds letters, words, passages and curriculum from bundled JSON',
      () async {
    await ContentSeeder(db, bundle: _DiskBundle()).seed();

    final letters = await db.select(db.letters).get();
    final words = await db.select(db.words).get();
    final nodes = await db.select(db.curriculumNodes).get();
    final progress = await db.select(db.nodeProgress).get();

    expect(letters, isNotEmpty);
    expect(words, isNotEmpty);
    expect(nodes.length, greaterThanOrEqualTo(12));

    // Exactly one node is unlocked initially (the first by ordinal).
    final available =
        progress.where((p) => p.status == 'available').toList();
    expect(available.length, 1);
    final firstNode = (nodes..sort((a, b) => a.ordinal.compareTo(b.ordinal))).first;
    expect(available.single.nodeId, firstNode.id);
  });

  test('seedIfNeeded is idempotent', () async {
    final seeder = ContentSeeder(db, bundle: _DiskBundle());
    await seeder.seedIfNeeded();
    final before = (await db.select(db.words).get()).length;
    await seeder.seedIfNeeded();
    final after = (await db.select(db.words).get()).length;
    expect(after, before);
  });

  test('records the bundled content version after seeding', () async {
    await ContentSeeder(db, bundle: _DiskBundle()).seedIfNeeded();
    final user = await db.userState();
    expect(user.contentVersion, greaterThanOrEqualTo(1));
  });

  test('content upgrade re-seeds but preserves completed progress', () async {
    final seeder = ContentSeeder(db, bundle: _DiskBundle());
    await seeder.seedIfNeeded();

    // Complete the first node, then pretend the install predates this content
    // version (stored version lower than bundled).
    final first = await (db.select(db.curriculumNodes)
          ..orderBy([(t) => OrderingTerm.asc(t.ordinal)])
          ..limit(1))
        .getSingle();
    await db.into(db.nodeProgress).insertOnConflictUpdate(
          NodeProgressCompanion.insert(
            nodeId: first.id,
            status: 'completed',
            stars: const Value(3),
          ),
        );
    await db.updateUserState(
      const UserStateTableCompanion(contentVersion: Value(0)),
    );

    await seeder.seedIfNeeded(); // triggers the upgrade path

    final progress = await (db.select(db.nodeProgress)
          ..where((t) => t.nodeId.equals(first.id)))
        .getSingle();
    expect(progress.status, 'completed');
    expect(progress.stars, 3);

    // The next node after the completed one is available again.
    final all = await db.select(db.nodeProgress).get();
    expect(all.where((p) => p.status == 'available').length, 1);
    final user = await db.userState();
    expect(user.contentVersion, greaterThanOrEqualTo(1));
  });
}
