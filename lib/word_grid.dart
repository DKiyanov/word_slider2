import 'package:flutter/material.dart';


class DrawBoxInfo{
  final DrawBox boxWidget;
  Rect rect = Rect.zero;
  DrawBoxInfo(this.boxWidget);
}

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
  final _stackKey = GlobalKey();
  final _boxInfoList = <DrawBoxInfo>[];
  bool _rebuildStrNeed = false;

  Size? _prevStackSize;

  double wordBoxHeight = 0;
  
  @override
  void initState() {
    super.initState();
    
    _setText(widget.text);
  }

  void _setText(String text){
    _boxInfoList.clear();

    text.split(' ').forEach((word){
      _boxInfoList.add(DrawBoxInfo(DrawBox(label: word, onBuild: widget.onDrawBoxBuild, key: GlobalKey<DrawBoxState>())));
    });
    
    _rebuildStrNeed = true;
  }

  void _rebuildStr(){
    if (!_rebuildStrNeed) {
      // We check if the dimensions of the panel have changed, if they have changed - the line needs to be rebuilt
      final stackSize = _getStackRenderBox().size;
      if (_prevStackSize != null) {
        if (stackSize.width != _prevStackSize!.width || stackSize.height != _prevStackSize!.height){
          _rebuildStrNeed = true;
        }
      }
      _prevStackSize = stackSize;
    }

    if (_rebuildStrNeed) {
      _rebuildStrNeed = false;
      _getBoxesRect();
      _buildBoxesString();
    }
  }

  RenderBox _getStackRenderBox(){
    return _stackKey.currentContext!.findRenderObject() as RenderBox;
  }

  RenderBox _getDrawBoxRenderBox(DrawBox drawBox){
    return drawBoxKey(drawBox).currentContext!.findRenderObject() as RenderBox;
  }

  void _getBoxesRect(){
    final renderBox = _getStackRenderBox();

    for (var boxInfo in _boxInfoList) {
      final boxRenderBox = _getDrawBoxRenderBox(boxInfo.boxWidget);
      final boxSize = boxRenderBox.size;
      final boxPos  = renderBox.globalToLocal(boxRenderBox.localToGlobal(Offset.zero));
      boxInfo.rect = Rect.fromLTWH(boxPos.dx, boxPos.dy, boxSize.width, boxSize.height);
    }
  }

  void _buildBoxesString(){
    wordBoxHeight = 0;
    for (var boxInfo in _boxInfoList) {
      if (wordBoxHeight < boxInfo.rect.height ) {
        wordBoxHeight = boxInfo.rect.height;
      }
    }

    final stackSize = _getStackRenderBox().size;
    var position = const Offset(0,0);
    Offset nextPosition;

    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      final boxKey = drawBoxKey(boxInfo.boxWidget);

      nextPosition = Offset(position.dx + boxInfo.rect.width, position.dy);
      if (nextPosition.dx >= stackSize.width){
        position = Offset(0, position.dy + wordBoxHeight + widget.lineSpacing);
        nextPosition = Offset(position.dx + boxInfo.rect.width, position.dy);
      }

      boxKey.currentState!.setState((){
        boxInfo.rect = Rect.fromLTWH(position.dx, position.dy, boxInfo.rect.width, boxInfo.rect.height);
        boxKey.currentState!.position = position;
      });

      position = nextPosition;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final childList = _boxInfoList.map((boxInfo)=>boxInfo.boxWidget).toList();

    return OrientationBuilder( builder: (context, orientation) {

      WidgetsBinding.instance.addPostFrameCallback((_){
        _rebuildStr();
      });

      return Stack(
        key : _stackKey,
        children: childList,
      );
    });
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
