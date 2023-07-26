import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

class WordPanelController{
  WordPanelState? _panelState;

  WordPanelController({String text = ''}){
    _text = text;
  }

  String _text = '';

  String get text => _getText();

  set text(String value) {
    _setText(value);
  }

  String getWord(int pos){
    if (_panelState == null) return '';
    if (!_panelState!.mounted) return '';

    return _panelState!._getWord(pos);
  }

  String _getText(){
    if (_panelState == null) return _text;
    if (!_panelState!.mounted) return _text;

    _text = _panelState!._getText();
    return _text;
  }

  int getCursorPos() {
    if (_panelState == null) return -1;
    if (!_panelState!.mounted) return -1;

    return _panelState!._getCursorPos();
  }

  void _setText(String text) {
    _text = text;

    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    _panelState!._setText(_text);
    _panelState!._refresh();
  }

  void deleteWord(int fromPos, [int count = 1]) {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    _panelState!._deleteWord(fromPos, count);
  }

  void insertText(int pos, String text) {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    _panelState!._insertText(pos, text);
  }

  void refreshPanel() {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    _panelState!._refresh();
  }
}

class DragBoxInfo{
  final DragBox boxWidget;
  Rect rect = Rect.zero;
  DragBoxInfo(this.boxWidget);
}

GlobalKey<DragBoxState> dragBoxKey(DragBox dragBox){
  return dragBox.key as GlobalKey<DragBoxState>;
}

class WordPanelParam {
  final double sensWidth;   // the width of the sensitive zone at the ends of words, used when dragging and taping
  final double lineSpacing; // line spacing
  final String editPosLabel;
  final Color  editPosColor;
  final String insertPosLabel;
  final Color  insertPosColor;
  final double editPosWidth;
  final double insertPosWidth;
  final Color  colorWordNormal;
  final Color  colorWordSelected;
  final Color  colorWordCanDrop;
  final Color  colorWordMove;

  double wordBoxHeight = 1;

  WordPanelParam({
    this.sensWidth         = 20,
    this.lineSpacing       = 5,
    this.editPosLabel      = '@|@',
    this.editPosColor      = Colors.blue,
    this.insertPosLabel    = '@^@',
    this.insertPosColor    = Colors.green,
    this.editPosWidth      = 10,
    this.insertPosWidth    = 10,
    this.colorWordNormal   = Colors.grey,
    this.colorWordSelected = Colors.yellow,
    this.colorWordCanDrop  = Colors.amber,
    this.colorWordMove     = Colors.black12,
  });
}

class WordPanel extends StatefulWidget{
  final WordPanelController controller;
  final WordPanelParam param;

  const WordPanel({required this.controller, required this.param, Key? key}) : super(key: key);

  @override
  State<WordPanel> createState() => WordPanelState();
}

class WordPanelState extends State<WordPanel> {
  final _stackKey = GlobalKey();
  final _boxInfoList = <DragBoxInfo>[];
  final _sensRectList = <Rect>[];
  DragBoxInfo? _selectedBoxInfo;

  late  DragBox _moveBox;
  late  DragBox _editPos;
  late  DragBox _insertPos;

  bool _insertPosVisible = false;

  Offset? _selectInPos;
  bool _rebuildStrNeed = false;

  Size? _prevStackSize;

  late WordPanelParam _param;

  @override
  void initState() {
    super.initState();

    _param = widget.param;

    _moveBox   = DragBox(key: GlobalKey<DragBoxState>(), label: '',                    color: _param.colorWordMove,  param: _param);
    _editPos   = DragBox(key: GlobalKey<DragBoxState>(), label: _param.editPosLabel,   color: _param.editPosColor,   param: _param);
    _insertPos = DragBox(key: GlobalKey<DragBoxState>(), label: _param.insertPosLabel, color: _param.insertPosColor, param: _param);

    _setText(widget.controller._text);
  }

  _setText(String text){
    _boxInfoList.clear();
    _sensRectList.clear();

    text.split(' ').forEach((word){
      _boxInfoList.add(DragBoxInfo(DragBox(label: word, color: _param.colorWordNormal, key: GlobalKey<DragBoxState>(), param: _param)));
    });
    _rebuildStrNeed = true;
  }

  _rebuildStr(){
    if (!_rebuildStrNeed) {
      // We check if the dimensions of the panel have changed, if they have changed - the line needs to be rebuilt
      final stackSize = (_stackKey.currentContext!.findRenderObject() as RenderBox).size;
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

      _param.wordBoxHeight = _boxInfoList[0].rect.height;

      dragBoxKey(_insertPos).currentState!.setState((){
        dragBoxKey(_insertPos).currentState!.visible = false;
      });
    }
  }

  void _getBoxesRect(){
    final renderBox = _stackKey.currentContext!.findRenderObject() as RenderBox;

    for (var boxInfo in _boxInfoList) {
      final boxKey = dragBoxKey(boxInfo.boxWidget);
      final boxRenderBox = boxKey.currentContext!.findRenderObject() as RenderBox;
      final boxSize = boxRenderBox.size;
      final boxPos  = renderBox.globalToLocal(boxRenderBox.localToGlobal(Offset.zero));
      boxInfo.rect = Rect.fromLTWH(boxPos.dx, boxPos.dy, boxSize.width, boxSize.height);
    }
  }

  void _buildBoxesString(){
    _param.wordBoxHeight = _boxInfoList[0].rect.height;

    final stackSize = (_stackKey.currentContext!.findRenderObject() as RenderBox).size;
    var position = const Offset(0,0);
    Offset nextPosition;

    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      final boxKey = dragBoxKey(boxInfo.boxWidget);

      nextPosition = Offset(position.dx + boxInfo.rect.width, position.dy);
      if (nextPosition.dx >= stackSize.width){
        position = Offset(0, position.dy + _param.wordBoxHeight + _param.lineSpacing);
        nextPosition = Offset(position.dx + boxInfo.rect.width, position.dy);
      }

      boxKey.currentState!.setState((){
        boxInfo.rect = Rect.fromLTWH(position.dx, position.dy, boxInfo.rect.width, boxInfo.rect.height);
        boxKey.currentState!.position = position;
      });

      position = nextPosition;
    }

    final editPosState = dragBoxKey(_editPos).currentState;
    editPosState!.setState((){
      editPosState.position = position;
    });

    _fillSensRectList();
  }

  void _fillSensRectList(){
    _sensRectList.clear();

    if (_boxInfoList.isEmpty) return;

    final firstBox = _boxInfoList[0];
    final dy = firstBox.rect.height / 2;
    final sensHeight = firstBox.rect.height + _param.lineSpacing;

    _sensRectList.add(Rect.fromCenter(center: Offset(firstBox.rect.left, firstBox.rect.top + dy), width: _param.sensWidth, height: sensHeight ));

    for (var boxInfo in _boxInfoList) {
      _sensRectList.add(Rect.fromCenter(center: Offset(boxInfo.rect.right, boxInfo.rect.top + dy), width: _param.sensWidth, height: sensHeight ));
    }
  }

  String _getText(){
    String ret = '';

    for (var i = 0; i < _boxInfoList.length; i++) {
      final label = dragBoxKey(_boxInfoList[i].boxWidget).currentState!.label;

      if (ret.isEmpty) {
        ret = label;
      } else {
        ret = '$ret $label';
      }
    }

    return ret;
  }

  String _getWord(int pos){
    return dragBoxKey(_boxInfoList[pos].boxWidget).currentState!.label;
  }

  void _deleteWord(int fromPos, [int count = 1]){
    for (var i = fromPos; i < fromPos + count; i++) {
      if (fromPos < _boxInfoList.length) {
        _boxInfoList.removeAt(fromPos);
      }
    }
    _buildBoxesString();
  }

  void _insertText(int pos, String text){
    int lPos = pos;
    text.split(' ').forEach((word){
      _boxInfoList.insert(lPos, DragBoxInfo(DragBox(label: word, color: _param.colorWordNormal, key: GlobalKey<DragBoxState>(), param: _param)));
      lPos += 1;
    });
    _rebuildStrNeed = true;
  }

  int _getCursorPos(){
    final editPosState = dragBoxKey(_editPos).currentState;
    final editPosCenter = Offset(editPosState!.position.dx + _param.editPosWidth / 2, editPosState.position.dy +  _param.wordBoxHeight/ 2);
    int editIndex = 0;
    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      if (boxInfo.rect.top < editPosCenter.dy && boxInfo.rect.bottom > editPosCenter.dy){
        if (boxInfo.rect.left > editPosCenter.dx) return editIndex;
        editIndex = i;
      }
    }

    return editIndex;
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    widget.controller._panelState = this;

    final childList = _boxInfoList.map((boxInfo)=>boxInfo.boxWidget).toList();
    childList.add(_moveBox);
    childList.add(_editPos);
    childList.add(_insertPos);

    return OrientationBuilder( builder: (context, orientation) {

      WidgetsBinding.instance.addPostFrameCallback((_){
        _rebuildStr();
      });

      return GestureDetector(
          onPanStart: (details) => _onPanStart(details),
          onPanUpdate: (details) => _onPanUpdate(details),
          onPanEnd: (details) => _onPanEnd(details),
          onTapUp: (details)=> _onTapUp(details),
          child: Stack(
            key : _stackKey,
            children: childList,
          )
      );
    });
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = _stackKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    if (boxInfo != null){
      _selectedBoxInfo = boxInfo;
      _selectInPos = Offset(position.dx - boxInfo.rect.left, position.dy - boxInfo.rect.top);
      final moveBoxKey = _moveBox.key as GlobalKey<DragBoxState>;

      moveBoxKey.currentState!.setState((){
        moveBoxKey.currentState!.label = boxInfo.boxWidget.label;
        moveBoxKey.currentState!.visible = false;
      });
    }
  }
  void _onPanUpdate(DragUpdateDetails details) {
    if (_selectedBoxInfo == null) return;

    final renderBox = _stackKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);

    final moveBoxKey = dragBoxKey(_moveBox);
    final moveBoxPosition = Offset(position.dx - _selectInPos!.dx, position.dy - _selectInPos!.dy);
    final moveBoxSize = (moveBoxKey.currentContext!.findRenderObject() as RenderBox).size;
    final moveBoxCenter = Offset(moveBoxPosition.dx + moveBoxSize.width / 2, moveBoxPosition.dy + moveBoxSize.height / 2);

    final sensRect = _sensRectList.firstWhereOrNull ((rect)=>rect.contains(moveBoxCenter));
    final bool insertPosNeed = (sensRect != null);

    if (_insertPosVisible != insertPosNeed ) {
      moveBoxKey.currentState!.setState((){
        moveBoxKey.currentState!.color = insertPosNeed ? _param.colorWordCanDrop : _param.colorWordMove;
      });

      if ( insertPosNeed ){
        HapticFeedback.heavyImpact();
      }

      _insertPosVisible = insertPosNeed;

      final insertPosState = dragBoxKey(_insertPos).currentState;
      if (insertPosNeed) {
        int insertIndex = 0;
        int selIndex = 0;
        for (var i = 0; i < _boxInfoList.length; i++) {
          final boxInfo = _boxInfoList[i];
          if (boxInfo == _selectedBoxInfo){
            selIndex = i;
          }
          if (boxInfo.rect.top < sensRect.center.dy && boxInfo.rect.bottom > sensRect.center.dy && boxInfo.rect.left < sensRect.center.dx){
            insertIndex = i;
          }
        }
        insertIndex += 1;

        if (insertIndex != selIndex && insertIndex != (selIndex + 1)){
          insertPosState!.setState((){
            insertPosState.position = Offset(sensRect.center.dx - _param.insertPosWidth / 2, sensRect.center.dy - _param.wordBoxHeight / 2);
            insertPosState.visible = true;
          });
        }
      } else {
        insertPosState!.setState((){
          insertPosState.visible = false;
        });
      }
    }

    moveBoxKey.currentState!.setState(() {
      moveBoxKey.currentState!.position = moveBoxPosition;
      moveBoxKey.currentState!.visible = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_selectedBoxInfo == null) return;

    final moveBoxKey = dragBoxKey(_moveBox);
    moveBoxKey.currentState!.setState(() {
      moveBoxKey.currentState!.label = '';
      moveBoxKey.currentState!.visible = false;
      moveBoxKey.currentState!.position = const Offset(0,0);
    });

    final insertPosState = dragBoxKey(_insertPos).currentState;
    if (insertPosState!.visible) {
      final insertPosCenter = Offset(insertPosState.position.dx + _param.insertPosWidth / 2, insertPosState.position.dy +  _param.wordBoxHeight/ 2);
      int insertIndex = 0;
      int selIndex = 0;
      for (var i = 0; i < _boxInfoList.length; i++) {
        final boxInfo = _boxInfoList[i];
        if (boxInfo == _selectedBoxInfo){
          selIndex = i;
        }
        if (boxInfo.rect.top < insertPosCenter.dy && boxInfo.rect.bottom > insertPosCenter.dy && boxInfo.rect.left < insertPosCenter.dx){
          insertIndex = i;
        }
      }
      insertIndex += 1;

      if (selIndex != insertIndex){
        final boxInfo = _boxInfoList[selIndex];
        _boxInfoList.removeAt(selIndex);
        if (selIndex < insertIndex){
          insertIndex -= 1;
        }
        _boxInfoList.insert(insertIndex, boxInfo);

        _buildBoxesString();
      }

      insertPosState.setState((){
        insertPosState.visible = false;
      });

    }

    _selectedBoxInfo = null;
  }

  void _onTapUp(TapUpDetails details){
    final renderBox = _stackKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);

    final sensRect = _sensRectList.firstWhereOrNull((rect)=>rect.contains(position));
    if (sensRect != null){
      final editPosState = dragBoxKey(_editPos).currentState;
      editPosState!.setState((){
        editPosState.position = Offset(sensRect.center.dx - _param.editPosWidth / 2, sensRect.center.dy - _param.wordBoxHeight / 2);
      });
      return;
    }

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    if (boxInfo != null){
      final boxState = dragBoxKey(boxInfo.boxWidget).currentState;
      boxState!.setState((){
        boxState.color == _param.colorWordNormal ? boxState.color = _param.colorWordSelected : boxState.color = _param.colorWordNormal;
      });
      return;
    }
  }

}

class DragBox extends StatefulWidget {
  final String label;
  final Color color;
  final WordPanelParam param;

  const DragBox({required this.label, required this.color, required this.param, Key? key})  : super(key: key);

  @override
  State<DragBox> createState() => DragBoxState();
}

class DragBoxState extends State<DragBox> {
  Offset position = const Offset(0.0, 0.0);
  String label    = '';
  Color  color    = Colors.white;
  bool   visible  = true;
  late WordPanelParam param;

  DragBoxState();

  @override
  void initState() {
    super.initState();

    label = widget.label;
    color = widget.color;
    param = widget.param;
  }

  @override
  Widget build(BuildContext context) {
    if (!visible || label.isEmpty){
      return Positioned(
          left: 0,
          top: 0,
          child: Container()
      );
    }

    if (label == param.editPosLabel){
      return Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              color: color,
            ),
            width: param.editPosWidth,
            height: param.wordBoxHeight,
          )
      );
    }

    if (label == param.insertPosLabel){
      return Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              color: color,
            ),
            width: param.insertPosWidth,
            height: param.wordBoxHeight,
          )
      );
    }

    return Positioned(
        left: position.dx,
        top: position.dy,
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            color: color,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                decoration: TextDecoration.none,
                fontSize: 50.0,
              ),
            ),
          ),
        )
    );
  }
}
