/// Which operating system the program really runs on (not the look it is drawn in, which tests set to Android by default).
library;

export 'os_stub.dart' if (dart.library.io) 'os_io.dart';
