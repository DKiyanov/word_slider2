import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class DragBoxInfo{
  final DrawBox boxWidget;
  Size size = Size.zero;
  Rect rect = Rect.zero;
  bool isGroup = false;
  DragBoxInfo(this.boxWidget, [this.isGroup = false]);
}

GlobalKey<DrawBoxState> drawBoxKey(DrawBox drawBox){
  return drawBox.key as GlobalKey<DrawBoxState>;
}

class WordGrid extends StatefulWidget {
  final String         text;
  final DrawBoxBuilder onDrawBoxBuild;
  final DrawBoxTap?    onDrawBoxTap;
  final double         lineSpacing; // line spacing

  const WordGrid({required this.text, required this.onDrawBoxBuild, this.onDrawBoxTap, this.lineSpacing = 5, Key? key}) : super(key: key);

  @override
  State<WordGrid> createState() => _WordGridState();
}

class _WordGridState extends State<WordGrid> {
  final _stackKey = GlobalKey();
  bool _starting = true;
  final _boxInfoList = <DragBoxInfo>[];
  bool _rebuildStrNeed = false;

  double _width = 0.0;
  double _height = 0.0;

  @override
  void initState() {
    super.initState();

    _setText(widget.text);
  }

  void _setText(String text){
    _boxInfoList.clear();

    final regexp = RegExp(r'<\|.*?\|>');
    final matches = regexp.allMatches(text);

    int pos = 0;
    for (var element in matches) {
      if (element.start > pos) {
        final prevText = text.substring(pos, element.start);
        _addText(prevText);
      }

      final groupWord = text.substring(element.start+2, element.end-2);
      _boxInfoList.add(
        DragBoxInfo(
          DrawBox(
              label  : groupWord,
              onBuild: _groupHead,
              key    : GlobalKey<DrawBoxState>()
          ),
          true
        )
      );

      pos = element.end;
    }

    final endText = text.substring(pos);
    _addText(endText);

    _rebuildStrNeed = true;
  }

  void _addText(String str) {
    final wordList = <String>[];

    final subStrList = str.split('"');

    bool solid = false;

    for (var subStr in subStrList) {
      if (solid) {
        wordList.add(subStr);
      } else {
        wordList.addAll(subStr.split(' '));
      }

      solid = !solid;
    }

    for (var word in wordList) {
      if (word.isNotEmpty) {
        _boxInfoList.add(
            DragBoxInfo(
                DrawBox(
                    label        : word,
                    onBuild      : widget.onDrawBoxBuild,
                    key          : GlobalKey<DrawBoxState>()
                )
            )
        );
      }
    }
  }

  void _rebuildStr(double width){
    if (!_rebuildStrNeed) {
      if (_width != width) {
        _rebuildStrNeed = true;
        _width = width;
        _starting = true;
      }
    }

    if (_rebuildStrNeed) {
      _rebuildStrNeed = false;
      _putBoxesInPlaces(width);
    }
  }

  void _putBoxesInPlaces(double panelWidth){
    for (var boxInfo in _boxInfoList) {
      final boxKey = drawBoxKey(boxInfo.boxWidget);

      final renderBox = boxKey.currentContext!.findRenderObject() as RenderBox;
      boxInfo.size = renderBox.size;
    }

    _height = 0.0;

    if (!_boxInfoList.first.isGroup) {
      _putBoxesGroup(0, panelWidth);
    }

    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      if (!boxInfo.isGroup) continue;

      final boxKey = drawBoxKey(boxInfo.boxWidget);
      boxKey.currentState!.setState((){
        boxKey.currentState!.position = Offset(panelWidth / 2 - boxInfo.size.width / 2, _height);
      });

      _height += boxInfo.size.height;

      _putBoxesGroup(i + 1, panelWidth);
    }
  }

  void _putBoxesGroup(int fromIndex, double panelWidth) {
    // цель добиться минимального количества строк при максимальной ширине столбцов
    // и по возможности таблице подобного отображения
    // сильно длинные слова могут занимать несколько ячеек

    // рассчитываем среднюю и максимальную ширину столбца (слова)
    // далее двигаеся с небольшим икриментом от средней к максимальной
    // ловим минимальное количеств строк

    int toIndex = 0;
    int count = 0;
    double maxWidth = 0.0;
    double midWidth = 0.0;

    for (var i = fromIndex; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      if (boxInfo.isGroup) {
        toIndex = i - 1;
        break;
      }

      if (maxWidth < boxInfo.size.width) {
        maxWidth = boxInfo.size.width;
      }

      midWidth += boxInfo.size.width;
      count ++;
    }

    if (count == 0) return;

    if (toIndex == 0) {
      toIndex = _boxInfoList.length - 1;
    }

    midWidth = midWidth / count;

    if (maxWidth > panelWidth) {
      maxWidth = panelWidth;
    }

    int bestLineCount = 100000000;
    double bestColumnWidth = 0.0;

    for (double columnWidth = midWidth; columnWidth <= maxWidth; columnWidth ++) {
      final lineCount = _getGroupLineCount(fromIndex, toIndex, columnWidth, panelWidth);

      if (bestLineCount >= lineCount) {
        bestLineCount   = lineCount;
        bestColumnWidth = columnWidth;
      }
    }

    final columnCount = panelWidth ~/ bestColumnWidth;
    bestColumnWidth = panelWidth / columnCount;
//    bestColumnWidth --;

    _putBoxesGroupOk(fromIndex, toIndex, bestColumnWidth, panelWidth);
  }

  double _getBoxGridWidth(double boxWidth, double columnWidth, double panelWidth) {
    double boxGridWidth = 0.0;

    if (boxWidth <= columnWidth) {
      boxGridWidth = columnWidth;
    } else {
      boxGridWidth = (boxWidth ~/ columnWidth) * columnWidth;
      if (boxGridWidth < boxWidth) {
        boxGridWidth += columnWidth;
      }

      if (boxGridWidth > panelWidth) {
        boxGridWidth = panelWidth;
      }
    }

    return boxGridWidth;
  }

  void _putBoxesGroupOk(int fromIndex, int toIndex, double columnWidth, double panelWidth) {
    var position = Offset(0, _height);
    Offset nextPosition;

    double lineHeight = 0.0;

    for (var i = fromIndex; i <= toIndex; i++) {
      final boxInfo = _boxInfoList[i];

      final boxWidth = _getBoxGridWidth(boxInfo.size.width, columnWidth, panelWidth);

      if (lineHeight < boxInfo.size.height) {
        lineHeight = boxInfo.size.height;
      }

      nextPosition = Offset(position.dx + boxWidth, position.dy);
      if (nextPosition.dx > panelWidth){
        position = Offset(0, position.dy + lineHeight + widget.lineSpacing);
        nextPosition = Offset(position.dx + boxWidth, position.dy);

        if (i < toIndex) {
          lineHeight = 0.0;
        }
      }

      final boxKey = drawBoxKey(boxInfo.boxWidget);
      boxKey.currentState!.setState((){
        boxInfo.rect = Rect.fromLTWH(position.dx, position.dy, boxInfo.size.width, boxInfo.size.height);
        boxKey.currentState!.position = position;
      });

      position = nextPosition;
    }

    _height = position.dy + lineHeight;
  }

  int _getGroupLineCount(int fromIndex, int toIndex, double columnWidth, double panelWidth) {
    int lineCount = 1;

    double lineWidth = 0;

    for (var i = fromIndex; i <= toIndex; i++) {
      final boxInfo = _boxInfoList[i];

      final boxWidth = _getBoxGridWidth(boxInfo.size.width, columnWidth, panelWidth);

      lineWidth += boxWidth;

      if (lineWidth > panelWidth) {
        lineCount ++;
        lineWidth = boxWidth;
      }
    }

    return lineCount;
  }

  @override
  Widget build(BuildContext context) {
    final childList = _boxInfoList.map((boxInfo)=>boxInfo.boxWidget).toList();

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {

        WidgetsBinding.instance.addPostFrameCallback((_){
          _rebuildStr(viewportConstraints.maxWidth);

          if (_starting) {
            setState(() {
              _starting = false;
            });
          }
        });

        if (_starting) {
          return Offstage(
            child: Stack(
              children: childList,
            ),
          );
        }

        return SingleChildScrollView(
          child: GestureDetector(
            onTapUp: (details) => _onTapUp(details),
            child: SizedBox(
              width: _width,
              height: _height,

              child: Stack(
                key : _stackKey,
                children: childList,
              ),
            ),
          ),
        );
      },
    );
  }

  RenderBox _getStackRenderBox(){
    return _stackKey.currentContext!.findRenderObject() as RenderBox;
  }

  DragBoxInfo? getBoxAtPos(Offset globalPosition) {
    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(globalPosition);

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    return boxInfo;
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    if (widget.onDrawBoxTap == null) return;
    final boxInfo = getBoxAtPos(details.globalPosition);
    if (boxInfo == null) return;

    widget.onDrawBoxTap!.call(boxInfo.boxWidget.label, boxInfo.rect.topLeft);
  }

  Widget _groupHead(BuildContext context, String label) {
    return Text(label);
  }
}

typedef DrawBoxBuilder = Widget Function(BuildContext context, String label);
typedef DrawBoxTap = Future<bool?> Function(String label, Offset position);

class DrawBox extends StatefulWidget {
  final String label;
  final DrawBoxBuilder onBuild;

  const DrawBox({this.label = '', required this.onBuild, Key? key})  : super(key: key);

  @override
  State<DrawBox> createState() => DrawBoxState();
}

class DrawBoxState extends State<DrawBox> {
  Offset position  = const Offset(0.0, 0.0);
  bool   visible   = true;

  @override
  Widget build(BuildContext context) {
    if (!visible){
      return Positioned(
          left: 0,
          top: 0,
          child: Container()
      );
    }

    return  Positioned(
        left  : position.dx,
        top   : position.dy,
        child: widget.onBuild.call(context, widget.label)
    );
  }
}