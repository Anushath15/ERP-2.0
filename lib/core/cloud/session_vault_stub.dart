import 'session_vault.dart';

/// No disk in a browser: the sign-in is not kept (the person signs in again when the page is reopened).
SessionVault createVault(SessionVault Function() fallback, {String file = 'session.bin'}) => fallback();
