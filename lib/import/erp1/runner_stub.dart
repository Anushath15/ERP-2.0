import 'outcome.dart';
import 'preview.dart';

/// The browser build cannot swap database files, so it cannot import.
const bool importSupported = false;

Future<ImportPreview> previewInBackground(String text, String fileName) async => previewFromText(text, fileName);

Future<ImportOutcome> writeNewShopFile({required String text, required String fileName, required String outPath, void Function(String stage)? onStage}) async =>
    ImportOutcome.failed('Importing needs the Windows or Mac program.');
