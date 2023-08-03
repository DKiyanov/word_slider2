import 'package:flutter/material.dart';


GlobalKey<DrawBoxState> drawBoxKey(DrawBox drawBox){
  return drawBox.key as GlobalKey<DrawBoxState>;
}

class WordGrid extends StatefulWidget {
  final String         text;
  final DrawBoxBuilder onDrawBoxBuild;
  final double         lineSpacing; // line spacing

  const WordGrid({required this.text, required this.onDrawBoxBuild, this.lineSpacing = 5, Key? key}) : super(key: key);

  @override
  State<WordGrid> createState() => _WordGridState();
}

class _WordGridState extends State<WordGrid> {
  bool _starting = true;
  final _drawBoxList = <DrawBox>[];
  bool _rebuildStrNeed = false;

  double _width = 0.0;
  double _height = 0.0;

  double wordBoxHeight = 0;

  @override
  void initState() {
    super.initState();

    _setText(widget.text);
  }

  void _setText(String text){
    _drawBoxList.clear();

    text.split(' ').forEach((word){
      _drawBoxList.add(DrawBox(label: word, onBuild: widget.onDrawBoxBuild, key: GlobalKey<DrawBoxState>()));
    });

    _rebuildStrNeed = true;
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
      _buildBoxesString(width);
    }
  }

  void _buildBoxesString(double width){
    wordBoxHeight = 0;

    var position = const Offset(0,0);
    Offset nextPosition;

    for (var i = 0; i < _drawBoxList.length; i++) {
      final drawBox = _drawBoxList[i];
      final boxKey = drawBoxKey(drawBox);

      final renderBox = boxKey.currentContext!.findRenderObject() as RenderBox;

      if (wordBoxHeight == 0.0) {
        wordBoxHeight = renderBox.size.height;
        _height = wordBoxHeight;
      }

      nextPosition = Offset(position.dx + renderBox.size.width, position.dy);
      if (nextPosition.dx >= width){
        position = Offset(0, position.dy + wordBoxHeight + widget.lineSpacing);
        nextPosition = Offset(position.dx + renderBox.size.width, position.dy);
        _height = position.dy + wordBoxHeight;
      }

      boxKey.currentState!.setState((){
        boxKey.currentState!.position = position;
      });

      position = nextPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    final childList = _drawBoxList.map((drawBox)=>drawBox).toList();

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
          child: SizedBox(
            width: _width,
            height: _height,

            child: Stack(
              children: childList,
            ),
          ),
        );
      },
    );
  }
}

typedef DrawBoxBuilder = Widget Function(BuildContext context, String label, Offset position);
typedef DrawBoxTap = Future<String?> Function(String label, Offset position);

class DrawBox extends StatefulWidget {
  final String label;
  final DrawBoxBuilder onBuild;

  const DrawBox({this.label = '', required this.onBuild, Key? key})  : super(key: key);

  @override
  State<DrawBox> createState() => DrawBoxState();
}

class DrawBoxState extends State<DrawBox> {
  Offset position  = const Offset(0.0, 0.0);
  String label     = '';
  bool   visible   = true;

  @override
  void initState() {
    super.initState();

    label = widget.label;
  }

  @override
  Widget build(BuildContext context) {
    if (!visible){
      return Positioned(
          left: 0,
          top: 0,
          child: Container()
      );
    }

    return widget.onBuild.call(context, label, position);
  }
}