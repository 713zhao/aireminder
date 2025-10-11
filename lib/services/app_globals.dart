import 'package:flutter/material.dart';

/// Shared app globals used across services and UI.
/// The `navigatorKey` is used by background services to obtain a BuildContext
/// for showing SnackBars or navigating without importing `main.dart`.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
