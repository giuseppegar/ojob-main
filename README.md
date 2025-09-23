# Job Schedule Generator

[![Build Status](https://github.com/yourusername/ojob/workflows/Build%20Multi-Platform/badge.svg)](https://github.com/yourusername/ojob/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.24.0-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Un'applicazione cross-platform per generare file Job Schedule con formato specifico. Sviluppata con Flutter, supporta Windows, Linux, Web e mobile.

## 📱 Caratteristiche

- **Generazione File Automatica**: Crea file `Job_Schedule.txt` con formato standardizzato
- **Interfaccia Intuitiva**: Design moderno in italiano con Material Design 3
- **Multi-Piattaforma**: Funziona su Windows, Linux, Web, Android e iOS
- **Cronologia Completa**: Mantiene uno storico degli ultimi 50 file generati
- **Selezione Percorso**: Possibilità di scegliere dove salvare i file
- **Validazione Input**: Controlli automatici sui dati inseriti

## 🚀 Download

### Releases Automatiche
Le build vengono generate automaticamente tramite GitHub Actions per ogni release:

- **Windows**: `JobScheduleGenerator-Windows-[version].zip`
- **Linux**: `JobScheduleGenerator-Linux-[version].tar.gz` 
- **Web**: `JobScheduleGenerator-Web.tar.gz`

Vai alla sezione [Releases](https://github.com/yourusername/ojob/releases) per scaricare l'ultima versione.

## 📋 Utilizzo

1. **Inserisci i dati**:
   - Codice Articolo (es: `PXO7471-250905`)
   - Lotto (es: `310`)
   - Numero Pezzi (es: `15`)

2. **Seleziona destinazione** (opzionale)

3. **Clicca "Genera File Job Schedule"**

4. **Il file viene salvato** con formato: `[CODICE]  [LOTTO] [PEZZI]`

### Esempio Output
```
PXO7471-250905  310 15
```

## 🔧 Sviluppo

### Requisiti
- Flutter SDK 3.24.0+
- Dart 3.0+

### Setup Locale
```bash
# Clona il repository
git clone https://github.com/yourusername/ojob.git
cd ojob

# Installa dipendenze
flutter pub get

# Esegui l'app
flutter run
```

### Build Locali

#### Windows
```bash
flutter config --enable-windows-desktop
flutter build windows --release
```

#### Linux
```bash
# Installa dipendenze Linux
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

flutter config --enable-linux-desktop
flutter build linux --release
```

#### Web
```bash
flutter config --enable-web
flutter build web --release
```

## 🤖 CI/CD

Il progetto utilizza GitHub Actions per la build automatica:

### Workflow Principali

1. **build-windows.yml**: Build specifica per Windows con packaging
2. **build-multi-platform.yml**: Build complete per tutte le piattaforme

### Trigger
- Push su `main` branch
- Tag con formato `v*` (es: `v1.0.0`)
- Pull request su `main`
- Esecuzione manuale

### Artifacts
Ogni build genera artifacts scaricabili per 30 giorni:
- Windows: Eseguibile + DLLs in formato ZIP
- Linux: AppImage + bundle in formato TAR.GZ
- Web: Build statica deployabile

## 📁 Struttura Progetto

```
ojob/
├── lib/
│   └── main.dart              # App principale
├── test/
│   └── widget_test.dart       # Test dell'app
├── .github/
│   └── workflows/             # GitHub Actions
│       ├── build-windows.yml
│       └── build-multi-platform.yml
├── assets/
│   └── icons/                 # Icone app
└── build/                     # Build output (generato)
```

## 🔧 Configurazione GitHub Actions

Per abilitare le build automatiche nel tuo fork:

1. Fork questo repository
2. Vai su Settings → Actions → General
3. Abilita "Allow all actions and reusable workflows"
4. Le build si attiveranno automaticamente sui push

### Creare una Release

```bash
# Crea e pusha un tag
git tag v1.0.0
git push origin v1.0.0
```

Questo attiverà automaticamente la build e la creazione di una release con tutti gli artifacts.

## 🛠️ Tecnologie

- **Framework**: Flutter 3.24.0
- **Linguaggio**: Dart 3.0+
- **UI**: Material Design 3
- **File I/O**: file_picker, path_provider
- **Storage**: shared_preferences
- **CI/CD**: GitHub Actions
- **Piattaforme**: Windows, Linux, Web, Android, iOS

## 📄 Formato File

I file generati seguono il formato specificato:
```
[CODICE_ARTICOLO]  [LOTTO] [PEZZI]
```

**Importante**: Due spazi tra codice articolo e lotto, uno spazio tra lotto e pezzi.

## 🤝 Contribuire

1. Fork il progetto
2. Crea un branch per la feature (`git checkout -b feature/AmazingFeature`)
3. Commit le modifiche (`git commit -m 'Add some AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

## 📝 License

Questo progetto è distribuito sotto licenza MIT. Vedi `LICENSE` per maggiori informazioni.

## 💬 Supporto

Per problemi, bug report o richieste di funzionalità, apri una [Issue](https://github.com/yourusername/ojob/issues).

## 🏗️ Build Status

| Piattaforma | Status |
|-------------|---------|
| Windows     | ![Windows Build](https://github.com/yourusername/ojob/workflows/Build%20Windows%20App/badge.svg) |
| Multi-Platform | ![Multi-Platform Build](https://github.com/yourusername/ojob/workflows/Build%20Multi-Platform/badge.svg) |

---

Sviluppato con ❤️ usando Flutter
