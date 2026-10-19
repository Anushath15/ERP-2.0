/// Product codes: made by the program from the product's category, like ELE-0001 for the first product of Electrical.
/// Pure Dart. The running number comes from a gapless counter per prefix (see lib/data/repo/product_codes.dart).
library;

/// The first three English letters of the category in capitals (Electrical -> ELE). A category without at least two English
/// letters (a name typed in another script, only digits) uses GEN.
String productCodePrefix(String category) {
  final letters = category.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  if (letters.length < 2) return 'GEN';
  return letters.substring(0, letters.length < 3 ? letters.length : 3);
}

String formatProductCode(String prefix, int number) => '$prefix-${number.toString().padLeft(4, '0')}';
