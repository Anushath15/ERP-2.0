/// The moving (weighted) average buying cost, the way Tally, Zoho Inventory and ERPNext value stock. Pure Dart, integer paise.
library;

import '../core/money.dart';

/// The average cost per unit after [inMilli] more arrive at [inCost]: (stock x its cost + arrival x its cost) / (stock + arrival), rounded half-up to a paisa.
/// Stock that is nil or negative carries no value, so the arrival's own cost is the average. Costs are per unit without GST.
int movingAverage({required int haveMilli, required int haveCost, required int inMilli, required int inCost}) {
  if (inMilli <= 0) return haveCost;
  if (haveMilli <= 0 || haveCost <= 0) return inCost;
  return divRound(haveMilli * haveCost + inMilli * inCost, haveMilli + inMilli);
}
