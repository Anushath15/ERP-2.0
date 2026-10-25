import 'reveal_file.dart';

FileRevealer createRevealer() => _NoReveal();

class _NoReveal implements FileRevealer {
  @override
  Future<void> reveal(String path) async {}
}
