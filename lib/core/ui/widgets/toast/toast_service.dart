import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum ToastType { info, success, error, warning }

class ToastMessage {
  final String id;
  final String title;
  final String? description;
  final ToastType type;
  final Duration duration;

  const ToastMessage({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.duration = const Duration(seconds: 4),
  });
}

class ToastNotifier extends StateNotifier<List<ToastMessage>> {
  ToastNotifier() : super([]);

  static const int maxVisibleToasts = 3;

  void show({
    required String title,
    String? description,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final id = const Uuid().v4();
    final toast = ToastMessage(
      id: id,
      title: title,
      description: description,
      type: type,
      duration: duration,
    );

    final next = [...state, toast];
    if (next.length > maxVisibleToasts) {
      state = next.sublist(next.length - maxVisibleToasts);
    } else {
      state = next;
    }

    // Auto-dismiss
    Future.delayed(duration, () => dismiss(id));
  }

  void dismiss(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final toastProvider = StateNotifierProvider<ToastNotifier, List<ToastMessage>>((
  ref,
) {
  return ToastNotifier();
});
