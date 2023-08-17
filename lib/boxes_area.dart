import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'drag_box_widget.dart';

typedef DragBoxTap = Future<bool?> Function(DragBoxInfo? boxInfo, Offset position);
typedef OnChangeSize = void Function(double newWidth, double newHeight);
typedef OnRebuildLayout = void Function(BoxConstraints viewportConstraints, List<DragBoxInfo> boxInfoList);

class BoxesArea extends StatefulWidget {
  final List<DragBoxInfo> boxInfoList;
  final OnRebuildLayout   onRebuildLayout;
  final DragBoxTap?       onDragBoxTap;
  final OnChangeSize?     onChangeSize;

  const BoxesArea({
    required this.boxInfoList,
    required this.onRebuildLayout,
    this.onDragBoxTap,
    this.onChangeSize, Key? key
  }) : super(key: key);

  @override
  State<BoxesArea> createState() => _BoxesAreaState();
}

class _BoxesAreaState extends State<BoxesArea> {
  final _stackKey = GlobalKey();
  bool  _starting = true;
  bool  _refresh  = false;

  double _width = 0.0;
  double _height = 0.0;

  @override
  Widget build(BuildContext context) {
    _starting = false;
    _refresh  = false;

    final childList = widget.boxInfoList.map((boxInfo)=>boxInfo.widget).toList();

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {

      WidgetsBinding.instance.addPostFrameCallback((_){
        _calcSize(viewportConstraints);

        if (_refresh || _starting) {
          setState(() {});
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
            height: _height,

            child: Stack(
              key : _stackKey,
              children: childList,
            ),
          ),
        ),
      );

    });
  }

  void _calcSize(BoxConstraints viewportConstraints) {
    for (var boxInfo in widget.boxInfoList) {
      if (!boxInfo.data.visible) continue;
      boxInfo.refreshSize();
    }

    widget.onRebuildLayout.call(viewportConstraints, widget.boxInfoList);

    double width  = 0.0;
    double height = 0.0;

    for (var boxInfo in widget.boxInfoList) {
      if (!boxInfo.data.visible) continue;

      final right = boxInfo.data.position.dx + boxInfo.size.width;
      if (width < right) {
        width = right;
      }

      final bottom = boxInfo.data.position.dy + boxInfo.size.height;
      if (height < bottom) {
        height = bottom;
      }
    }

    if (_width != width || _height != height) {
      _width  = width;
      _height = height;
      _refresh = true;

      widget.onChangeSize?.call(width, height);
    }
  }

  RenderBox _getStackRenderBox(){
    return _stackKey.currentContext!.findRenderObject() as RenderBox;
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    if (widget.onDragBoxTap == null) return;

    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(details.globalPosition);
    final boxInfo = widget.boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));

    widget.onDragBoxTap!.call(boxInfo, position);
  }

}