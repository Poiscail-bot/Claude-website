# MacNettoyeur

Application macOS native (SwiftUI) de nettoyage et d'entretien, pensée pour les Mac Apple Silicon (MacBook Air M1 → M5).

## Fonctions

| Module | Ce qu'il fait | Mode de suppression |
|---|---|---|
| **Tableau de bord** | Stockage, mémoire, charge processeur, lancement de l'analyse | — |
| **Nettoyage** | Caches des apps, journaux, DerivedData Xcode, caches npm/Yarn/Gradle, corbeille, pièces jointes Mail, installateurs `.dmg/.pkg`, sauvegardes iPhone | Définitif pour ce qui se régénère (caches, journaux, corbeille), corbeille pour le reste |
| **Gros fichiers** | Liste les fichiers > 50 Mo / 100 Mo / 500 Mo / 1 Go de votre dossier personnel | Corbeille |
| **Désinstallation** | Supprime une app et ses restes dans `~/Library` (préférences, conteneurs, caches…) | Corbeille |
| **Démarrage** | Liste les agents/démons launchd, signale les orphelins et les emplacements suspects, retire ceux de votre session | Corbeille |
| **Sécurité** | Vérifie SIP, Gatekeeper, FileVault, coupe-feu, XProtect, et la signature/notarisation de chaque app | Lecture seule |

Garde-fous : rien n'est supprimé hors de votre dossier personnel (sauf une app de `/Applications`), les dossiers structurels (`~/Documents`, `~/Library/Caches`, trousseaux…) sont refusés, les caches iCloud et de téléchargements en cours sont exclus, et chaque action demande confirmation.

## Ce que l'app ne fait pas (volontairement)

- **Pas d'antivirus.** macOS intègre XProtect, mis à jour silencieusement par Apple. Un « antivirus » tiers sur Mac apporte peu et demande des privilèges élevés. Le module Sécurité vérifie que les protections intégrées sont actives.
- **Pas de « libération de RAM ».** Sur macOS, une mémoire pleine est normale (elle sert de cache). Les boutons « Free RAM » des nettoyeurs commerciaux vident ce cache et ralentissent le Mac juste après.
- **Pas de suppression dans les dossiers système.** Ils sont protégés par SIP et macOS les entretient lui-même.

## Installation

Prérequis : macOS 14 ou plus récent et les outils Xcode (`xcode-select --install` suffit pour compiler ; Xcode complet est nécessaire pour `swift test`).

```bash
cd mac-cleaner
./scripts/build-app.sh             # compile et crée build/MacNettoyeur.app
cp -R build/MacNettoyeur.app /Applications/
open /Applications/MacNettoyeur.app
```

Pour développer : `open Package.swift` dans Xcode, ou `swift run`.

### Accès complet au disque

Sans lui, la corbeille, les pièces jointes Mail et les sauvegardes iPhone restent invisibles (l'app l'indique). Pour l'accorder :
**Réglages Système › Confidentialité et sécurité › Accès complet au disque › +** puis choisissez `/Applications/MacNettoyeur.app` et relancez l'app.

La signature est « ad hoc » (locale) : après chaque recompilation, macOS considère l'app comme nouvelle et il faut ré-accorder l'accès.

## Tests

```bash
swift test
```

Ils couvrent le cœur (`MacNettoyeurCore`) : formatage des tailles, garde-fous de suppression, analyse des catégories, recherche des restes d'apps, détection des agents suspects et lecture des sorties `csrutil`/`spctl`/`fdesetup`.

## Architecture

```
Sources/
  MacNettoyeurCore/   logique pure Foundation (analyse, suppression, garde-fous) — testable
  MacNettoyeur/       interface SwiftUI, un fichier par écran (modèle @Observable + vue)
Support/Info.plist    métadonnées du bundle .app
scripts/build-app.sh  compilation release arm64 + signature ad hoc
```
