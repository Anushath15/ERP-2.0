/// The result of writing the new data file from an ERP 1 backup (plain data, safe to send between isolates).
class ImportOutcome {
  ImportOutcome({required this.ok, this.error = '', this.newFile = '', this.verified = false, this.mismatches = const [], this.selfCheckProblems = const [], this.integrity = '', this.counts = const {}, this.millis = 0});
  final bool ok, verified;
  final String error, newFile, integrity;
  final List<String> mismatches, selfCheckProblems;
  final Map<String, int> counts; // what the NEW file holds, read back from it
  final int millis;

  /// Every check passed: written, read back equal to the backup, integrity ok, the program's own check found nothing.
  bool get allChecksPassed => ok && verified && mismatches.isEmpty && selfCheckProblems.isEmpty && integrity == 'ok';

  static ImportOutcome failed(String message) => ImportOutcome(ok: false, error: message);
}
