import 'package:hive/hive.dart';

part 'history_entry.g.dart';

/// Hive-persisted record of a single completed tasbih session.
///
/// Stored in the 'history' box and rendered in the Progress History overlay.
@HiveType(typeId: 0)
class HistoryEntry extends HiveObject {
  @HiveField(0)
  late String dhikrId;

  @HiveField(1)
  late String dhikrName;

  @HiveField(2)
  late int count;

  @HiveField(3)
  late int target;

  @HiveField(4)
  late DateTime completedAt;

  @HiveField(5)
  late bool targetReached;

  HistoryEntry({
    required this.dhikrId,
    required this.dhikrName,
    required this.count,
    required this.target,
    required this.completedAt,
    required this.targetReached,
  });
}
