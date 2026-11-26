import 'package:flutter/widgets.dart';

/// A design's empty-state illustration rendered in Blender: the looping WebP,
/// or its still first frame when animations are reduced.
String emptyArtAsset(BuildContext context, String design) {
  final ext = MediaQuery.disableAnimationsOf(context) ? 'png' : 'webp';
  return 'assets/designs/$design/empty.$ext';
}
