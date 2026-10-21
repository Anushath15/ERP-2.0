/// Did somebody else change this product while it was open on this screen? (The cloud sync or the counter link can change a product on this computer
/// at any moment.) Pure Dart.
library;

import 'models.dart';

/// True when [current] (what the database holds now) differs from [opened] (what the person was shown) in anything they could be editing.
/// The stock figure is left out: it moves with every sale and is not edited in the same way.
bool productChangedElsewhere(Product opened, Product current) =>
    opened.name != current.name ||
    opened.category != current.category ||
    opened.unit != current.unit ||
    opened.pricePaise != current.pricePaise ||
    opened.costPaise != current.costPaise ||
    opened.mrpPaise != current.mrpPaise ||
    opened.gstBp != current.gstBp ||
    opened.barcode != current.barcode ||
    opened.hsn != current.hsn ||
    opened.minStockMilli != current.minStockMilli ||
    opened.brand != current.brand;
