# Build & Release (Flutter / Android, Windows)

- flutter n'est PAS dans le PATH, ni dans bash ni dans PowerShell. Utilise le SDK épinglé dans `android/local.properties` (`flutter.sdk`) : `C:\Users\entre\dev-tools\flutter\bin\flutter.bat`.
- Compile les APK release arm64 avec : `flutter build apk --release --target-platform android-arm64`
- Après le build, envoie l'APK sur gofile et donne-moi le lien de téléchargement.
- Avant d'annoncer des changements d'UI comme terminés, vérifie-les sur l'émulateur et envoie les captures d'écran dans la conversation.
- Le skill `/apk` enchaîne tests, build et envoi.
