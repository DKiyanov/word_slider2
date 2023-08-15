import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:word_slider2/text_constructor.dart';
import 'package:word_slider2/word_panel_model.dart';

void main() => runApp(MyApp());

const String textConstructorJson = '''
{
   "text" : "начальный текст в конструкторе @keyboard #0|символ",
   "basement" : "<|G1|>на 'ч аль' ны й ~текст <|G2|>в конструкторе, #0|символ",
   
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
   "markStyle" : 3,
   
   "randomMixWord" : false,
   "randomView" : false,
   "notDelFromBasement" : false,
   
   "canMoveWord"   : true,
   "noCursor"      : false,
   "focusAsCursor" : true,
   
   "btnKeyboard"  : true,
   "btnUndo"      : true,
   "btnRedo"      : true,
   "btnBackspace" : true,
   "btnDelete"    : true,
   "btnClear"     : true
}
''';

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final TextConstructorData _textConstructor = TextConstructorData.fromMap(jsonDecode(textConstructorJson));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Demo Home Page'),
        ),

        body: TextConstructorWidget(textConstructor : _textConstructor),
      ),
    );
  }
}
