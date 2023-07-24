import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({required this.title, Key? key}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final wordPanelKey = GlobalKey<WordPanelState>();

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
        body: WordPanel(key: wordPanelKey, text: 'one two three five six seven eight nine ten eleven twelve')
    );
  }

  void pressTest(){
    final wordPanelState = wordPanelKey.currentState!;

//    print('text = ${ wordPanelState.getText() }');

    wordPanelState.setState((){
      final curPos = wordPanelState.getCursorPos();
      wordPanelState.deleteWord(curPos);
      wordPanelState.insertText(curPos, '123 456');
//      wordPanelState.setText('123 456 789');
    });
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

const double sensWidth = 20; // the width of the sensitive zone at the ends of words, used when dragging and taping
const double lineSpacing = 5; // line spacing
const editPosLabel = '@|@';
const insertPosLabel = '@^@';
const double editPosWidth = 10;
const double insertPosWidth = 10;
const colorWordNormal = Colors.grey;
const colorWordSelected = Colors.yellow;
const colorWordCanDrop = Colors.amber;
const colorWordMove = Colors.black12;

double wordBoxHeight = 1;

class WordPanel extends StatefulWidget{
  final String text;

  const WordPanel({required this.text, Key? key}) : super(key: key);

  @override
  State<WordPanel> createState() => WordPanelState();
}

class WordPanelState extends State<WordPanel> {
  final stackKey = GlobalKey();
  final boxInfoList = <DragBoxInfo>[];
  final sensRectList = <Rect>[];
  DragBoxInfo? selectedBoxInfo;
  final moveBox = DragBox(key: GlobalKey<DragBoxState>(), label: '', color: colorWordMove);
  final editPos = DragBox(key: GlobalKey<DragBoxState>(), label: editPosLabel);

  final insertPos = DragBox(key: GlobalKey<DragBoxState>(), label: insertPosLabel);
  bool insertPosVisible = false;

  Offset? selectInPos;
  String text = '';
  bool rebuildStrNeed = false;

  Size? _prevStackSize;

  @override
  void initState() {
    super.initState();

    setText(widget.text);
  }

  setText(String text){
    boxInfoList.clear();
    sensRectList.clear();
    this.text = text;

    text.split(' ').forEach((word){
      boxInfoList.add(DragBoxInfo(DragBox(label: word, color: colorWordNormal, key: GlobalKey<DragBoxState>())));
    });
    rebuildStrNeed = true;
  }

  rebuildStr(){
    if (!rebuildStrNeed) {
      // We check if the dimensions of the panel have changed, if they have changed - the line needs to be rebuilt
      final stackSize = (stackKey.currentContext!.findRenderObject() as RenderBox).size;
      if (_prevStackSize != null) {
        if (stackSize.width != _prevStackSize!.width || stackSize.height != _prevStackSize!.height){
          rebuildStrNeed = true;
        }
      }
      _prevStackSize = stackSize;
    }

    if (rebuildStrNeed) {
      rebuildStrNeed = false;
      getBoxesRect();
      buildBoxesString();

      wordBoxHeight = boxInfoList[0].rect.height;

      dragBoxKey(insertPos).currentState!.setState((){
        dragBoxKey(insertPos).currentState!.visible = false;
      });
    }
  }

  void getBoxesRect(){
    final renderBox = stackKey.currentContext!.findRenderObject() as RenderBox;

    for (var boxInfo in boxInfoList) {
      final boxKey = dragBoxKey(boxInfo.boxWidget);
      final boxRenderBox = boxKey.currentContext!.findRenderObject() as RenderBox;
      final boxSize = boxRenderBox.size;
      final boxPos  = renderBox.globalToLocal(boxRenderBox.localToGlobal(Offset.zero));
      boxInfo.rect = Rect.fromLTWH(boxPos.dx, boxPos.dy, boxSize.width, boxSize.height);
    }
  }

  void buildBoxesString(){
    wordBoxHeight = boxInfoList[0].rect.height;

    final stackSize = (stackKey.currentContext!.findRenderObject() as RenderBox).size;
    var position = const Offset(0,0);
    Offset nextPosition;

    for (var i = 0; i < boxInfoList.length; i++) {
      final boxInfo = boxInfoList[i];
      final boxKey = dragBoxKey(boxInfo.boxWidget);

      nextPosition = Offset(position.dx + boxInfo.rect.width, position.dy);
      if (nextPosition.dx >= stackSize.width){
        position = Offset(0, position.dy + wordBoxHeight + lineSpacing);
        nextPosition = Offset(position.dx + boxInfo.rect.width, position.dy);
      }

      boxKey.currentState!.setState((){
        boxInfo.rect = Rect.fromLTWH(position.dx, position.dy, boxInfo.rect.width, boxInfo.rect.height);
        boxKey.currentState!.position = position;
      });

      position = nextPosition;
    }

    final editPosState = dragBoxKey(editPos).currentState;
    editPosState!.setState((){
      editPosState.position = position;
    });

    fillSensRectList();
  }

  void fillSensRectList(){
    sensRectList.clear();

    if (boxInfoList.isEmpty) return;

    final firstBox = boxInfoList[0];
    final dy = firstBox.rect.height / 2;
    final sensHeight = firstBox.rect.height + lineSpacing;

    sensRectList.add(Rect.fromCenter(center: Offset(firstBox.rect.left, firstBox.rect.top + dy), width: sensWidth, height: sensHeight ));

    for (var boxInfo in boxInfoList) {
      sensRectList.add(Rect.fromCenter(center: Offset(boxInfo.rect.right, boxInfo.rect.top + dy), width: sensWidth, height: sensHeight ));
    }
  }

  String getText(){
    String ret = '';

    for (var i = 0; i < boxInfoList.length; i++) {
      final label = dragBoxKey(boxInfoList[i].boxWidget).currentState!.label;

      if (ret.isEmpty) {
        ret = label;
      } else {
        ret = '$ret $label';
      }
    }

    return ret;
  }

  String getWord(int pos){
    return dragBoxKey(boxInfoList[pos].boxWidget).currentState!.label;
  }

  void deleteWord(int fromPos, [int count = 1]){
    for (var i = fromPos; i < fromPos + count; i++) {
      boxInfoList.removeAt(fromPos);
    }
    buildBoxesString();
  }

  void insertText(int pos, String text){
    int lPos = pos;
    text.split(' ').forEach((word){
      boxInfoList.insert(lPos, DragBoxInfo(DragBox(label: word, color: colorWordNormal, key: GlobalKey<DragBoxState>())));
      lPos += 1;
    });
    rebuildStrNeed = true;
  }

  int getCursorPos(){
    final editPosState = dragBoxKey(editPos).currentState;
    final editPosCenter = Offset(editPosState!.position.dx + editPosWidth / 2, editPosState.position.dy +  wordBoxHeight/ 2);
    int editIndex = 0;
    for (var i = 0; i < boxInfoList.length; i++) {
      final boxInfo = boxInfoList[i];
      if (boxInfo.rect.top < editPosCenter.dy && boxInfo.rect.bottom > editPosCenter.dy && boxInfo.rect.left < editPosCenter.dx){
        editIndex = i;
      }
    }

    return editIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    final childList = boxInfoList.map((boxInfo)=>boxInfo.boxWidget).toList();
    childList.add(moveBox);
    childList.add(editPos);
    childList.add(insertPos);

    return OrientationBuilder( builder: (context, orientation) {

      WidgetsBinding.instance.addPostFrameCallback((_){
        rebuildStr();
      });

      return GestureDetector(
          onPanStart: (details) => _onPanStart(details),
          onPanUpdate: (details) => _onPanUpdate(details),
          onPanEnd: (details) => _onPanEnd(details),
          onTapUp: (details)=> _onTapUp(details),
          child: Stack(
            key : stackKey,
            children: childList,
          )
      );
    });
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = stackKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);

    final boxInfo = boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    if (boxInfo != null){
      selectedBoxInfo = boxInfo;
      selectInPos = Offset(position.dx - boxInfo.rect.left, position.dy - boxInfo.rect.top);
      final moveBoxKey = moveBox.key as GlobalKey<DragBoxState>;

      moveBoxKey.currentState!.setState((){
        moveBoxKey.currentState!.label = boxInfo.boxWidget.label;
        moveBoxKey.currentState!.visible = false;
      });
    }
  }
  void _onPanUpdate(DragUpdateDetails details) {
    if (selectedBoxInfo == null) return;

    final renderBox = stackKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);

    final moveBoxKey = dragBoxKey(moveBox);
    final moveBoxPosition = Offset(position.dx - selectInPos!.dx, position.dy - selectInPos!.dy);
    final moveBoxSize = (moveBoxKey.currentContext!.findRenderObject() as RenderBox).size;
    final moveBoxCenter = Offset(moveBoxPosition.dx + moveBoxSize.width / 2, moveBoxPosition.dy + moveBoxSize.height / 2);

    final sensRect = sensRectList.firstWhereOrNull ((rect)=>rect.contains(moveBoxCenter));
    final bool insertPosNeed = (sensRect != null);

    if (insertPosVisible != insertPosNeed ) {
      moveBoxKey.currentState!.setState((){
        moveBoxKey.currentState!.color = insertPosNeed ? colorWordCanDrop : colorWordMove;
      });

      if ( insertPosNeed ){
        HapticFeedback.heavyImpact();
      }

      insertPosVisible = insertPosNeed;

      final insertPosState = dragBoxKey(insertPos).currentState;
      if (insertPosNeed) {
        int insertIndex = 0;
        int selIndex = 0;
        for (var i = 0; i < boxInfoList.length; i++) {
          final boxInfo = boxInfoList[i];
          if (boxInfo == selectedBoxInfo){
            selIndex = i;
          }
          if (boxInfo.rect.top < sensRect.center.dy && boxInfo.rect.bottom > sensRect.center.dy && boxInfo.rect.left < sensRect.center.dx){
            insertIndex = i;
          }
        }
        insertIndex += 1;

        if (insertIndex != selIndex && insertIndex != (selIndex + 1)){
          insertPosState!.setState((){
            insertPosState.position = Offset(sensRect.center.dx - insertPosWidth / 2, sensRect.center.dy - wordBoxHeight / 2);
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
    if (selectedBoxInfo == null) return;

    final moveBoxKey = dragBoxKey(moveBox);
    moveBoxKey.currentState!.setState(() {
      moveBoxKey.currentState!.label = '';
      moveBoxKey.currentState!.visible = false;
      moveBoxKey.currentState!.position = const Offset(0,0);
    });

    final insertPosState = dragBoxKey(insertPos).currentState;
    if (insertPosState!.visible) {
      final insertPosCenter = Offset(insertPosState.position.dx + insertPosWidth / 2, insertPosState.position.dy +  wordBoxHeight/ 2);
      int insertIndex = 0;
      int selIndex = 0;
      for (var i = 0; i < boxInfoList.length; i++) {
        final boxInfo = boxInfoList[i];
        if (boxInfo == selectedBoxInfo){
          selIndex = i;
        }
        if (boxInfo.rect.top < insertPosCenter.dy && boxInfo.rect.bottom > insertPosCenter.dy && boxInfo.rect.left < insertPosCenter.dx){
          insertIndex = i;
        }
      }
      insertIndex += 1;

      if (selIndex != insertIndex){
        final boxInfo = boxInfoList[selIndex];
        boxInfoList.removeAt(selIndex);
        if (selIndex < insertIndex){
          insertIndex -= 1;
        }
        boxInfoList.insert(insertIndex, boxInfo);

        buildBoxesString();
      }

      insertPosState.setState((){
        insertPosState.visible = false;
      });

    }

    selectedBoxInfo = null;
  }

  void _onTapUp(TapUpDetails details){
    final renderBox = stackKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);

    final sensRect = sensRectList.firstWhereOrNull((rect)=>rect.contains(position));
    if (sensRect != null){
      final editPosState = dragBoxKey(editPos).currentState;
      editPosState!.setState((){
        editPosState.position = Offset(sensRect.center.dx - editPosWidth / 2, sensRect.center.dy - wordBoxHeight / 2);
      });
      return;
    }

    final boxInfo = boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));
    if (boxInfo != null){
      final boxState = dragBoxKey(boxInfo.boxWidget).currentState;
      boxState!.setState((){
        boxState.color == colorWordNormal ? boxState.color = colorWordSelected : boxState.color = colorWordNormal;
      });
      return;
    }
  }

}

class DragBox extends StatefulWidget {
  final String label;
  final Color color;

  const DragBox({this.label = '', this.color = Colors.white, Key? key})  : super(key: key);

  @override
  State<DragBox> createState() => DragBoxState();
}

class DragBoxState extends State<DragBox> {
  Offset position = const Offset(0.0, 0.0);
  String label = '';
  bool visible = true;
  Color color = Colors.white;

  DragBoxState();

  @override
  void initState() {
    super.initState();

    label = widget.label;
    color = widget.color;
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

    if (label == editPosLabel){
      return Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(3)),
              color: Colors.blue,
            ),
            width: editPosWidth,
            height: wordBoxHeight,
          )
      );
    }

    if (label == insertPosLabel){
      return Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(3)),
              color: Colors.green,
            ),
            width: insertPosWidth,
            height: wordBoxHeight,
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
