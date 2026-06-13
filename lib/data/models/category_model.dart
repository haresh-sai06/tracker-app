import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 3)
class CategoryModel extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? name;

  @HiveField(2)
  int? iconCodePoint;

  @HiveField(3)
  int? colorValue;

  @HiveField(4)
  bool? isDefault;

  @HiveField(5)
  bool? isDeleted;

  CategoryModel({
    this.id,
    this.name,
    this.iconCodePoint,
    this.colorValue,
    this.isDefault,
    this.isDeleted,
  });
}
