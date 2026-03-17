import 'package:hive/hive.dart';
import 'dhikr_model.dart';

class CustomDhikr extends HiveObject {
  String id;
  String arabicText;
  int target;

  CustomDhikr({required this.id, required this.arabicText, required this.target});

  DhikrModel toDhikrModel() {
    return DhikrModel(
      id: id,
      name: arabicText,
      arabicText: arabicText,
      transliteration: 'ذكر مخصص',
      defaultTarget: target,
      gradientIndex: 5,
      keywords: [], // Disable fuzzy matching for custom until fully trained
      isCustom: true,
    );
  }
}

class CustomDhikrAdapter extends TypeAdapter<CustomDhikr> {
  @override
  final int typeId = 1;

  @override
  CustomDhikr read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomDhikr(
      id: fields[0] as String,
      arabicText: fields[1] as String,
      target: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CustomDhikr obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.arabicText)
      ..writeByte(2)
      ..write(obj.target);
  }
}
