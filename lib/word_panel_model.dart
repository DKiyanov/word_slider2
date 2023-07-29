class JrfTextConstructor {
  static const String text               = 'text';
  static const String objects            = 'objects';
  static const String styles             = 'styles';
  static const String markStyle          = 'markStyle';
  static const String basement           = 'basement';
  static const String canMoveWord        = 'canMoveWord';
  static const String randomMixWord      = 'randomMixWord';
  static const String randomView         = 'randomView';
  static const String notDelFromBasement = 'notDelFromBasement';
}

class JtfWordObject {
  static const String name      = 'name';
  static const String viewIndex = 'viewIndex';
  static const String views     = 'views';
}

class TextConstructor {
  final String text;
  final List<WordObject> objects;
  final List<String> styles;
  final int markStyle;
  final List<String> basement;
  final bool canMoveWord;
  final bool randomMixWord;
  final bool randomView;
  final bool notDelFromBasement;

  TextConstructor({
    required this.text,
    required this.objects,
    required this.styles,
    required this.markStyle,
    required this.basement,
    required this.canMoveWord,
    required this.randomMixWord,
    required this.randomView,
    required this.notDelFromBasement
  });

  factory TextConstructor.fromMap(Map<String, dynamic> json) {
    return TextConstructor(
      text               : json[JrfTextConstructor.text],
      objects            : objectListFromMapList<WordObject>(WordObject.fromMap, json[JrfTextConstructor.objects]),
      styles             : valueListFromMapList<String>(json[JrfTextConstructor.styles]),
      markStyle          : json[JrfTextConstructor.markStyle],
      basement           : valueListFromMapList<String>(json[JrfTextConstructor.basement]),
      canMoveWord        : json[JrfTextConstructor.canMoveWord],
      randomMixWord      : json[JrfTextConstructor.randomMixWord],
      randomView         : json[JrfTextConstructor.randomView],
      notDelFromBasement : json[JrfTextConstructor.notDelFromBasement],
    );
  }

  Map<String, dynamic> toJson() => {
    JrfTextConstructor.text               :text,
    JrfTextConstructor.objects            :objects,
    JrfTextConstructor.styles             :styles,
    JrfTextConstructor.markStyle          :markStyle,
    JrfTextConstructor.basement           :basement,
    JrfTextConstructor.canMoveWord        :canMoveWord,
    JrfTextConstructor.randomMixWord      :randomMixWord,
    JrfTextConstructor.randomView         :randomView,
    JrfTextConstructor.notDelFromBasement :notDelFromBasement,
  };
}

class WordObject {
  final String name;
  final int viewIndex;
  final List<String> views;

  WordObject({
    required this.name,
    required this.viewIndex,
    required this.views
  });

  factory WordObject.fromMap(Map<String, dynamic> json) {
    return WordObject(
      name      : json[JtfWordObject.name],
      viewIndex : json[JtfWordObject.viewIndex]??0,
      views     : valueListFromMapList<String>(json[JtfWordObject.views]),
    );
  }

  Map<String, dynamic> toJson() => {
    JtfWordObject.name      :name,
    JtfWordObject.viewIndex :viewIndex,
    JtfWordObject.views     :views,
  };
}

List<T> valueListFromMapList<T>(dynamic value) {
  if (value == null) return [];
  if (value is! List) return [];
  return List<T>.from(value.map((t) => t));
}

typedef CreateFromMap<T> = T Function(Map<String, dynamic>);

List<T> objectListFromMapList<T>(CreateFromMap<T> createFromMap, dynamic value) {
  if (value == null) return [];
  if (value is! List) return [];

  return List<T>.from(value.map((tMap) => createFromMap.call(tMap) ));
}
