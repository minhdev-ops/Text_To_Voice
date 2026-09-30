import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:text_to_voice/data/database/app_database.dart';

Future<void> main() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.customSelect("SELECT name, sql FROM sqlite_master WHERE type='table'").get().then((rows) {
    for (final r in rows) {
      // ignore: avoid_dynamic_calls
      print('${r.data['name']}: ${r.data['sql']}');
    }
  });
  await db.close();
}
