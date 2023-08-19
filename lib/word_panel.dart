import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

import 'drag_box_widget.dart';

typedef DragBoxTap = Future<String?> Function(String label, Offset position);
typedef OnChangeHeight = void Function(double newHeight);

enum DragBoxSpec {
  none,
  move,
  canDrop,
  focus,
  insertPos,
  editPos,
}

class PanelBoxExt{
  String label;
  DragBoxSpec spec;
  PanelBoxExt({this.label = '', this.spec = DragBoxSpec.none });
}

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

class WordPanel extends StatefulWidget {
  final WordPanelController controller;
  final DragBoxBuilder<PanelBoxExt> onDragBoxBuild;
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
  final _boxInfoList = <DragBoxInfo<PanelBoxExt>>[];
  final _sensRectList = <Rect>[];
  DragBoxInfo<PanelBoxExt>? _selectedBoxInfo;

  late  DragBoxInfo<PanelBoxExt> _testBox;
  late  DragBoxInfo<PanelBoxExt> _moveBox;
  late  DragBoxInfo<PanelBoxExt> _editPos;
  late  DragBoxInfo<PanelBoxExt> _insertPos;

  DragBoxInfo<PanelBoxExt>? _focusBox;

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

    _testBox   = _createDragBoxInfo(label: 'Tp');
    _moveBox   = _createDragBoxInfo(spec: DragBoxSpec.move);
    _editPos   = _createDragBoxInfo(spec: DragBoxSpec.editPos);
    _insertPos = _createDragBoxInfo(spec: DragBoxSpec.insertPos);

    _setText(widget.controller._text);
  }

  DragBoxInfo<PanelBoxExt> _createDragBoxInfo({String label = '', DragBoxSpec spec = DragBoxSpec.none}){
    return DragBoxInfo.create<PanelBoxExt>(
      builder: widget.onDragBoxBuild,
      ext    : PanelBoxExt(label: label, spec: spec),
    );
  }

  _setText(String text){
    _boxInfoList.clear();
    _sensRectList.clear();

    _boxInfoList.addAll(_splitText(text));
    widget.controller.onChange?.call();

    _rebuildStrNeed = true;
  }

  List<DragBoxInfo<PanelBoxExt>> _splitText(String text) {
    if (text.isEmpty) return [];

    final result = <DragBoxInfo<PanelBoxExt>>[];

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
        result.add(_createDragBoxInfo(label: word));
      }
    }

    return result;
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

      if (_editPosWidth == 0.0) {
        _editPos.refreshSize();
        _editPosWidth   = _editPos.size.width;
      }
      if (_insertPosWidth == 0.0) {
        _insertPos.refreshSize();
        _insertPosWidth = _insertPos.size.width;
      }
      if (_wordBoxHeight == 0.0) {
        _testBox.refreshSize();
        _wordBoxHeight = _testBox.size.height;
      }

      _buildBoxesString(width);

      _testBox.setState(visible: false);
      _insertPos.setState(visible: false);
      _editPos.setState(visible: false);
    }
  }

  RenderBox _getStackRenderBox(){
    return _stackKey.currentContext!.findRenderObject() as RenderBox;
  }

  void _buildBoxesString(double width){
    final prevHeight = _height;
    _height = _wordBoxHeight;

    var position = const Offset(0,0);
    Offset nextPosition;

    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      boxInfo.refreshSize();

      nextPosition = Offset(position.dx + boxInfo.size.width, position.dy);
      if (nextPosition.dx >= width){
        position = Offset(0, position.dy + _wordBoxHeight + widget.lineSpacing);
        nextPosition = Offset(position.dx + boxInfo.size.width, position.dy);
        _height = position.dy + _wordBoxHeight;
      }

      boxInfo.setState(position: position);

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
      final label = _boxInfoList[i].data.ext.label;

      if (ret.isEmpty) {
        ret = label;
      } else {
        ret = '$ret $label';
      }
    }

    return ret;
  }

  String _getWord(int pos){
    return _boxInfoList[pos].data.ext.label;
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
    _boxInfoList.insert(pos, _createDragBoxInfo(label: word));
    widget.controller.onChange?.call();
    _rebuildStrNeed = true;
  }

  int _getFocusPos() {
    if (_focusBox == null) return -1;

    final focusCenter = Offset(_focusBox!.data.position.dx + _focusBox!.size.width / 2, _focusBox!.data.position.dy + _focusBox!.size.height / 2);
    final boxInfo = getBoxAtPos(localPosition : focusCenter, tapOnSensRect : false);
    if (boxInfo == null) return -1;

    final pos = _boxInfoList.indexOf(boxInfo);

    return pos;
  }

  void _setFocusPos(int pos) {
    if (pos < 0 || pos >= _boxInfoList.length) return;

    final boxInfo = _boxInfoList[pos];

    if (boxInfo == _focusBox) return;

    if (_focusBox != null) {
      _focusBox!.data.ext.spec = DragBoxSpec.none;
      _focusBox!.setState();
    }

    boxInfo.data.ext.spec = DragBoxSpec.focus;
  }

  void _hideFocus() {
    if (_focusBox == null) return;

    _focusBox!.data.ext.spec = DragBoxSpec.none;
    _focusBox!.setState();
  }

  int _getCursorPos() {
    if (!_editPos.data.visible) return -1;

    final editPosCenter = Offset(_editPos.data.position.dx + _editPosWidth / 2, _editPos.data.position.dy + _wordBoxHeight/ 2);

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
    if (_boxInfoList.isEmpty) {
      _editPos.setState(
        visible  : true,
        position : Offset(_editPosWidth / 2, 0),
      );
      return;
    }

    if (pos >= _boxInfoList.length) {
      final boxInfo = _boxInfoList.last;
      _editPos.setState(
        visible  : true,
        position : Offset(boxInfo.rect.right - _editPosWidth / 2, boxInfo.rect.center.dy - _wordBoxHeight / 2),
      );
      return;
    }

    if (pos < 0) pos = 0;
    final boxInfo = _boxInfoList[pos];

    _editPos.setState(
      visible  : true,
      position : Offset(boxInfo.rect.left - _editPosWidth / 2, boxInfo.rect.center.dy - _wordBoxHeight / 2),
    );
  }

  void _hideCursor() {
    _editPos.setState(visible: false);
  }

  void _refresh() {
    _starting = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    widget.controller._panelState = this;

    final childList = _boxInfoList.map((boxInfo)=>boxInfo.widget).toList();
    childList.add(_testBox.widget);
    childList.add(_moveBox.widget);
    childList.add(_editPos.widget);
    childList.add(_insertPos.widget);

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

      _moveBox.data.ext.label = boxInfo.data.ext.label;
      _moveBox.setState(visible : false);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_selectedBoxInfo == null) return;

    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(details.globalPosition);

    final moveBoxPosition = Offset(position.dx - _selectInPos!.dx, position.dy - _selectInPos!.dy);
    _moveBox.refreshSize();
    final moveBoxCenter = Offset(moveBoxPosition.dx + _moveBox.size.width / 2, moveBoxPosition.dy + _moveBox.size.height / 2);

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

      if (insertPosVisible) {
        HapticFeedback.heavyImpact();

        _insertPos.setState(
          position: Offset(sensRect!.center.dx - _insertPosWidth / 2, sensRect.center.dy - _wordBoxHeight / 2),
          visible: true,
        );
      } else {
        _insertPos.setState(visible: false);
      }
    }

    _moveBox.data.ext.spec = insertPosVisible ? DragBoxSpec.canDrop : DragBoxSpec.move;
    _moveBox.setState(
      position : moveBoxPosition,
      visible  : true,
    );
  }

  void _onPanEnd(DragEndDetails details) {
    if (_selectedBoxInfo == null) return;

    _moveBox.data.ext.label = '';
    _moveBox.setState(
      visible  : false,
      position : const Offset(0,0),
    );

    if (_insertPos.data.visible) {
      final insertPosCenter = Offset(_insertPos.data.position.dx + _insertPosWidth / 2, _insertPos.data.position.dy + _wordBoxHeight/ 2);
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
        DragBoxInfo<PanelBoxExt>? cursorBoxInfo;
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

      _insertPos.setState(visible: false);
    }

    _selectedBoxInfo = null;
  }

  DragBoxInfo<PanelBoxExt>? getBoxAtPos({Offset? globalPosition, Offset? localPosition, bool tapOnSensRect = true}) {
    var position = localPosition;

    if (position == null && globalPosition != null) {
      final renderBox = _getStackRenderBox();
      position = renderBox.globalToLocal(globalPosition);
    }

    if (position == null) return null;

    if (!widget.controller.noCursor && tapOnSensRect) {
      final sensRect = _sensRectList.firstWhereOrNull((rect)=>rect.contains(position!));
      if (sensRect != null){
        _editPos.setState(
          visible  : true,
          position : Offset(sensRect.center.dx - _editPosWidth / 2, sensRect.center.dy - _wordBoxHeight / 2),
        );
        return null;
      }
    }

    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position!));
    return boxInfo;
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    final boxInfo = getBoxAtPos(globalPosition: details.globalPosition);
    if (boxInfo == null) return;

    bool setFocus = true;

    if (_focusBox != null) {
      if (_focusBox == boxInfo) {
        boxInfo.data.ext.spec = DragBoxSpec.none;
        _focusBox = null;
        setFocus = false;
      } else {
        _focusBox!.data.ext.spec = DragBoxSpec.none;
        _focusBox!.setState();
      }
    }

    if (setFocus) {
      boxInfo.data.ext.spec = DragBoxSpec.focus;
      _focusBox = boxInfo;

      if (widget.controller.focusAsCursor) {
        _hideCursor();
      }
    }

    bool labelChanged = false;

    if (widget.onDragBoxTap != null){
      final newLabel = await widget.onDragBoxTap!.call(boxInfo.data.ext.label, boxInfo.data.position);
      if (newLabel != null ) {
        if (boxInfo.data.ext.label != newLabel) {
          boxInfo.data.ext.label = newLabel;
          labelChanged = true;
        }
      }
    }

    boxInfo.setState();

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

    final newLabel = await onDragTap.call(boxInfo.data.ext.label, boxInfo.data.position);
    if (newLabel == null || boxInfo.data.ext.label == newLabel) return;

    boxInfo.data.ext.label = newLabel;
    boxInfo.setState();

    widget.controller.onChange?.call();

    _rebuildStrNeed = true;
    setState(() {});
  }
}
