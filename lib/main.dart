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

class MyHomePage extends StatefulWidget {
  const MyHomePage({required this.title, Key? key}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final controller = WordPanelController(text: 'one two three five six seven eight nine ten eleven twelve');

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
//          key: wordPanelKey,
          controller: controller,
          param: WordPanelParam(),
        )
    );
  }

  void pressTest(){
    final curPos = controller.getCursorPos();
    controller.deleteWord(curPos);
    controller.insertText(curPos, '123 456');
    controller.refreshPanel();
  }
}
