import 'dart:typed_data';
import 'dart:io';

import 'package:image/image.dart' as image;

const _iconSizes = <int>[16, 32, 48, 96, 128];

Future<void> main(List<String> arguments) async {
  final root = Directory.current;
  final source = File(
    '${root.path}${Platform.pathSeparator}windows${Platform.pathSeparator}'
    'runner${Platform.pathSeparator}resources${Platform.pathSeparator}'
    'app_icon.ico',
  );

  if (!await source.exists()) {
    stderr.writeln('Missing source icon: ${source.path}');
    exitCode = 1;
    return;
  }

  try {
    final sourceBytes = await source.readAsBytes();
    final sourceImage = image.IcoDecoder().decodeImageLargest(sourceBytes);
    if (sourceImage == null) {
      stderr.writeln('Unable to decode source icon: ${source.path}');
      exitCode = 1;
      return;
    }

    final extensionIcons = Directory(
      '${root.path}${Platform.pathSeparator}extension${Platform.pathSeparator}'
      'shared${Platform.pathSeparator}icons',
    );
    final trayIcons = Directory(
      '${root.path}${Platform.pathSeparator}assets${Platform.pathSeparator}icons',
    );
    await extensionIcons.create(recursive: true);
    await trayIcons.create(recursive: true);

    for (final size in _iconSizes) {
      final icon = image.copyResize(sourceImage, width: size, height: size);
      final destination = File(
        '${extensionIcons.path}${Platform.pathSeparator}icon$size.png',
      );
      await destination.writeAsBytes(image.encodePng(icon));
    }

    final trayIcon16 = image.copyResize(sourceImage, width: 16, height: 16);
    final trayIcon32 = image.copyResize(sourceImage, width: 32, height: 32);
    trayIcon16.addFrame(trayIcon32);
    final trayDestination = File(
      '${trayIcons.path}${Platform.pathSeparator}tray.ico',
    );
    await trayDestination.writeAsBytes(image.encodeIco(trayIcon16));
    await _verifyTrayIcon(trayDestination);

    stdout.writeln('Generated extension icons and ${trayDestination.path}.');
  } on FileSystemException catch (error) {
    stderr.writeln('Failed to write icons: $error');
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Failed to generate icons: $error');
    exitCode = 1;
  }
}

Future<void> _verifyTrayIcon(File trayIcon) async {
  final bytes = await trayIcon.readAsBytes();
  if (bytes.length < 38) {
    throw const FormatException('Tray icon is too small.');
  }

  final data = ByteData.sublistView(bytes);
  final isIcon =
      data.getUint16(0, Endian.little) == 0 &&
      data.getUint16(2, Endian.little) == 1;
  final imageCount = data.getUint16(4, Endian.little);
  final firstWidth = bytes[6];
  final firstHeight = bytes[7];
  final secondWidth = bytes[22];
  final secondHeight = bytes[23];

  if (!isIcon ||
      imageCount != 2 ||
      firstWidth != 16 ||
      firstHeight != 16 ||
      secondWidth != 32 ||
      secondHeight != 32) {
    throw const FormatException(
      'Tray icon must contain 16 px and 32 px icon images.',
    );
  }
}
