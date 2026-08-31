import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'binary_locator.dart';
import 'process_runner.dart';

final binaryLocatorProvider = Provider<BinaryLocator>((ref) => BinaryLocator());
final processRunnerProvider = Provider<ProcessRunner>((ref) => ProcessRunner());
