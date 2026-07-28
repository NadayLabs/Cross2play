# Cross2Play

Gestionnaire de bottles Wine pour **macOS Apple Silicon** (14+), orienté **Steam** et jeux Windows **sans anti-triche noyau**.

[![Platform](https://img.shields.io/badge/macOS-14%2B-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Arch](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4-black)](https://apple.com)

> **Statut v1 :** Steam-first. Voir [docs/JEUX-INCOMPATIBLES.md](docs/JEUX-INCOMPATIBLES.md) pour les titres qui ne marcheront (presque) jamais (Vanguard, EAC, EAAC, ACE…).

## Ce que Cross2Play promet

- Runtime Wine **isolé** (téléchargé dans `~/Library/Application Support/Cross2play/`)
- Bottles Windows isolées
- Client **Steam** Windows + lancement de jeux compatibles
- Stack graphique **DXMT** (D3D11→Metal) lorsque le runtime Cross2Play FOSS est installé
- Liste claire des jeux incompatibles (anti-triche)

## Ce que Cross2Play ne promet pas

- Valorant, Fortnite, Call of Duty online, FC / Battlefield récents, etc. (anti-triche noyau)
- Parité CrossOver / Whisky sur « tous les jeux Windows »
- Interface web Chromium (CEF) parfaite pour tous les launchers Windows sous Wine

## Prérequis

- macOS 14 (Sonoma) ou plus récent
- Apple Silicon (M1–M4…)
- **Rosetta 2** installé (`softwareupdate --install-rosetta`)
- ~3–10 Go libres (runtime + Steam + jeux)

## Installation (joueur)

1. Téléchargez le DMG depuis les [Releases](https://github.com/NadayLabs/Cross2play/releases) (ou construisez depuis les sources).
2. Glissez `Cross2play.app` dans Applications.
3. Au premier lancement : suivez l’assistant (Rosetta → runtime → bottle Steam).

Si Gatekeeper bloque une build non notariée : clic droit → Ouvrir (une fois). Les releases officielles signées/notariées n’en ont pas besoin.

## Compilation (développeur)

```bash
brew install xcodegen
git clone https://github.com/NadayLabs/Cross2play.git
cd Cross2play
xcodegen generate
xcodebuild -project Cross2play.xcodeproj -scheme Cross2play \
  -configuration Release -derivedDataPath build/DerivedData build
```

Empaquetage DMG :

```bash
./scripts/build-release.sh
```

Notarization (compte Apple Developer) :

```bash
export APPLE_ID=... APPLE_TEAM_ID=... APPLE_APP_SPECIFIC_PASSWORD=...
# ou NOTARY_PROFILE=...
./scripts/build-release.sh --notarize
```

Runtime FOSS + DXMT (mainteneurs) :

```bash
./Tools/package-runtime.sh   # produit artifacts/cross2play-runtime-*.tar.xz
# Publier sur GitHub Releases puis renseigner url + SHA dans
# Cross2play/Resources/RuntimeManifest.json (auto si CROSS2PLAY_UPDATE_MANIFEST=1)
```

## Site web

Le site marketing Cross2play est **privé** (dépôt séparé, déployé via AWS Amplify) et **n’est pas inclus** dans ce dépôt open-source.

## Chemins locaux


| Élément | Chemin |
|---------|--------|
| Runtime | `~/Library/Application Support/Cross2play/Runtime/` |
| Bottles | `~/Library/Application Support/Cross2play/Bottles/` |
| Outils (winetricks…) | `~/Library/Application Support/Cross2play/Tools/` |
| Raccourcis | `~/Applications/Cross2play/` |

## Licence

- Application : [MIT](LICENSE)
- Tiers (Wine, DXMT, winetricks…) : [NOTICE](NOTICE)

## Contribution

Voir [CONTRIBUTING.md](CONTRIBUTING.md).
