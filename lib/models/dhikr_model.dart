/// Immutable data model representing a single Dhikr option.
///
/// Contains display information and Arabic keyword patterns used
/// by the fuzzy voice-matching engine in [CounterProvider].
class DhikrModel {
  const DhikrModel({
    required this.id,
    required this.name,
    required this.arabicText,
    required this.transliteration,
    required this.defaultTarget,
    required this.gradientIndex,
    required this.keywords,
    this.isCustom = false,
  });

  /// Unique identifier used for Hive storage keys.
  final String id;

  /// Display name shown on the card and counter screen.
  final String name;

  /// Full Arabic text displayed on the card.
  final String arabicText;

  /// Latin transliteration for accessibility.
  final String transliteration;

  /// Default repetition target (e.g. 33 or 99).
  final int defaultTarget;

  /// Index into [AppColors.cardGradients] for the card background.
  final int gradientIndex;

  /// List of Arabic keyword fragments used for fuzzy voice matching.
  /// If recognized speech contains ANY of these strings, the counter increments.
  final List<String> keywords;

  /// Whether this is user-defined custom dhikr.
  final bool isCustom;

  DhikrModel copyWith({String? name, String? arabicText, int? defaultTarget, List<String>? keywords}) {
    return DhikrModel(
      id: id,
      name: name ?? this.name,
      arabicText: arabicText ?? this.arabicText,
      transliteration: transliteration,
      defaultTarget: defaultTarget ?? this.defaultTarget,
      gradientIndex: gradientIndex,
      keywords: keywords ?? this.keywords,
      isCustom: isCustom,
    );
  }
}

/// Pre-defined built-in dhikr options.
class DhikrPresets {
  DhikrPresets._();

  static const subhanallah = DhikrModel(
    id: 'subhanallah',
    name: 'SubhanAllah',
    arabicText: 'سُبْحَانَ اللَّهِ',
    transliteration: 'SubhanAllah',
    defaultTarget: 33,
    gradientIndex: 0,
    keywords: ['سبحان', 'سبحان الله', 'سوبحان', 'سبحانه'],
  );

  static const alhamdulillah = DhikrModel(
    id: 'alhamdulillah',
    name: 'Alhamdulillah',
    arabicText: 'الْحَمْدُ لِلَّهِ',
    transliteration: 'Alhamdulillah',
    defaultTarget: 33,
    gradientIndex: 2,
    keywords: ['الحمد', 'الحمد لله', 'حمد', 'احمد لله'],
  );

  static const allahuakbar = DhikrModel(
    id: 'allahuakbar',
    name: 'Allahu Akbar',
    arabicText: 'اللَّهُ أَكْبَرُ',
    transliteration: 'Allahu Akbar',
    defaultTarget: 34,
    gradientIndex: 3,
    keywords: ['الله أكبر', 'اكبر', 'أكبر', 'الله اكبر'],
  );

  static const astaghfirullah = DhikrModel(
    id: 'astaghfirullah',
    name: 'Astaghfirullah',
    arabicText: 'أَسْتَغْفِرُ اللَّهَ',
    transliteration: 'Astaghfirullah',
    defaultTarget: 33,
    gradientIndex: 4,
    keywords: ['أستغفر', 'استغفر', 'استغفر الله', 'اغفر'],
  );

  static const custom = DhikrModel(
    id: 'custom',
    name: 'Custom',
    arabicText: '✦',
    transliteration: 'Custom Dhikr',
    defaultTarget: 100,
    gradientIndex: 5,
    keywords: [],
    isCustom: true,
  );

  static const List<DhikrModel> all = [
    subhanallah,
    alhamdulillah,
    allahuakbar,
    astaghfirullah,
    custom,
  ];
}
