import 'package:flutter/material.dart';

import 'ml_tools_screen.dart';

/// Compatibility route for older code referencing MlKitToolsScreen.
/// All image features are implemented by the current MlToolsScreen.
class MlKitToolsScreen extends StatelessWidget {
  const MlKitToolsScreen({super.key});

  @override
  Widget build(BuildContext context) => const MlToolsScreen();
}
