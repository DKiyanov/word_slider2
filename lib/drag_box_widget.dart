import 'package:flutter/material.dart';

enum DragBoxSpec {
  none,
  move,
  canDrop,
  focus,
  insertPos,
  editPos,
  isGroup,
}

typedef DragBoxBuilder = Widget Function(BuildContext context, String label, DragBoxSpec spec);


class DragBoxData{
  String label;
  Offset position;
  bool   visible;
  DragBoxSpec spec;

  DragBoxData({
    this.label    = '',
    this.position =  const Offset(0.0, 0.0),
    this.visible  = true,
    this.spec     = DragBoxSpec.none,
  });
}

class DragBoxInfo{
  final DragBox widget;
  final DragBoxData data;

  DragBoxInfo({required this.widget, required this.data});

  Size size = Size.zero;
  Rect get rect => Rect.fromLTWH(data.position.dx, data.position.dy, size.width, size.height);

  void setState({
    String?      label,
    Offset?      position,
    bool?        visible,
    DragBoxSpec? spec,
  }){
    if (label != null) {
      data.label = label;
    }
    if (position != null) {
      data.position = position;
    }
    if (visible != null) {
      data.visible = visible;
    }
    if (spec != null) {
      data.spec = spec;
    }

    final boxKey = widget.key as GlobalKey<DragBoxState>;
    if (boxKey.currentState != null && boxKey.currentState!.mounted) {
      boxKey.currentState!.setState(() {});
    }
  }

  void refreshSize() {
    final boxKey = widget.key as GlobalKey<DragBoxState>;
    final renderBox = boxKey.currentContext!.findRenderObject() as RenderBox;
    size = renderBox.size;
  }

  static DragBoxInfo create({required DragBoxBuilder builder, String label = '', DragBoxSpec spec = DragBoxSpec.none}){
    final boxData = DragBoxData(label: label, spec: spec);

    return DragBoxInfo(
      widget : DragBox(
          data    : boxData,
          onBuild : builder,
          key     : GlobalKey<DragBoxState>()
      ),

      data : boxData,
    );
  }
}

class DragBox extends StatefulWidget {
  final DragBoxData data;
  final DragBoxBuilder onBuild;

  const DragBox({required this.data, required this.onBuild, Key? key})  : super(key: key);

  @override
  State<DragBox> createState() => DragBoxState();
}

class DragBoxState extends State<DragBox> {

  @override
  Widget build(BuildContext context) {
    if (!widget.data.visible){
      return Positioned(
          left : 0,
          top  : 0,
          child: Container()
      );
    }

    return Positioned(
        left  : widget.data.position.dx,
        top   : widget.data.position.dy,
        child : widget.onBuild.call(context, widget.data.label, widget.data.spec)
    );
  }
}
