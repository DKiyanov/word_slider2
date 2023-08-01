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

  double get wordBoxHeight {
    if (_panelState == null) return 0;
    if (!_panelState!.mounted) return 0;

    return _panelState!.wordBoxHeight;
  }

  String getWord(int pos) {
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

class WordPanel extends StatefulWidget{
  final WordPanelController controller;
  final DragBoxBuilder      onDragBoxBuild;
  final DragBoxTap?         onDragBoxTap;
  final DragBoxTap?         onDragBoxLongPress;
  final DragBoxTap?         onDoubleTap;
  final double              sensWidth;   // the width of the sensitive zone at the ends of words, used when dragging and taping
  final double              lineSpacing; // line spacing

  const WordPanel({
    required this.controller,
    required this.onDragBoxBuild,
    this.onDragBoxTap,
    this.onDragBoxLongPress,
    this.onDoubleTap,
    this.sensWidth   = 20,
    this.lineSpacing = 5,
    Key? key
  }) : super(key: key);

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

  GlobalKey<DragBoxState>? _focusBoxKey;

  bool _insertPosVisible = false;

  Offset? _selectInPos;
  bool _rebuildStrNeed = false;

  Size? _prevStackSize;

  double _editPosWidth   = 0.0;
  double _insertPosWidth = 0.0;

  double wordBoxHeight = 0;

  @override
  void initState() {
    super.initState();

    _moveBox   = DragBox(key: GlobalKey<DragBoxState>(), spec: DragBoxSpec.move     , onBuild: widget.onDragBoxBuild);
    _editPos   = DragBox(key: GlobalKey<DragBoxState>(), spec: DragBoxSpec.editPos  , onBuild: widget.onDragBoxBuild);
    _insertPos = DragBox(key: GlobalKey<DragBoxState>(), spec: DragBoxSpec.insertPos, onBuild: widget.onDragBoxBuild);

    _setText(widget.controller._text);
  }

  _setText(String text){
    _boxInfoList.clear();
    _sensRectList.clear();

    text.split(' ').forEach((word){
      _boxInfoList.add(DragBoxInfo(DragBox(label: word, onBuild: widget.onDragBoxBuild, key: GlobalKey<DragBoxState>())));
    });
    _rebuildStrNeed = true;
  }

  _rebuildStr(){
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

      _editPosWidth   = _getDragBoxRenderBox(_editPos).size.width;
      _insertPosWidth = _getDragBoxRenderBox(_insertPos).size.width;

      dragBoxKey(_insertPos).currentState!.setState((){
        dragBoxKey(_insertPos).currentState!.visible = false;
      });
    }
  }

  RenderBox _getStackRenderBox(){
    return _stackKey.currentContext!.findRenderObject() as RenderBox;
  }

  RenderBox _getDragBoxRenderBox(DragBox dragBox){
    return dragBoxKey(dragBox).currentContext!.findRenderObject() as RenderBox;
  }

  void _getBoxesRect(){
    final renderBox = _getStackRenderBox();

    for (var boxInfo in _boxInfoList) {
      final boxRenderBox = _getDragBoxRenderBox(boxInfo.boxWidget);
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
      final boxKey = dragBoxKey(boxInfo.boxWidget);

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
    final sensHeight = firstBox.rect.height + widget.lineSpacing;

    _sensRectList.add(Rect.fromCenter(center: Offset(firstBox.rect.left, firstBox.rect.top + dy), width: widget.sensWidth, height: sensHeight ));

    for (var boxInfo in _boxInfoList) {
      _sensRectList.add(Rect.fromCenter(center: Offset(boxInfo.rect.right, boxInfo.rect.top + dy), width: widget.sensWidth, height: sensHeight ));
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
      _boxInfoList.insert(lPos, DragBoxInfo(DragBox(label: word, onBuild: widget.onDragBoxBuild, key: GlobalKey<DragBoxState>())));
      lPos += 1;
    });
    _rebuildStrNeed = true;
  }

  int _getCursorPos(){
    final editPosState = dragBoxKey(_editPos).currentState;
    final editPosCenter = Offset(editPosState!.position.dx + _editPosWidth / 2, editPosState.position.dy + wordBoxHeight/ 2);
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
          onPanStart:       (details) => _onPanStart(details),
          onPanUpdate:      (details) => _onPanUpdate(details),
          onPanEnd:         (details) => _onPanEnd(details),
          onTapUp:          (details) => _onTapUp(details),
          onLongPressStart: (details) => _tapProcess(widget.onDragBoxLongPress, details.globalPosition),
          onDoubleTapDown:  (details) => _tapProcess(widget.onDoubleTap, details.globalPosition),
          child: Stack(
            key : _stackKey,
            children: childList,
          )
      );
    });
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(details.globalPosition);

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    if (boxInfo != null){
      _selectedBoxInfo = boxInfo;
      _selectInPos = Offset(position.dx - boxInfo.rect.left, position.dy - boxInfo.rect.top);
      final moveBoxKey = _moveBox.key as GlobalKey<DragBoxState>;

      moveBoxKey.currentState!.setState((){
        moveBoxKey.currentState!.label = dragBoxKey(boxInfo.boxWidget).currentState!.label;
        moveBoxKey.currentState!.visible = false;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_selectedBoxInfo == null) return;

    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(details.globalPosition);

    final moveBoxKey = dragBoxKey(_moveBox);
    final moveBoxPosition = Offset(position.dx - _selectInPos!.dx, position.dy - _selectInPos!.dy);
    final moveBoxSize = _getDragBoxRenderBox(_moveBox).size;
    final moveBoxCenter = Offset(moveBoxPosition.dx + moveBoxSize.width / 2, moveBoxPosition.dy + moveBoxSize.height / 2);

    final sensRect = _sensRectList.firstWhereOrNull ((rect)=>rect.contains(moveBoxCenter));
    final bool insertPosNeed = (sensRect != null);

    if (_insertPosVisible != insertPosNeed ) {
      moveBoxKey.currentState!.setState((){
        moveBoxKey.currentState!.spec = insertPosNeed ? DragBoxSpec.canDrop : DragBoxSpec.move;
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
            insertPosState.position = Offset(sensRect.center.dx - _insertPosWidth / 2, sensRect.center.dy - wordBoxHeight / 2);
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
      final insertPosCenter = Offset(insertPosState.position.dx + _insertPosWidth / 2, insertPosState.position.dy + wordBoxHeight/ 2);
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

  DragBoxInfo? getBoxAtPos(Offset globalPosition) {
    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(globalPosition);

    final sensRect = _sensRectList.firstWhereOrNull((rect)=>rect.contains(position));
    if (sensRect != null){
      final editPosState = dragBoxKey(_editPos).currentState;
      editPosState!.setState((){
        editPosState.position = Offset(sensRect.center.dx - _editPosWidth / 2, sensRect.center.dy - wordBoxHeight / 2);
      });
      return null;
    }

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    return boxInfo;
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    final boxInfo = getBoxAtPos(details.globalPosition);
    if (boxInfo == null) return;

    final boxKey = dragBoxKey(boxInfo.boxWidget);
    final boxState = boxKey.currentState;
    if (boxState == null)  return;

    bool setFocus = true;

    if (_focusBoxKey != null) {
      final focusBoxState = _focusBoxKey!.currentState;
      if (focusBoxState != null) {
        if (_focusBoxKey == boxKey) {
          boxState.spec = DragBoxSpec.none;
          _focusBoxKey = null;
          setFocus = false;
        } else {
          focusBoxState.setState(() {
            focusBoxState.spec = DragBoxSpec.none;
          });
        }
      }
    }

    if (setFocus) {
      boxState.spec = DragBoxSpec.focus;
      _focusBoxKey = boxKey;
    }

    if (widget.onDragBoxTap != null){
      final newLabel = await widget.onDragBoxTap!.call(boxState.label, boxState.position);
      if (newLabel != null ) {
        boxState.label = newLabel;
      }
    }

    boxState.setState((){});
  }

  Future<void> _tapProcess(DragBoxTap? onDragTap, Offset globalPosition) async {
    if (onDragTap == null) return;

    final boxInfo = getBoxAtPos(globalPosition);
    if (boxInfo == null) return;

    final boxKey = dragBoxKey(boxInfo.boxWidget);
    final boxState = boxKey.currentState;
    if (boxState == null)  return;

    final newLabel = await onDragTap.call(boxState.label, boxState.position);
    if (newLabel == null || boxState.label == newLabel) return;

    boxState.setState((){
      boxState.label = newLabel;
    });

    _rebuildStrNeed = true;
    setState(() {});
  }
}

enum DragBoxSpec {
  none,
  move,
  canDrop,
  focus,
  insertPos,
  editPos,
}

typedef DragBoxBuilder = Widget Function(BuildContext context, String label, DragBoxSpec spec, Offset position);
typedef DragBoxTap = Future<String?> Function(String label, Offset position);

class DragBox extends StatefulWidget {
  final String label;
  final DragBoxSpec spec;
  final DragBoxBuilder onBuild;

  const DragBox({this.label = '', this.spec = DragBoxSpec.none, required this.onBuild, Key? key})  : super(key: key);

  @override
  State<DragBox> createState() => DragBoxState();
}

class DragBoxState extends State<DragBox> {
  Offset position  = const Offset(0.0, 0.0);
  String label     = '';
  DragBoxSpec spec = DragBoxSpec.none;
  bool   visible   = true;

  @override
  void initState() {
    super.initState();

    label = widget.label;
    spec  = widget.spec;

    if (spec == DragBoxSpec.move) {
      visible = false;
    }
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

    return widget.onBuild.call(context, label, spec, position);
  }
}
