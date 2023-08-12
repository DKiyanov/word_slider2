import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

class WordPanelController {
  WordPanelState? _panelState;

  final VoidCallback? onChange;

  final bool canMoveWord;
  final bool noCursor;
  final bool focusAsCursor;

  WordPanelController({
    String text = '',
    this.onChange,
    this.canMoveWord   = true,
    this.noCursor      = false,
    this.focusAsCursor = true
  }){
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

    return _panelState!._wordBoxHeight;
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

  int getCursorPos({bool onlyCursor = false, bool lastPostIfNot = false}) {
    if (_panelState == null) return -1;
    if (!_panelState!.mounted) return -1;

    final pos = _panelState!._getCursorPos();
    if (pos >=0) return pos;

    if (onlyCursor) {
      if (lastPostIfNot) {
        return _panelState!._boxInfoList.length;
      } else {
        return pos;
      }
    }

    if (focusAsCursor) {
      final pos = getFocusPos();

      if (pos >=0) return pos;

      if (lastPostIfNot) {
        return _panelState!._boxInfoList.length;
      } else {
        return pos;
      }
    }

    return pos;
  }

  void setCursorPos(int pos) {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    return _panelState!._setCursorPos(pos);
  }

  void hideCursor() {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    return _panelState!._hideCursor();
  }

  int getFocusPos() {
    if (_panelState == null) return -1;
    if (!_panelState!.mounted) return -1;

    return _panelState!._getFocusPos();
  }

  void setFocusPos(int pos) {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    return _panelState!._setFocusPos(pos);
  }

  void hideFocus() {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    return _panelState!._hideFocus();
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

  void insertWord(int pos, String word) {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    _panelState!._insertWord(pos, word);
  }

  void refreshPanel() {
    if (_panelState == null) return;
    if (!_panelState!.mounted) return;

    _panelState!._refresh();
  }
}

class ValueProxy{
  String value;
  ValueProxy(this.value);
}

class DragBoxInfo{
  final DragBox boxWidget;
  final ValueProxy label;
  Rect rect = Rect.zero;
  DragBoxInfo({required this.boxWidget, required this.label});
}

GlobalKey<DragBoxState> dragBoxKey(DragBox dragBox){
  return dragBox.key as GlobalKey<DragBoxState>;
}

typedef OnChangeHeight = void Function(double newHeight);

class WordPanel extends StatefulWidget {
  final WordPanelController controller;
  final DragBoxBuilder      onDragBoxBuild;
  final DragBoxTap?         onDragBoxTap;
  final DragBoxTap?         onDragBoxLongPress;
  final DragBoxTap?         onDoubleTap;
  final OnChangeHeight?     onChangeHeight;
  final double              sensWidth;   // the width of the sensitive zone at the ends of words, used when dragging and taping
  final double              lineSpacing; // line spacing

  const WordPanel({
    required this.controller,
    required this.onDragBoxBuild,
    this.onDragBoxTap,
    this.onDragBoxLongPress,
    this.onDoubleTap,
    this.onChangeHeight,
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

  double _width = 0.0;
  double _height = 0.0;

  double _editPosWidth   = 0.0;
  double _insertPosWidth = 0.0;

  double _wordBoxHeight = 0;

  bool _starting = true;

  @override
  void initState() {
    super.initState();

    _moveBox   = DragBox(key: GlobalKey<DragBoxState>(), spec: DragBoxSpec.move     , onBuild: widget.onDragBoxBuild, label: ValueProxy(''),);
    _editPos   = DragBox(key: GlobalKey<DragBoxState>(), spec: DragBoxSpec.editPos  , onBuild: widget.onDragBoxBuild);
    _insertPos = DragBox(key: GlobalKey<DragBoxState>(), spec: DragBoxSpec.insertPos, onBuild: widget.onDragBoxBuild);

    _setText(widget.controller._text);
  }

  _setText(String text){
    _boxInfoList.clear();
    _sensRectList.clear();

    _boxInfoList.addAll(_splitText(text));
    widget.controller.onChange?.call();

    _rebuildStrNeed = true;
  }

  List<DragBoxInfo> _splitText(String text) {
    if (text.isEmpty) return [];

    final result = <DragBoxInfo>[];

    final wordList = <String>[];

    final subStrList = text.split("'");

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
        result.add(_createNewWord(word));
      }
    }

    return result;
  }

  DragBoxInfo _createNewWord(String word){
    final label = ValueProxy(word);

    return DragBoxInfo(
      boxWidget : DragBox(
        label   : label,
        onBuild : widget.onDragBoxBuild,
        key     : GlobalKey<DragBoxState>()
      ),

      label : label,
    );
  }

  _rebuildStr(double width){
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

      if (_editPosWidth == 0.0) {
        _editPosWidth   = _getDragBoxRenderBox(_editPos).size.width;
      }
      if (_insertPosWidth == 0.0) {
        _insertPosWidth = _getDragBoxRenderBox(_insertPos).size.width;
      }

      final insertPosState = dragBoxKey(_insertPos).currentState!;
      insertPosState.setState((){
        insertPosState.visible = false;
      });

      final editPosState = dragBoxKey(_editPos).currentState!;
      editPosState.setState((){
        editPosState.visible = false;
      });
    }
  }

  RenderBox _getStackRenderBox(){
    return _stackKey.currentContext!.findRenderObject() as RenderBox;
  }

  RenderBox _getDragBoxRenderBox(DragBox dragBox){
    return dragBoxKey(dragBox).currentContext!.findRenderObject() as RenderBox;
  }

  void _buildBoxesString(double width){
    final prevHeight = _height;
    _wordBoxHeight = 0;

    var position = const Offset(0,0);
    Offset nextPosition;

    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      final boxKey = dragBoxKey(boxInfo.boxWidget);

      final renderBox = boxKey.currentContext!.findRenderObject() as RenderBox;

      if (_wordBoxHeight == 0.0) {
        _wordBoxHeight = renderBox.size.height;
        _height = _wordBoxHeight;
      }

      nextPosition = Offset(position.dx + renderBox.size.width, position.dy);
      if (nextPosition.dx >= width){
        position = Offset(0, position.dy + _wordBoxHeight + widget.lineSpacing);
        nextPosition = Offset(position.dx + renderBox.size.width, position.dy);
        _height = position.dy + _wordBoxHeight;
      }

      boxKey.currentState!.setState((){
        boxInfo.rect = Rect.fromLTWH(position.dx, position.dy, renderBox.size.width, renderBox.size.height);
        boxKey.currentState!.position = position;
      });

      position = nextPosition;
    }

    if (prevHeight != _height) {
      _starting = true;
      widget.onChangeHeight?.call(_height);
    }

    _fillSensRectList();
  }

  void _fillSensRectList(){
    _sensRectList.clear();

    if (_boxInfoList.isEmpty) return;

    final firstBox = _boxInfoList[0];
    final dy = firstBox.rect.height / 2;
    final sensHeight = firstBox.rect.height + widget.lineSpacing;

    double prevTop = -1.0;

    for (var boxInfo in _boxInfoList) {
      if (prevTop != boxInfo.rect.top) {
        _sensRectList.add(Rect.fromCenter(center: Offset(boxInfo.rect.left, boxInfo.rect.top + dy), width: widget.sensWidth, height: sensHeight ));
        prevTop = boxInfo.rect.top;
      }

      _sensRectList.add(Rect.fromCenter(center: Offset(boxInfo.rect.right, boxInfo.rect.top + dy), width: widget.sensWidth, height: sensHeight ));
    }
  }

  String _getText(){
    String ret = '';

    for (var i = 0; i < _boxInfoList.length; i++) {
      final label = _boxInfoList[i].label.value;

      if (ret.isEmpty) {
        ret = label;
      } else {
        ret = '$ret $label';
      }
    }

    return ret;
  }

  String _getWord(int pos){
    return _boxInfoList[pos].label.value;
  }

  void _deleteWord(int fromPos, [int count = 1]){
    for (var i = fromPos; i < fromPos + count; i++) {
      if (fromPos < _boxInfoList.length) {
        _boxInfoList.removeAt(fromPos);
      }
    }
    widget.controller.onChange?.call();
    _buildBoxesString(_width);
  }

  void _insertText(int pos, String text){
    _boxInfoList.insertAll(pos, _splitText(text));
    widget.controller.onChange?.call();
    _rebuildStrNeed = true;
  }

  void _insertWord(int pos, String word) {
    _boxInfoList.insert(pos, _createNewWord(word));
    widget.controller.onChange?.call();
    _rebuildStrNeed = true;
  }

  int _getFocusPos() {
    if (_focusBoxKey == null) return -1;

    final focusRenderBox = _focusBoxKey!.currentContext?.findRenderObject() as RenderBox?;
    if (focusRenderBox == null) return -1;

    final focusState = _focusBoxKey!.currentState;
    if (focusState == null) return -1;

    final focusCenter = Offset(focusState.position.dx + focusRenderBox.size.width / 2, focusState.position.dy + focusRenderBox.size.height / 2);
    final boxInfo = getBoxAtPos(localPosition : focusCenter, tapOnSensRect : false);
    if (boxInfo == null) return -1;

    final pos = _boxInfoList.indexOf(boxInfo);

    return pos;
  }

  void _setFocusPos(int pos) {
    if (pos < 0 || pos >= _boxInfoList.length) return;

    final boxInfo = _boxInfoList[pos];
    final boxKey = dragBoxKey(boxInfo.boxWidget);

    if (boxKey == _focusBoxKey) return;

    final boxState = boxKey.currentState;
    if (boxState == null) return;

    if (_focusBoxKey != null) {
      final focusBoxState = _focusBoxKey!.currentState;
      if (focusBoxState != null) {
        focusBoxState.setState(() {
          focusBoxState.spec = DragBoxSpec.none;
        });
      }
    }

    boxState.setState(() {
      boxState.spec = DragBoxSpec.focus;
    });
  }

  void _hideFocus() {
    if (_focusBoxKey == null) return;
    final focusState = _focusBoxKey!.currentState;
    if (focusState == null) return;

    focusState.setState(() {
      focusState.spec = DragBoxSpec.none;
    });
  }

  int _getCursorPos(){
    final editPosState = dragBoxKey(_editPos).currentState;
    if (editPosState == null) return -1;
    if (!editPosState.visible) return -1;

    final editPosCenter = Offset(editPosState.position.dx + _editPosWidth / 2, editPosState.position.dy + _wordBoxHeight/ 2);

    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      if (boxInfo.rect.top < editPosCenter.dy && boxInfo.rect.bottom > editPosCenter.dy){
        if (boxInfo.rect.right > editPosCenter.dx) {
          return i;
        }
      }
    }

    return _boxInfoList.length;
  }

  void _setCursorPos(int pos) {
    final editPosState = dragBoxKey(_editPos).currentState!;

    if (_boxInfoList.isEmpty) {
      editPosState.setState((){
        editPosState.visible = true;
        editPosState.position = Offset(_editPosWidth / 2, 0);
      });
      return;
    }

    if (pos >= _boxInfoList.length) {
      final boxInfo = _boxInfoList.last;
      editPosState.setState((){
        editPosState.visible = true;
        editPosState.position = Offset(boxInfo.rect.right - _editPosWidth / 2, boxInfo.rect.center.dy - _wordBoxHeight / 2);
      });
      return;
    }

    if (pos < 0) pos = 0;
    final boxInfo = _boxInfoList[pos];

    editPosState.setState((){
      editPosState.visible = true;
      editPosState.position = Offset(boxInfo.rect.left - _editPosWidth / 2, boxInfo.rect.center.dy - _wordBoxHeight / 2);
    });

  }

  void _hideCursor() {
    final editPosState = dragBoxKey(_editPos).currentState!;
    editPosState.setState((){
      editPosState.visible = false;
    });
  }

  void _refresh() {
    _starting = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    widget.controller._panelState = this;

    final childList = _boxInfoList.map((boxInfo)=>boxInfo.boxWidget).toList();
    childList.add(_moveBox);
    childList.add(_editPos);
    childList.add(_insertPos);

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
            onPanStart:       (details) => _onPanStart(details),
            onPanUpdate:      (details) => _onPanUpdate(details),
            onPanEnd:         (details) => _onPanEnd(details),
            onTapUp:          (details) => _onTapUp(details),
            onLongPressStart: (details) => _tapProcess(widget.onDragBoxLongPress, details.globalPosition),
            onDoubleTapDown:  (details) => _tapProcess(widget.onDoubleTap, details.globalPosition),
            child: SizedBox(
              width: _width,
              height: _height,

              child: Stack(
                key : _stackKey,
                children: childList,
              ),
            )
        ),
      );

    });
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.controller.canMoveWord) return;

    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(details.globalPosition);

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    if (boxInfo != null){
      _selectedBoxInfo = boxInfo;
      _selectInPos = Offset(position.dx - boxInfo.rect.left, position.dy - boxInfo.rect.top);
      final moveBoxKey = _moveBox.key as GlobalKey<DragBoxState>;

      moveBoxKey.currentState!.setState((){
        _moveBox.label!.value = boxInfo.label.value;
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

    bool insertPosVisible = false;

    final sensRect = _sensRectList.firstWhereOrNull ((rect)=>rect.contains(moveBoxCenter));
    final bool insertPosNeed = (sensRect != null);

    if (insertPosNeed) {
      int insertIndex = 0;
      int selIndex = 0;

      for (var i = 0; i < _boxInfoList.length; i++) {
        final boxInfo = _boxInfoList[i];
        if (boxInfo == _selectedBoxInfo){
          selIndex = i;
          break;
        }
      }

      for (var i = 0; i < _boxInfoList.length; i++) {
        final boxInfo = _boxInfoList[i];
        if (boxInfo.rect.top < sensRect.center.dy && boxInfo.rect.bottom > sensRect.center.dy){
          if (sensRect.contains(boxInfo.rect.centerLeft)) {
            insertIndex = i;
            break;
          }
          if (sensRect.contains(boxInfo.rect.centerRight)) {
            insertIndex = i + 1;
            break;
          }
        }
      }

      if (insertIndex != selIndex && insertIndex != (selIndex + 1)){
        insertPosVisible = true;
      }
    }

    if (_insertPosVisible != insertPosVisible) {
      _insertPosVisible = insertPosVisible;

      final insertPosState = dragBoxKey(_insertPos).currentState;

      if (insertPosVisible) {
        HapticFeedback.heavyImpact();

        insertPosState!.setState((){
          insertPosState.position = Offset(sensRect!.center.dx - _insertPosWidth / 2, sensRect.center.dy - _wordBoxHeight / 2);
          insertPosState.visible = true;
        });
      } else {
        insertPosState!.setState((){
          insertPosState.visible = false;
        });
      }
    }

    final moveBoxState = moveBoxKey.currentState!;
    moveBoxState.setState(() {
      moveBoxState.spec     = insertPosVisible ? DragBoxSpec.canDrop : DragBoxSpec.move;
      moveBoxState.position = moveBoxPosition;
      moveBoxState.visible  = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_selectedBoxInfo == null) return;

    final moveBoxKey = dragBoxKey(_moveBox);
    moveBoxKey.currentState!.setState(() {
      _moveBox.label!.value = '';
      moveBoxKey.currentState!.visible = false;
      moveBoxKey.currentState!.position = const Offset(0,0);
    });

    final insertPosState = dragBoxKey(_insertPos).currentState;
    if (insertPosState!.visible) {
      final insertPosCenter = Offset(insertPosState.position.dx + _insertPosWidth / 2, insertPosState.position.dy + _wordBoxHeight/ 2);
      final sensRect = _sensRectList.firstWhere((rect)=>rect.contains(insertPosCenter));
      int insertIndex = 0;
      int selIndex = 0;

      for (var i = 0; i < _boxInfoList.length; i++) {
        final boxInfo = _boxInfoList[i];
        if (boxInfo == _selectedBoxInfo){
          selIndex = i;
        }
      }

      for (var i = 0; i < _boxInfoList.length; i++) {
        final boxInfo = _boxInfoList[i];

        if (sensRect.contains(boxInfo.rect.centerLeft)) {
          insertIndex = i;
          break;
        }
        if (sensRect.contains(boxInfo.rect.centerRight)) {
          insertIndex = i + 1;
          break;
        }
      }

      if (selIndex != insertIndex){
        final pos = _getCursorPos();
        DragBoxInfo? cursorBoxInfo;
        int posAdd = 0;
        if (pos >= 0) {
          if (pos >= _boxInfoList.length) {
            posAdd = 1;
            cursorBoxInfo = _boxInfoList[_boxInfoList.length - 1];
          } else {
            cursorBoxInfo = _boxInfoList[pos];
          }
        }

        final boxInfo = _boxInfoList[selIndex];
        _boxInfoList.removeAt(selIndex);
        if (selIndex < insertIndex){
          insertIndex -= 1;
        }
        _boxInfoList.insert(insertIndex, boxInfo);

        widget.controller.onChange?.call();

        _buildBoxesString(_width);
        if (_starting) {
          setState(() {});
        }

        if (cursorBoxInfo != null) {
          final pos = _boxInfoList.indexOf(cursorBoxInfo) + posAdd;
          _setCursorPos(pos);
        }
      }

      insertPosState.setState((){
        insertPosState.visible = false;
      });

    }

    _selectedBoxInfo = null;
  }

  DragBoxInfo? getBoxAtPos({Offset? globalPosition, Offset? localPosition, bool tapOnSensRect = true}) {
    var position = localPosition;

    if (position == null && globalPosition != null) {
      final renderBox = _getStackRenderBox();
      position = renderBox.globalToLocal(globalPosition);
    }

    if (position == null) return null;

    if (!widget.controller.noCursor && tapOnSensRect) {
      final sensRect = _sensRectList.firstWhereOrNull((rect)=>rect.contains(position!));
      if (sensRect != null){
        final editPosState = dragBoxKey(_editPos).currentState!;
        editPosState.setState((){
          editPosState.visible = true;
          editPosState.position = Offset(sensRect.center.dx - _editPosWidth / 2, sensRect.center.dy - _wordBoxHeight / 2);
        });
        return null;
      }
    }

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position!));
    return boxInfo;
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    final boxInfo = getBoxAtPos(globalPosition: details.globalPosition);
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

      if (widget.controller.focusAsCursor) {
        _hideCursor();
      }
    }

    bool labelChanged = false;

    if (widget.onDragBoxTap != null){
      final newLabel = await widget.onDragBoxTap!.call(boxInfo.label.value, boxState.position);
      if (newLabel != null ) {
        if (boxInfo.label.value != newLabel) {
          boxInfo.label.value = newLabel;
          labelChanged = true;
        }
      }
    }

    boxState.setState((){});

    if (labelChanged) {
      widget.controller.onChange?.call();
      _rebuildStrNeed = true;
      setState(() {});
    }
  }

  Future<void> _tapProcess(DragBoxTap? onDragTap, Offset globalPosition) async {
    if (onDragTap == null) return;

    final boxInfo = getBoxAtPos(globalPosition : globalPosition);
    if (boxInfo == null) return;

    final boxKey = dragBoxKey(boxInfo.boxWidget);
    final boxState = boxKey.currentState;
    if (boxState == null)  return;

    final newLabel = await onDragTap.call(boxInfo.label.value, boxState.position);
    if (newLabel == null || boxInfo.label.value == newLabel) return;

    boxState.setState((){
      boxInfo.label.value = newLabel;
    });

    widget.controller.onChange?.call();

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

typedef DragBoxBuilder = Widget Function(BuildContext context, String label, DragBoxSpec spec);
typedef DragBoxTap = Future<String?> Function(String label, Offset position);

class DragBox extends StatefulWidget {
  final ValueProxy? label;
  final DragBoxSpec spec;
  final DragBoxBuilder onBuild;

  const DragBox({this.label, this.spec = DragBoxSpec.none, required this.onBuild, Key? key})  : super(key: key);

  @override
  State<DragBox> createState() => DragBoxState();
}

class DragBoxState extends State<DragBox> {
  Offset position  = const Offset(0.0, 0.0);
  DragBoxSpec spec = DragBoxSpec.none;
  bool   visible   = true;

  @override
  void initState() {
    super.initState();

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

    String label = '';
    if (widget.label != null) label = widget.label!.value;

    return Positioned(
        left  : position.dx,
        top   : position.dy,
        child: widget.onBuild.call(context, label, spec)
    );
  }
}
