import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../plugins/feature_activation.dart';
import '../platform/platform_info.dart';
import '../../l10n/l10n_ext.dart';

class PluginRouteGate extends ConsumerWidget {
  const PluginRouteGate({
    required this.pluginId,
    required this.child,
    super.key,
  });

  final String pluginId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activation = ref.watch(featureActivationProvider);
    final descriptor = ref.watch(featureCatalogProvider).byId[pluginId];
    if (descriptor?.supportsPlatform(
              PlatformInfo.isAndroid ? 'android' : 'windows',
            ) ==
            true &&
        activation.isEnabledById(pluginId)) {
      return child;
    }
    final l10n = context.l10n;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.extension_off_outlined,
                  size: 36,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.pluginInactiveTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pluginInactiveBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go(
                    '/settings/plugins?plugin=${Uri.encodeQueryComponent(pluginId)}',
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(l10n.pluginManage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
