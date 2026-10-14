import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A new record id: UUIDv7 (time-ordered, so new rows land at the end of the index and ids from different devices never clash).
String newId() => _uuid.v7();
