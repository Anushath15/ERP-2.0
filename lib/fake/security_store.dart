import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sample data for the Security card (Phase 1). In Phase 2 the same screen reads the people from the deployed rules lists and
// the devices and sign-ins from Firestore; only the owner may approve or revoke (the rules enforce it).

enum Role { owner, manager, cashier }

enum DeviceState { pending, approved, revoked }

class SamplePerson {
  const SamplePerson(this.email, this.role);
  final String email;
  final Role role;
}

class SampleDevice {
  const SampleDevice(this.id, this.name, this.email, this.state, this.lastSeen);
  final String id, name, email, lastSeen;
  final DeviceState state;
  SampleDevice withState(DeviceState s) => SampleDevice(id, name, email, s, lastSeen);
}

class SampleSignIn {
  const SampleSignIn(this.email, this.device, this.when);
  final String email, device, when;
}

/// A stopped device can never be switched back on by a tap: that person must ask again from the device (a new request).
bool canApprove(SampleDevice d) => d.state == DeviceState.pending;

const samplePeople = [
  SamplePerson('owner@example.com', Role.owner),
  SamplePerson('partner@example.com', Role.owner),
  SamplePerson('manager@example.com', Role.manager),
  SamplePerson('counter@example.com', Role.cashier),
];

const sampleSignIns = [
  SampleSignIn('counter@example.com', 'Billing counter PC', 'Today 9:02 am'),
  SampleSignIn('owner@example.com', "Owner's phone", 'Today 8:40 am'),
  SampleSignIn('manager@example.com', 'Shop laptop', 'Yesterday 6:15 pm'),
];

class DevicesNotifier extends Notifier<List<SampleDevice>> {
  @override
  List<SampleDevice> build() => const [
        SampleDevice('dev-owner', "Owner's phone", 'owner@example.com', DeviceState.approved, 'Today 8:40 am'),
        SampleDevice('dev-counter', 'Billing counter PC', 'counter@example.com', DeviceState.approved, 'Today 9:02 am'),
        SampleDevice('dev-pending', 'New laptop', 'manager@example.com', DeviceState.pending, 'Today 10:11 am'),
      ];

  void setState(String id, DeviceState s) => state = [for (final d in state) if (d.id == id) d.withState(s) else d];
}

final devicesProvider = NotifierProvider<DevicesNotifier, List<SampleDevice>>(DevicesNotifier.new);
