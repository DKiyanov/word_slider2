import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:word_slider2/word_grid.dart';
import 'package:word_slider2/word_panel.dart';
import 'package:word_slider2/word_panel_model.dart';
import 'package:simple_events/simple_events.dart';

String _txtDialogInputText = 'Введите текст';

class TextConstructorWidget extends StatefulWidget {
  final TextConstructorData textConstructor;
  const TextConstructorWidget({required this.textConstructor, Key? key}) : super(key: key);

  @override
  State<TextConstructorWidget> createState() => _TextConstructorWidgetState();
}

class _TextConstructorWidgetState extends State<TextConstructorWidget> {
  static const String wordKeyboard = '@keyboard';

  late TextConstructorData _textConstructorData;
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
  final double _basementMinHeight = 200;

  final Map<String, Color> _colorMap = {
    'r' : Colors.red,
    'g' : Colors.green,
    'b' : Colors.blue,
    'y' : Colors.yellow,
    'o' : Colors.orange,
  };

  final _historyList = <String>[];
  bool _historyRecordOn = true;
  int _historyPos = -1;

  final _toolBarRefresh = SimpleEvent();

  bool   _starting = true;
  double _panelHeight = 0.0;
  double _basementHeight = 0.0;

  @override
  void initState() {
    super.initState();

    _textConstructorData = widget.textConstructor; //TextConstructorData.fromMap(jsonDecode(textConstructorJson));

    _controller = WordPanelController(
      text          : _textConstructorData.text,
      onChange      : _onChange,
      canMoveWord   : _textConstructorData.canMoveWord,
      noCursor      : _textConstructorData.noCursor,
      focusAsCursor : _textConstructorData.focusAsCursor,
    );
  }

  void _onChange() {
    if (!_historyRecordOn) return;

    if (_historyPos >= 0) {
      _historyList.removeRange(_historyPos + 1, _historyList.length);
      _historyPos = -1;
    }

    _historyList.add(_controller.text);
    _toolBarRefresh.send();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      WidgetsBinding.instance.addPostFrameCallback((_){
        if (_starting) {
          setState(() {
            _starting = false;
          });
        }
      });

      if (_starting) {
        return Offstage(
          child: startBody(),
        );
      }

      return body(viewportConstraints);
    });

  }

  Widget body(BoxConstraints viewportConstraints) {

    if (_textConstructorData.basement.isEmpty || _basementHeight == 0.0) {
      return Column(
        children: [

          toolbar(),

          Expanded(
            child: wordPanel(),
          ),

        ],
      );
    }

    var panelHeight = _panelHeight;

    if (panelHeight > (viewportConstraints.maxHeight - _basementMinHeight)) {
      panelHeight = viewportConstraints.maxHeight - _basementMinHeight;
    }

    return Column(
      children: [

        SizedBox(
          height: panelHeight,
          child: wordPanel(),
        ),

        toolbar(),

        Expanded(
            child: basement()
        ),

      ],
    );
  }

  Widget startBody() {
    return Column(
      children: [

        SizedBox(
          height: 100,
          child: wordPanel(),
        ),

        SizedBox(
            height: 100,
            child: basement()
        ),

      ],
    );
  }

  Widget wordPanel() {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: WordPanel(
        controller         : _controller,
        onDragBoxBuild     : onDragBoxBuild,
        onDragBoxTap       : onDragBoxTap,
        onDragBoxLongPress : onDragBoxLongPress,
        onDoubleTap        : onDragBoxLongPress,
        onChangeHeight     : (double newHeight) {
          final newPanelHeight = newHeight + 12 + _controller.wordBoxHeight;
          if (_panelHeight != newPanelHeight) {
            setState(() {
              _panelHeight = newPanelHeight;
            });
          }
        },
      ),
    );
  }

  Widget basement() {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: WordGrid(
        text           : _textConstructorData.basement,
        onDrawBoxBuild : onBasementBoxBuild,
        onDrawBoxTap   : onBasementBoxTap,
        onChangeHeight : (double newHeight) {
          if (_basementHeight != newHeight) {
            setState(() {
              _basementHeight = newHeight;
            });
          }
        },
      ),
    );
  }

  Widget toolbar() {
    return  EventReceiverWidget(
        events: [_toolBarRefresh],
        builder: (BuildContext context) {
          return BottomAppBar(
              color: Colors.blue,
              child: IconTheme(
                data: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [

                  if (_textConstructorData.btnKeyboard) ...[
                    IconButton(
                      onPressed: () async {
                        final word = await wordInputDialog(context);
                        if (word.isEmpty) return;

                        final pos = _controller.getCursorPos(lastPostIfNot: true);
                        _controller.insertWord(pos, word);
                        _controller.refreshPanel();
                      },
                      icon: const Icon(Icons.keyboard_alt_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnUndo) ...[
                    IconButton(
                      onPressed: (_historyPos == 0 || _historyList.length == 1) ? null : (){
                        if (_historyPos < 0) {
                          _historyPos = _historyList.length - 2;
                        } else {
                          _historyPos --;
                        }

                        _historyRecordOn = false;
                        _controller.text = _historyList[_historyPos];
                        _historyRecordOn = true;

                        _toolBarRefresh.send();
                      },
                      icon: const Icon(Icons.undo_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnRedo) ...[
                    IconButton(
                      onPressed: (_historyPos < 0 || _historyPos == (_historyList.length - 1) ) ? null : (){
                        _historyPos ++;
                        _historyRecordOn = false;
                        _controller.text = _historyList[_historyPos];
                        _historyRecordOn = true;

                        _toolBarRefresh.send();
                      },
                      icon: const Icon(Icons.redo_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnBackspace) ...[
                    IconButton(
                      onPressed: ()=> deleteWord(-1),
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnDelete) ...[
                    IconButton(
                      onPressed: ()=> deleteWord(),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],

                  if (_textConstructorData.btnClear) ...[
                    IconButton(
                      onPressed: (){
                        _controller.text = '';
                      },
                      icon: const Icon(Icons.clear_outlined),
                    ),
                  ],

                  IconButton(
                    onPressed: (){

                    },
                    icon: const Icon(Icons.check, color: Colors.lightGreenAccent),
                  ),

                ]),
              )
          );
        }
    );
  }

  void deleteWord([int posAdd = 0]){
    bool cursor = true;
    var pos = _controller.getCursorPos(onlyCursor: true);

    if (pos < 0) {
      cursor = false;
      pos = _controller.getFocusPos();
      if (pos < 0) return;
    }

    pos += posAdd;

    if (pos < 0) return;

    _controller.deleteWord(pos);
    _controller.refreshPanel();

    if (cursor) {
      _controller.setCursorPos(pos);
    } else {
      _controller.setFocusPos(pos);
    }
  }


  Future<String?> onDragBoxTap(String label, Offset position) async {
    if (label.isEmpty) return label;

    if (label == wordKeyboard) {
      final inputValue = await wordInputDialog(context);
      if (inputValue.isEmpty) return null;
      return inputValue;
    }

    if (_textConstructorData.markStyle >= 0){
      if (label.substring(0, 1) == '\$') {
        label = label.substring(1);
      } else {
        label = '\$$label';
      }
    }

    return label;
  }

  Future<String?> onDragBoxLongPress(String label, Offset position) async {
    return showPopupMenu(label, position);
  }

  Widget editPos() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        color: _editPosColor,
      ),
      width: _editPosWidth,
      height: _controller.wordBoxHeight,
    );
  }

  Widget insertPos() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        color: _insertPosColor,
      ),
      width: _insertPosWidth,
      height: _controller.wordBoxHeight,
    );
  }

  Widget onDragBoxBuild(BuildContext context, String label, DragBoxSpec spec) {
    if (spec == DragBoxSpec.editPos){
      return editPos();
    }

    if (spec == DragBoxSpec.insertPos){
      return insertPos();
    }

    return labelWidget(context, label, spec);
  }

  Widget onBasementBoxBuild(BuildContext context, String label) {
    return labelWidget(context, label, DragBoxSpec.none);
  }

  double internalBoxHeight() {
    if (_controller.wordBoxHeight == 0.0) return 20.0;
    return _controller.wordBoxHeight - 2;
  }

  Widget labelWidget(BuildContext context, String label, DragBoxSpec spec) {
    if (label.isEmpty) return Container();

    if (label == wordKeyboard) {
      return makeDecoration(
        child           : SizedBox(
          height : internalBoxHeight(),
          child  : const Icon(Icons.keyboard_alt_outlined, color: Colors.white)
        ),
        borderColor     : _borderColor,
        borderWidth     : _borderWidth,
        backgroundColor : _colorWordNormal,
      );
    }

    var viewIndex = -1;

    int? styleIndex;

    if (label.substring(0, 1) == '\$' && _textConstructorData.markStyle >= 0) {
      styleIndex = _textConstructorData.markStyle;
      label = label.substring(1);
    }

    if (label.substring(0, 1) == '#') {
      String objectName;
      if (label.substring(2,3) == '|') {
        objectName = label.substring(3);
        viewIndex = int.parse(label.substring(1,2));
      } else {
        objectName = label.substring(1);
      }

      final wordObject = _textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;

      if (viewIndex < 0) {
        viewIndex = wordObject.viewIndex;
      }

      final viewStr = wordObject.views[viewIndex];

      return getObjectViewWidget(context, objectName: objectName, viewStr: viewStr, styleIndex: styleIndex, spec: spec );
    }

    return getObjectViewWidget(context, label: label, styleIndex: styleIndex, spec : spec );
  }

  Widget getObjectViewWidget(BuildContext context, {
    String      label      = '',
    String      objectName = '',
    String      viewStr    = '',
    int?        styleIndex ,
    DragBoxSpec spec       = DragBoxSpec.none,
    bool        forPopup   = false
  }) {
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

    var localStyleIndex = -1;

    if (objectName.isNotEmpty) {
      final viewSplit1 = viewStr.split('|');
      if (viewSplit1.length == 1) {
        outStr = viewSplit1[0];
      } else {
        outStr = viewSplit1[1];

        final viewSplit2 = viewSplit1[0].split('/');
        final styleIndexStr = viewSplit2[0];
        if (styleIndexStr.isNotEmpty) {
          localStyleIndex = int.parse(styleIndexStr);
        }
        if (viewSplit2.length > 1) {
          menuText = viewSplit2[1];
        }
      }

      if (outStr.isEmpty) {
        outStr = objectName;
      }
    }

    if (styleIndex != null) {
      localStyleIndex = styleIndex;
    }

    if (localStyleIndex >= 0) {
      final styleStr = _textConstructorData.styles[localStyleIndex];
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

    final retWidget = Container(
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
      return makeDecoration(
        child           : retWidget,
        borderColor     : _borderColor,
        borderWidth     : _borderWidth,
        backgroundColor : backgroundColor,
      );
    }

    return makeDecoration(
      child           : retWidget,
      borderColor     : borderColor,
      borderWidth     : borderWidth,
      backgroundColor : backgroundColor,
    );
  }

  Widget makeDecoration({
    required Widget child,
    required Color  borderColor,
    required double borderWidth,
    required Color  backgroundColor,
  }){
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
      child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: child
      ),
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

    final wordObject = _textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;

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

  Future<bool?> onBasementBoxTap(String label, Offset position) async {
    final curPos = _controller.getCursorPos(lastPostIfNot: true);
    _controller.insertWord(curPos, label);
    _controller.refreshPanel();
    return false;
  }

  Future<String> wordInputDialog(BuildContext context) async {
    final textController = TextEditingController();
    String  word = '';

    final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(_txtDialogInputText),
            content: TextField(
              onChanged: (value) {
                word = value;
              },
              controller: textController,
            ),
            actions: <Widget>[
              IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
                word = '';
                Navigator.pop(context, false);
              }),

              IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: () {
                Navigator.pop(context, true);
              }),

            ],
          );
        });

    if (result != null && result) return word;

    return '';
  }

}
