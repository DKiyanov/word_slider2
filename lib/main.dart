import 'package:flutter/material.dart';
import 'package:word_slider2/word_panel.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class PanelParam {
  final Color  editPosColor;
  final Color  insertPosColor;
  final Color  colorWordNormal;
  final Color  colorWordSelected;
  final Color  colorWordCanDrop;
  final Color  colorWordMove;
  final double editPosWidth;
  final double insertPosWidth;

  PanelParam({
    this.editPosColor      = Colors.blue,
    this.insertPosColor    = Colors.green,
    this.colorWordNormal   = Colors.grey,
    this.colorWordSelected = Colors.yellow,
    this.colorWordCanDrop  = Colors.amber,
    this.colorWordMove     = Colors.black12,
    this.editPosWidth      = 10,
    this.insertPosWidth    = 10,
  });
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({required this.title, Key? key}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _controller = WordPanelController(text: 'one two three five six seven eight nine ten eleven twelve');
  final _param = PanelParam();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.accessibility),
              onPressed: pressTest,
            )
          ],
        ),
        body: WordPanel(
          controller: _controller,
          onDragBoxBuild: onDragBoxBuild,
          onDragBoxTap: onDragBoxTap,
          onDragBoxLongPress: onDragBoxLongPress,
        )
    );
  }


  Future<String?> onDragBoxTap(String label, Offset position) async {
    return label;
    // boxState.color == _param.colorWordNormal ? boxState.color = _param.colorWordSelected : boxState.color = _param.colorWordNormal;
  }

  Future<String?> onDragBoxLongPress(String label, Offset position) async {
    final value = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 100, position.dy + 100),
        items: [
          const PopupMenuItem(
            value: '1',
            child: Text("View"),
          ),
          const PopupMenuItem(
            value: '2',
            child: Text("Edit"),
          ),
          const PopupMenuItem(
            value: '3',
            child: Text("Delete"),
          ),
        ]
    );

    return value;
  }

  Widget onDragBoxBuild(BuildContext context, String label, DragBoxSpec spec, Offset position) {
    if (spec == DragBoxSpec.editPos){
      return Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              color: _param.editPosColor,
            ),
            width: _param.editPosWidth,
            height: _controller.wordBoxHeight,
          )
      );
    }

    if (spec == DragBoxSpec.insertPos){
      return Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              color: _param.insertPosColor,
            ),
            width: _param.insertPosWidth,
            height: _controller.wordBoxHeight,
          )
      );
    }

    var color = _param.colorWordNormal;
    if (spec == DragBoxSpec.move) {
      color = _param.colorWordMove;
    }
    if (spec == DragBoxSpec.canDrop) {
      color = _param.colorWordCanDrop;
    }
    if (spec == DragBoxSpec.focus) {
      color = _param.colorWordSelected;
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

  void pressTest(){
    final curPos = _controller.getCursorPos();
    _controller.deleteWord(curPos);
    _controller.insertText(curPos, '123 456');
    _controller.refreshPanel();
  }
}
