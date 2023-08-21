class JrfTextConstructor {
  static const String text               = 'text';
  static const String objects            = 'objects';
  static const String styles             = 'styles';
  static const String markStyle          = 'markStyle';
  static const String basement           = 'basement';
  static const String randomMixWord      = 'randomMixWord';
  static const String randomView         = 'randomView';
  static const String notDelFromBasement = 'notDelFromBasement';
  static const String canMoveWord        = 'canMoveWord';
  static const String noCursor           = 'noCursor';
  static const String focusAsCursor      = 'focusAsCursor';

  static const String btnKeyboard        = 'btnKeyboard';
  static const String btnUndo            = 'btnUndo';
  static const String btnRedo            = 'btnRedo';
  static const String btnBackspace       = 'btnBackspace';
  static const String btnDelete          = 'btnDelete';
  static const String btnClear           = 'btnClear';
}

class JtfWordObject {
  static const String name         = 'name';
  static const String viewIndex    = 'viewIndex';
  static const String nonRemovable = 'nonRemovabl';
  static const String views        = 'views';
}

class TextConstructorData {
  final String text;
  final List<WordObject> objects;
  final List<String> styles;
  final int markStyle;
  final String basement;
  final bool canMoveWord;
  final bool randomMixWord;
  final bool randomView;
  final bool notDelFromBasement;
  final bool noCursor;
  final bool focusAsCursor;

  final bool btnKeyboard ;
  final bool btnUndo     ;
  final bool btnRedo     ;
  final bool btnBackspace;
  final bool btnDelete   ;
  final bool btnClear    ;

  TextConstructorData({
    required this.text,
    required this.objects,
    required this.styles,
    required this.markStyle,
    required this.basement,
    required this.randomMixWord,
    required this.randomView,
    required this.notDelFromBasement,
    this.canMoveWord   = true,
    this.noCursor      = false,
    this.focusAsCursor = true,

    this.btnKeyboard  = true,
    this.btnUndo      = true,
    this.btnRedo      = true,
    this.btnBackspace = true,
    this.btnDelete    = true,
    this.btnClear     = true,
  });

  factory TextConstructorData.fromMap(Map<String, dynamic> json) {
    return TextConstructorData(
      text               : json[JrfTextConstructor.text],
      objects            : objectListFromMapList<WordObject>(WordObject.fromMap, json[JrfTextConstructor.objects]),
      styles             : valueListFromMapList<String>(json[JrfTextConstructor.styles]),
      markStyle          : json[JrfTextConstructor.markStyle]??-1,
      basement           : json[JrfTextConstructor.basement]??'',
      randomMixWord      : json[JrfTextConstructor.randomMixWord]??false,
      randomView         : json[JrfTextConstructor.randomView]??false,
      notDelFromBasement : json[JrfTextConstructor.notDelFromBasement]??false,
      canMoveWord        : json[JrfTextConstructor.canMoveWord]??true,
      noCursor           : json[JrfTextConstructor.noCursor]??false,
      focusAsCursor      : json[JrfTextConstructor.focusAsCursor]??true,

      btnKeyboard        : json[JrfTextConstructor.btnKeyboard ]??true,
      btnUndo            : json[JrfTextConstructor.btnUndo     ]??true,
      btnRedo            : json[JrfTextConstructor.btnRedo     ]??true,
      btnBackspace       : json[JrfTextConstructor.btnBackspace]??true,
      btnDelete          : json[JrfTextConstructor.btnDelete   ]??true,
      btnClear           : json[JrfTextConstructor.btnClear    ]??true,

    );
  }

  Map<String, dynamic> toJson() => {
    JrfTextConstructor.text               :text,
    JrfTextConstructor.objects            :objects,
    JrfTextConstructor.styles             :styles,
    JrfTextConstructor.markStyle          :markStyle,
    JrfTextConstructor.basement           :basement,
    JrfTextConstructor.randomMixWord      :randomMixWord,
    JrfTextConstructor.randomView         :randomView,
    JrfTextConstructor.notDelFromBasement :notDelFromBasement,
    JrfTextConstructor.canMoveWord        :canMoveWord,
    JrfTextConstructor.noCursor           :noCursor,
    JrfTextConstructor.focusAsCursor      :focusAsCursor,

    JrfTextConstructor.btnKeyboard        :btnKeyboard ,
    JrfTextConstructor.btnUndo            :btnUndo     ,
    JrfTextConstructor.btnRedo            :btnRedo     ,
    JrfTextConstructor.btnBackspace       :btnBackspace,
    JrfTextConstructor.btnDelete          :btnDelete   ,
    JrfTextConstructor.btnClear           :btnClear    ,
  };
}

class WordObject {
  final String name;
  final int viewIndex;
  final bool nonRemovable;
  final List<String> views;

  WordObject({
    required this.name,
    required this.viewIndex,
    required this.nonRemovable,
    required this.views
  });

  factory WordObject.fromMap(Map<String, dynamic> json) {
    return WordObject(
      name         : json[JtfWordObject.name],
      viewIndex    : json[JtfWordObject.viewIndex]??0,
      nonRemovable : json[JtfWordObject.nonRemovable]??false,
      views        : valueListFromMapList<String>(json[JtfWordObject.views]),
    );
  }

  Map<String, dynamic> toJson() => {
    JtfWordObject.name      :name,
    JtfWordObject.viewIndex :viewIndex,
    JtfWordObject.nonRemovable :nonRemovable,
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
