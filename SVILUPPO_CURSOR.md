# 🚀 Sviluppo con Cursor - Job Schedule Generator

## 📋 Setup Iniziale

### 1. Prerequisiti
- **Flutter SDK** installato e configurato
- **Cursor Editor** installato
- **Windows 10/11** (per build native)

### 2. Verifica Flutter
```bash
flutter doctor -v
flutter config --enable-windows-desktop
```

### 3. Dipendenze
```bash
flutter pub get
```

## ⚡ Build Rapida con Cursor

### Metodo 1: Script Automatico (Consigliato)
```bash
# Doppio click su:
build_windows.bat
```

### Metodo 2: Tasks di Cursor
Premi `Ctrl+Shift+P` e cerca "Tasks: Run Task":

- **Build Windows Installer (Full)** - Build completo + installer
- **Flutter: Build Windows Release** - Solo build release  
- **Flutter: Run Windows** - Avvia in modalità debug
- **Create Windows Package Only** - Solo packaging

### Metodo 3: Comandi Manuali
```bash
# Build release
flutter build windows --release --verbose

# Crea installer
powershell -ExecutionPolicy Bypass -File create_installer.ps1
```

## 🎯 Risultato

Dopo il build troverai:
```
📁 dist/
  └── 📦 JobScheduleGenerator-Windows-v1.0.0.zip
      ├── 🚀 JobScheduleGenerator.exe
      ├── 📄 LEGGIMI.txt  
      ├── ⚡ AVVIA_APP.bat
      └── 📚 [tutte le dll necessarie]
```

## 🔧 Debug e Test

### Run in Debug Mode
```bash
flutter run -d windows
```

### Hot Reload attivo
- `r` - Hot reload
- `R` - Hot restart  
- `q` - Quit

### Debug con Cursor
1. Apri il file `lib/main.dart`
2. Metti breakpoint dove necessario
3. Premi `F5` o usa "Flutter: Debug Windows"

## 📱 Test dell'App

### Test Input
- **Codice Articolo**: `PXO7471-250905`
- **Lotto**: `310`
- **Pezzi**: `15`

### Output Atteso
File `Job_Schedule.txt` con contenuto:
```
PXO7471-250905  310 15
```

## 🚨 Risoluzione Problemi

### Build Fallisce
```bash
flutter clean
flutter pub get
flutter build windows --release
```

### Errori di Dipendenze
```bash
flutter pub upgrade --major-versions
flutter pub get
```

### Problemi Windows Desktop
```bash
flutter config --enable-windows-desktop
flutter doctor -v
```

### File Non Trovati
Verifica che esistano:
- `build/windows/x64/runner/Release/ojob.exe`
- Tutte le `.dll` nella stessa directory

## 🎉 Test Installazione

1. Copia il file `.zip` su un altro PC Windows
2. Estrai tutto in una cartella
3. Esegui `JobScheduleGenerator.exe`
4. Test funzionalità complete

## 📝 Note Sviluppo

- **Hot Reload**: Funziona perfettamente su Windows
- **File Picker**: Usa la versione ^10.3.3 per compatibilità Windows
- **Icons**: Phosphor Flutter per UI moderna
- **Theme**: Gradient viola con Material Design 3
- **Storage**: SharedPreferences per cronologia
- **Languages**: UI completamente in italiano

## 🔄 Workflow Sviluppo Consigliato

1. **Sviluppo**: `flutter run -d windows` 
2. **Test rapido**: Hot reload con `r`
3. **Test completo**: Build release con `build_windows.bat`
4. **Deploy**: Zip dell'installer pronto

## ⚙️ Configurazioni Cursor

File già configurati:
- `.vscode/tasks.json` - Tasks personalizzate
- `.vscode/launch.json` - Configurazioni debug
- `build_windows.bat` - Script build automatico
- `create_installer.ps1` - Packaging automatico

Usa `Ctrl+Shift+P` per accedere velocemente a tutte le funzioni!