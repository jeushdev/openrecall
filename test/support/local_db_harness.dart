import 'package:open_recall/core/local_db/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points sqflite at the FFI implementation so tests can open a real database
/// on the Dart VM. Call once per test file, in `setUpAll`.
///
/// Without this every `Local*Store` test can only exercise the `isNoop`
/// (null-database) contract — a real, *empty* database is a different code
/// path, and the one a fresh install offline actually hits.
void initLocalDbTestFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// A fresh in-memory database at the current schema version. Nothing is
/// persisted between tests.
Future<AppDatabase> openTestDatabase() =>
    AppDatabase.open(path: inMemoryDatabasePath);
