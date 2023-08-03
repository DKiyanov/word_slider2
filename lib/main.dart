import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:word_slider2/word_grid.dart';
import 'package:word_slider2/word_panel.dart';
import 'package:word_slider2/word_panel_model.dart';

void main() => runApp(const MyApp());

const String textConstructorJson = '''
{
   "text" : "начальный текст в конструкторе, #0|символ",
   
   "objects": [
   
     {
      "name" :  "символ",
      "viewIndex": 1,
      "views": ["2|", "3|"]
     },
     
     {
      "name" :  "объект-3",
      "viewIndex": 1,
      "views": ["2|вариант-3", "3|вариант-4"]
     }
     
   ],
   
   "styles": ["i", "b", "ccr,bcb", "ccb,bcr,l~g"], 
   "markStyle" : 1,
   "basement" : ["слово-1", "слово-2", "#объект-3" ],
   
   "canMoveWord" : true,
   "randomMixWord" : false,
   "randomView" : false,
   "notDelFromBasement" : false
}
''';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({required this.title, Key? key}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextConstructor _textConstructor;
  late WordPanelController _controller;

  final Color  _defaultTextColor  = Colors.white;
  final double _fontSize          = 40.0;
  final Color  _borderColor      = Colors.black;
  final double _borderWidth      = 1.0;
  final Color  _focusBorderColor  = Colors.blue;
  final double _focusBorderWidth  = 2.0;
  final Color  _editPosColor      = Colors.blue;
  final Color  _insertPosColor    = Colors.green;
  final Color  _colorWordNormal   = Colors.grey;
//  final Color  _colorWordSelected = Colors.yellow;
  final Color  _colorWordCanDrop  = Colors.amber;
  final Color  _colorWordMove     = Colors.black12;
  final double _editPosWidth      = 10;
  final double _insertPosWidth    = 10;
  
  final Map<String, Color> _colorMap = {
    'r' : Colors.red,
    'g' : Colors.green,
    'b' : Colors.blue,
    'y' : Colors.yellow,
    'o' : Colors.orange,
  };

  @override
  void initState() {
    super.initState();

    _textConstructor = TextConstructor.fromMap(jsonDecode(textConstructorJson));
    _controller = WordPanelController(text: _textConstructor.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.accessibility),
              onPressed: pressTest,
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: WordPanel(
                controller         : _controller,
                onDragBoxBuild     : onDragBoxBuild,
                onDragBoxTap       : onDragBoxTap,
                onDragBoxLongPress : onDragBoxLongPress,
                onDoubleTap        : onDragBoxLongPress,
              ),
            ),

            Expanded(
              child: WordGrid(
                text           : 'начальный текст в конструкторе, #0|символ',
                onDrawBoxBuild : onDrawBoxBuild,
              )
            ),
          ],
        )
    );
  }


  Future<String?> onDragBoxTap(String label, Offset position) async {
    return label;
    // boxState.color == colorWordNormal ? boxState.color = colorWordSelected : boxState.color = colorWordNormal;
  }

  Future<String?> onDragBoxLongPress(String label, Offset position) async {
     return showPopupMenu(label, position);
  }

  Widget editPos(Offset position) {
    return Positioned(
        left: position.dx,
        top: position.dy,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            color: _editPosColor,
          ),
          width: _editPosWidth,
          height: _controller.wordBoxHeight,
        )
    );
  }

  Widget insertPos(Offset position) {
    return Positioned(
        left: position.dx,
        top: position.dy,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            color: _insertPosColor,
          ),
          width: _insertPosWidth,
          height: _controller.wordBoxHeight,
        )
    );
  }

  Widget onDragBoxBuild(BuildContext context, String label, DragBoxSpec spec, Offset position) {
    if (spec == DragBoxSpec.editPos){
      return editPos(position);
    }

    if (spec == DragBoxSpec.insertPos){
      return insertPos(position);
    }

    return outLabel(context, label, spec, position);
  }

  Widget onDrawBoxBuild(BuildContext context, String label, Offset position) {
    return outLabel(context, label, DragBoxSpec.none, position);
  }

  Widget outLabel(BuildContext context, String label, DragBoxSpec spec, Offset position) {
    return Positioned(
        left  : position.dx,
        top   : position.dy,
        child : labelWidget(context, label, spec)
    );
  }

  Widget labelWidget(BuildContext context, String label, DragBoxSpec spec) {
    if (label.isEmpty) return Container();

    var viewIndex = -1;

    Widget widget;

    if (label.substring(0, 1) == '#') {
      String objectName;
      if (label.substring(2,3) == '|') {
        objectName = label.substring(3);
        viewIndex = int.parse(label.substring(1,2));
      } else {
        objectName = label.substring(1);
      }

      final wordObject = _textConstructor.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;

      if (viewIndex < 0) {
        viewIndex = wordObject.viewIndex;
      }

      final viewStr = wordObject.views[viewIndex];

      widget = getObjectViewWidget(context, objectName: objectName, viewStr: viewStr, spec: spec );
    } else {
      widget = getObjectViewWidget(context, label: label, spec : spec );
    }

    return widget;
  }

  Widget getObjectViewWidget(BuildContext context, {String label = '', String objectName = '', String viewStr = '', DragBoxSpec spec = DragBoxSpec.none, bool forPopup = false}) {
    var textStyleBold   = false;
    var textStyleItalic = false;

    var textColor       = _defaultTextColor;
    var backgroundColor = _colorWordNormal;

    var lineColor = Colors.black;
    var linePos   = TextDecoration.none;
    var lineStyle = TextDecorationStyle.solid;

    var borderColor = _borderColor;
    var borderWidth = _borderWidth;

    var menuText = '';

    var outStr = '';

    if (objectName.isNotEmpty) {
      var styleIndex = -1;

      final viewSplit1 = viewStr.split('|');
      if (viewSplit1.length == 1) {
        outStr = viewSplit1[0];
      } else {
        outStr = viewSplit1[1];

        final viewSplit2 = viewSplit1[0].split('/');
        final styleIndexStr = viewSplit2[0];
        if (styleIndexStr.isNotEmpty) {
          styleIndex = int.parse(styleIndexStr);
        }
        if (viewSplit2.length > 1) {
          menuText = viewSplit2[1];
        }
      }

      if (outStr.isEmpty) {
        outStr = objectName;
      }

      if (styleIndex >= 0) {
        final styleStr = _textConstructor.styles[styleIndex];
        final subStyleList = styleStr.split(',');

        for (var subStyle in subStyleList) {
          final subStyleStr = subStyle.trim().toLowerCase();
          final subStyleLen = subStyleStr.length;

          if (subStyleLen == 1) {
            if (subStyleStr == 'b') {
              textStyleBold = true;
            }
            if (subStyleStr == 'i') {
              textStyleItalic = true;
            }
          }

          if (subStyleLen == 3) {
            final formatCh = subStyleStr.substring(0,1);
            final formatId = subStyleStr.substring(0,2);
            final colorKey = subStyleStr.substring(2,3);

            if (formatId == 'cc') {
              textColor = _colorMap[colorKey]!;
            }
            if (formatId == 'bc') {
              backgroundColor = _colorMap[colorKey]!;
            }

            if (formatCh == 'l') {
              linePos = TextDecoration.underline;
              lineColor = _colorMap[colorKey]!;

              if (formatId == 'l_') {
                lineStyle = TextDecorationStyle.solid;
              }
              if (formatId == 'l~') {
                lineStyle = TextDecorationStyle.wavy;
              }
              if (formatId == 'l=') {
                lineStyle = TextDecorationStyle.double;
              }
              if (formatId == 'l-') {
                lineStyle = TextDecorationStyle.dashed;
              }
              if (formatId == 'l.') {
                lineStyle = TextDecorationStyle.dotted;
              }
            }

            if (formatCh == 'd') {
              linePos = TextDecoration.lineThrough;
              lineColor = _colorMap[colorKey]!;

              if (formatId == 'd=') {
                lineStyle = TextDecorationStyle.double;
              }
              if (formatId == 'd-') {
                lineStyle = TextDecorationStyle.solid;
              }
            }
          }

        }
      }
    }

    if (label.isNotEmpty) {
      outStr = label;
    }

    if (forPopup && menuText.isNotEmpty) {
      outStr = menuText;
    }

    if (spec == DragBoxSpec.move) {
      backgroundColor = _colorWordMove;
    }
    if (spec == DragBoxSpec.canDrop) {
      backgroundColor = _colorWordCanDrop;
    }
    if (spec == DragBoxSpec.focus) {
      borderColor = _focusBorderColor;
      borderWidth = _focusBorderWidth;
    }

    final widget = Container(
      color: backgroundColor,
      child: Text(
        outStr,
        style: TextStyle(
          color: textColor,

          decoration     : linePos,
          decorationColor: lineColor,
          decorationStyle: lineStyle,

          fontSize: _fontSize,
          fontWeight: textStyleBold? FontWeight.bold : null,
          fontStyle: textStyleItalic? FontStyle.italic : null,
        ),
      ),
    );

    if (forPopup) {
      return  Container(
        padding: const EdgeInsets.only(left: 10, right: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: _borderColor,
            width: _borderWidth,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          color: backgroundColor,
        ),
        child: widget,
      );
    }

    return  Container(
      padding: const EdgeInsets.only(left: 10, right: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        color: backgroundColor,
      ),
      child: widget,
    );

  }

  Future<String?> showPopupMenu(String label, Offset position) async {
    if (label.isEmpty) return null;
    if (label.substring(0, 1) != '#') return null;

    String objectName;
    if (label.substring(2,3) == '|') {
      objectName = label.substring(3);
    } else {
      objectName = label.substring(1);
    }

    final wordObject = _textConstructor.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;

    final popupItems = <PopupMenuEntry<String>>[];

    for ( var i = 0; i < wordObject.views.length; i++ ) {
      final viewStr = wordObject.views[i];
      popupItems.add( PopupMenuItem(
        value: '#$i|$objectName',
        padding: EdgeInsets.zero,
        child: Center(child: getObjectViewWidget(context, objectName: objectName, viewStr: viewStr, forPopup: true))
      ));
    }

    final value = await showMenu<String>(
      context  : context,
      position : RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items    : popupItems,
      shape: const RoundedRectangleBorder( borderRadius: BorderRadius.all(Radius.circular(5)) ),
    );

    return value;
  }

  void pressTest(){
    final curPos = _controller.getCursorPos();
    _controller.deleteWord(curPos);
    _controller.insertText(curPos, '123 456');
    _controller.refreshPanel();
  }
}
