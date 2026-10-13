import 'dart:isolate';
import 'package:flutter/material.dart';
import 'bench.dart';

void main() => runApp(const MaterialApp(home: Home()));

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String text = 'running...';
  int frames = 0;
  @override
  void initState() {
    super.initState();
    Isolate.run(() => runBench(['5000', '5000', '50000', 'FULL'])).then((r) {
      debugPrint('BENCH_RESULT_BEGIN\n\\nBENCH_RESULT_END');
      setState(() => text = r);
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: SingleChildScrollView(child: Text(text, style: const TextStyle(fontSize: 11)))));
}
