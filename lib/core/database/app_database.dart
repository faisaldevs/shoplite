import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:shoplite/core/database/converters/string_list_converter.dart';
import 'package:shoplite/core/database/tables/products_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ProductsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'shoplite'));

  @override
  int get schemaVersion => 1;
}
