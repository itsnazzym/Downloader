import 'package:modern_downloader/core/design_system/design_skin.dart';

import 'nocturne/nocturne_skin.dart';
import 'pastille/pastille_skin.dart';
import 'porcelaine/porcelaine_skin.dart';
import 'signal/signal_skin.dart';
import 'studio/studio_skin.dart';
import 'terminal/terminal_skin.dart';

/// Lets each desktop design draw the shared rows and settings tiles.
void registerDesignSkins() {
  DesignSkin.register('signal', signalSkin);
  DesignSkin.register('porcelaine', porcelaineSkin);
  DesignSkin.register('pastille', pastilleSkin);
  DesignSkin.register('studio', studioSkin);
  DesignSkin.register('terminal', terminalSkin);
  DesignSkin.register('nocturne', nocturneSkin);
}
