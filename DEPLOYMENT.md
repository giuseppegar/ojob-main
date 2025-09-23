# Guida al Deployment su GitHub

Questa guida spiega come configurare il repository su GitHub per abilitare le build automatiche e i rilasci.

## 🚀 Setup Iniziale

### 1. Creare Repository GitHub

```bash
# Inizializza git (se non già fatto)
git init

# Aggiungi tutti i file
git add .

# Primo commit
git commit -m "Initial commit: Job Schedule Generator app"

# Aggiungi remote (sostituisci con il tuo repository)
git remote add origin https://github.com/tuousername/ojob.git

# Push del codice
git push -u origin main
```

### 2. Abilitare GitHub Actions

1. Vai su GitHub.com → tuo repository
2. Settings → Actions → General
3. Abilita "Allow all actions and reusable workflows"
4. Salva le impostazioni

## 🔧 Configurazione Build

### Workflow Disponibili

Il progetto include due workflow GitHub Actions:

1. **`build-windows.yml`**: Build specifica per Windows
2. **`build-multi-platform.yml`**: Build per Windows, Linux e Web

### Trigger Automatici

I workflow si attivano per:
- ✅ Push sul branch `main`
- ✅ Push sui tag `v*` (es: `v1.0.0`)
- ✅ Pull Request verso `main`
- ✅ Esecuzione manuale

### Artifacts Generati

Ogni build produce artifacts scaricabili:
- **Windows**: `JobScheduleGenerator-Windows-[version].zip`
- **Linux**: `JobScheduleGenerator-Linux-[version].tar.gz`
- **Web**: `JobScheduleGenerator-Web.tar.gz`

## 📦 Creare una Release

### Metodo 1: Tag Git

```bash
# Crea un tag per la versione
git tag v1.0.0

# Push del tag (attiva build automatica)
git push origin v1.0.0
```

### Metodo 2: Release GitHub

1. Vai su GitHub → tuo repository
2. Releases → "Create a new release"
3. Tag: `v1.0.0` (nuovo tag)
4. Title: `v1.0.0 - Prima Release`
5. Descrivi le funzionalità
6. "Publish release"

La release automaticamente:
- ✅ Attiva le build per tutte le piattaforme
- ✅ Carica gli artifacts
- ✅ Crea note di rilascio

## 🏗️ Monitorare le Build

### Visualizzare Build Status

1. Repository GitHub → Actions tab
2. Visualizza workflow in esecuzione/completati
3. Clicca su un workflow per dettagli e log

### Download Artifacts

1. Actions → seleziona workflow completato
2. Sezione "Artifacts" in fondo alla pagina
3. Download dei file generati

### Badge nel README

I badge mostrano automaticamente lo status:
- ![Build Status](https://img.shields.io/github/workflow/status/tuousername/ojob/Build%20Multi-Platform)

## 📋 Checklist Pre-Release

Prima di ogni release, verifica:

- [ ] Tests passano localmente (`flutter test`)
- [ ] Analisi clean (`flutter analyze`)  
- [ ] Versione aggiornata in `pubspec.yaml`
- [ ] CHANGELOG aggiornato (se presente)
- [ ] README aggiornato
- [ ] Build locali funzionanti per target principali

## 🛠️ Build Locali (Test)

Prima di pushare, testa le build:

```bash
# Windows (su Windows)
flutter config --enable-windows-desktop
flutter build windows --release

# Linux (su Linux/WSL)
flutter config --enable-linux-desktop
flutter build linux --release

# Web (multipiattaforma)
flutter config --enable-web
flutter build web --release
```

## 🚨 Risoluzione Problemi

### Build Falliscono

1. Controlla log su GitHub Actions
2. Verifica che `flutter analyze` sia clean
3. Assicurati che i test passino
4. Controlla compatibilità dipendenze

### Workflow Non Si Attivano

1. Verifica che GitHub Actions sia abilitato
2. Controlla sintassi YAML nei workflow
3. Verifica trigger conditions (branch, tag format)

### Artifacts Non Vengono Creati

1. Controlla che il build step sia completato con successo
2. Verifica path degli artifacts nei workflow
3. Controlla permessi repository

## 📧 Supporto

Per problemi specifici:
- Apri una Issue nel repository
- Controlla log GitHub Actions per dettagli errori
- Verifica documentazione GitHub Actions

## 🔄 Aggiornamento Workflow

Per modificare i workflow:
1. Modifica file in `.github/workflows/`
2. Commit e push
3. I workflow aggiornati si attivano automaticamente

---

**Nota**: Sostituisci `tuousername/ojob` con il tuo username e nome repository GitHub effettivi.