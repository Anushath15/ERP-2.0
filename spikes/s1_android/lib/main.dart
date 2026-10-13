// Spike S1 on Android: sign-in + sync over the REST layer, against the Firebase emulator on the host (10.0.2.2).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'engine.dart';
import 'rest.dart';

void main() => runApp(const MaterialApp(home: Home()));

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final log = StringBuffer();
  String text = 'running...';

  void say(String s) {
    log.writeln(s);
    debugPrint('SYNC $s');
  }

  @override
  void initState() {
    super.initState();
    run().then((_) => setState(() => text = log.toString())).catchError((Object e) {
      say('FAILED $e');
      setState(() => text = log.toString());
    });
  }

  Future<void> run() async {
    final client = http.Client();
    final auth = AuthRest(client);
    final email = 'android${DateTime.now().microsecondsSinceEpoch}@example.com';
    var sw = Stopwatch()..start();
    final s = await auth.signUp(email, 'secret-pass-1');
    await auth.verifyEmailViaEmulator(s);
    await auth.refresh(s);
    say('sign up + verify e-mail + refresh token: ${sw.elapsedMilliseconds} ms');
    final shop = 'shop-android-${DateTime.now().microsecondsSinceEpoch}';
    const base = 'projects/$projectId/databases/(default)/documents';
    final r = await client.post(Uri.parse('$fsBase/v1/$base:commit'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.idToken}'},
        body: '{"writes":[{"update":{"name":"$base/shops/$shop","fields":{"ownerEmail":{"stringValue":"$email"}}}},'
            '{"update":{"name":"$base/shops/$shop/members/$email","fields":{"role":{"stringValue":"owner"}}}}]}');
    say('create shop: HTTP ${r.statusCode}');
    final remote = RestRemote(FirestoreRest(client, s), shop);
    const u = Uuid();
    final dir = Directory.systemTemp.path;
    final a = Engine('$dir/a_${DateTime.now().microsecondsSinceEpoch}.sqlite', 'A', batchSize: 100);
    for (var i = 0; i < 600; i++) {
      a.save('bills', u.v7(), {'number': 'A-$i', 'total': i * 100});
    }
    sw = Stopwatch()..start();
    await a.pushAll(remote);
    say('push 600 bills (batches of 100): ${sw.elapsedMilliseconds} ms, pending left ${a.pendingCount}, server writes ${remote.fs.writes}');
    final b = Engine('$dir/b_${DateTime.now().microsecondsSinceEpoch}.sqlite', 'B');
    sw = Stopwatch()..start();
    await b.pull(remote, const ['bills']);
    say('fresh device pulls all: ${sw.elapsedMilliseconds} ms, records ${b.recordCount}, reads ${remote.fs.reads}');
    say(b.snapshot('bills').length == 600 && a.snapshot('bills').toString() == b.snapshot('bills').toString() ? 'RESULT PASS: both devices identical (600 bills)' : 'RESULT FAIL');
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: SingleChildScrollView(child: Text(text))));
}
