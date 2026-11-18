import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explicit opt-in for the separate `--showcase` process. Production stays false.
final showcaseModeProvider = Provider<bool>((ref) => false);
