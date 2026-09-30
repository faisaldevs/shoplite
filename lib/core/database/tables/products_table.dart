import 'package:drift/drift.dart';
import 'package:shoplite/core/database/converters/string_list_converter.dart';

@DataClassName("ProductRow")
class ProductsTable extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get category => text().withDefault(const Constant(""))();
  TextColumn get description => text().withDefault(const Constant(""))();
  RealColumn get price => real().withDefault(const Constant(0))();
  RealColumn get discountPercentage => real().withDefault(const Constant(0))();
  RealColumn get rating => real().withDefault(const Constant(0))();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  TextColumn get thumbnail => text().nullable()();

  TextColumn get images => text()
      .map(const StringListConverter())
      .withDefault(const Constant("[]"))();
  IntColumn get position => integer()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column>? get primaryKey => {id};
}

/*
  final int id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double discountPercentage;
  final double rating;
  final int stock;
  final String? thumbnail;
  final List<String> images;
*/
