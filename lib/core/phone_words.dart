/// The program's texts were written for a computer. On a real phone or tablet (see `isTouchDevice`) the generated `PhoneStrings` runs each text that
/// mentions "the computer", Windows or keyboard keys through this, so the phone says "this phone", never "Press F2" or "If Windows asks".
/// One list of replacements (longest and most specific first), so a new text that says "this computer" is reworded without anyone remembering to.
String phoneWords(String text) {
  var t = text;
  for (final r in _rules) {
    t = t.replaceAll(r.$1, r.$2);
  }
  return t;
}

const _rules = <(String, String)>[
  ('Press F2 or tap New bill.', 'Tap New bill.'),
  (' Keys: Ctrl and + or -, and Ctrl 0 to reset.', ''),
  ('If Windows asks to allow the program on the network, choose Allow (private network).', 'Both devices must be on the same shop Wi-Fi. The link works while the program is open on this phone.'),
  (', or Windows blocked it', ''),
  ('Windows or your phone', 'your phone'),
  ('Windows print window', 'print window'),
  ("This computer's address", 'The address of this phone'),
  ("this computer's own address", 'the address of this phone'),
  ('Match my computer', 'Match my phone'),
  ('the computer shows', 'the program shows'),
  ('Each computer in your shop', 'Each phone or computer in your shop'),
  ('two computers', 'two devices'),
  ('another computer', 'another device'),
  ('Another computer', 'Another device'),
  ('other computers', 'other devices'),
  ('slow computers', 'slow phones'),
  ('THIS computer', 'THIS phone'),
  ('this computer', 'this phone'),
  ('This computer', 'This phone'),
  ('your computer', 'your phone'),
  ('Your computer', 'Your phone'),
  ('my computer', 'my phone'),
  ('The computer could', 'The phone could'),
  ('the computer is', 'the phone is'),
  ('the computer beep', 'the phone beep'),
];
