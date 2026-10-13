import 'device_store.dart';

DeviceStore createPlatformStore(DeviceStore Function() fallback) => fallback();
