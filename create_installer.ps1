# Job Schedule Generator - Installer Creator
# PowerShell script per creare l'installer Windows

Write-Host "Creating Windows installer package..." -ForegroundColor Green

# Configuration
$buildPath = "build\windows\x64\runner\Release"
$distPath = "dist"
$appName = "JobScheduleGenerator"
$version = "1.0.0"
$packageName = "$appName-Windows-v$version"

# Check if build exists
if (!(Test-Path $buildPath)) {
    Write-Host "ERROR: Build directory not found at $buildPath" -ForegroundColor Red
    Write-Host "Please run 'flutter build windows --release' first" -ForegroundColor Yellow
    exit 1
}

# Check if executable exists
$exePath = "$buildPath\ojob.exe"
if (!(Test-Path $exePath)) {
    Write-Host "ERROR: ojob.exe not found at $exePath" -ForegroundColor Red
    Write-Host "Build may have failed. Check the flutter build output." -ForegroundColor Yellow
    exit 1
}

# Create dist directory
Write-Host "Creating distribution directory..." -ForegroundColor Yellow
Remove-Item -Path $distPath -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $distPath | Out-Null
New-Item -ItemType Directory -Force -Path "$distPath\$packageName" | Out-Null

# Copy all build files
Write-Host "Copying build files..." -ForegroundColor Yellow
Copy-Item -Recurse -Force "$buildPath\*" "$distPath\$packageName\"

# Rename executable to user-friendly name
Write-Host "Renaming executable..." -ForegroundColor Yellow
Rename-Item "$distPath\$packageName\ojob.exe" "$distPath\$packageName\$appName.exe"

# Create Italian README file
Write-Host "Creating documentation..." -ForegroundColor Yellow
$readmeContent = @"
Job Schedule Generator v$version
================================

🚀 INSTALLAZIONE RAPIDA:
1. Estrai tutti i file in una cartella sul desktop
2. Fai doppio clic su JobScheduleGenerator.exe
3. L'app si aprirà immediatamente - nessuna installazione richiesta!

📋 COME USARE:
1. Inserisci il CODICE ARTICOLO (esempio: PXO7471-250905)
2. Inserisci il LOTTO (esempio: 310)
3. Inserisci il NUMERO PEZZI (esempio: 15)  
4. [Opzionale] Clicca "Scegli dove salvare" per selezionare la cartella
5. Clicca "Genera File Job Schedule"

📄 FORMATO FILE:
Il file Job_Schedule.txt verrà creato con questo formato:
[CODICE_ARTICOLO]  [LOTTO] [PEZZI]

Esempio risultato:
PXO7471-250905  310 15

🔧 FUNZIONALITÀ:
✅ Interfaccia completamente in italiano
✅ Cronologia degli ultimi file generati
✅ Selezione libera della cartella di destinazione
✅ Validazione automatica dei dati inseriti
✅ Nessuna connessione internet richiesta

💻 REQUISITI SISTEMA:
- Windows 10 versione 1903 o successiva (64-bit)
- Circa 100 MB di spazio libero
- Nessun software aggiuntivo richiesto

🛠️ RISOLUZIONE PROBLEMI:
- Se Windows mostra un avviso di sicurezza, clicca "Maggiori informazioni" > "Esegui comunque"
- L'app è sicura al 100% - nessun accesso internet o modifica sistema
- Se l'app non si apre, controlla che tutti i file siano stati estratti nella stessa cartella

📧 SUPPORTO:
Per problemi o suggerimenti, contatta il team di sviluppo.

Creato con ❤️ usando Flutter
Versione build: $version
Data build: $(Get-Date -Format "dd/MM/yyyy HH:mm")
"@

$readmeContent | Out-File -FilePath "$distPath\$packageName\LEGGIMI.txt" -Encoding UTF8

# Create quick start batch file  
Write-Host "Creating quick start script..." -ForegroundColor Yellow
$quickStartContent = @"
@echo off
echo Avvio Job Schedule Generator...
start JobScheduleGenerator.exe
echo App avviata! Se non si apre, controlla che tutti i file siano stati estratti.
timeout 3 >nul
"@

$quickStartContent | Out-File -FilePath "$distPath\$packageName\AVVIA_APP.bat" -Encoding ASCII

# Create zip package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
$zipPath = "$distPath\$packageName.zip"
try {
    Compress-Archive -Path "$distPath\$packageName" -DestinationPath $zipPath -Force
    
    # Show success info
    $zipSize = (Get-Item $zipPath).Length / 1MB
    Write-Host "" -ForegroundColor Green
    Write-Host "✅ SUCCESS! Package created:" -ForegroundColor Green
    Write-Host "   📁 File: $zipPath" -ForegroundColor Cyan
    Write-Host "   📏 Size: $("{0:N1}" -f $zipSize) MB" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Green
    Write-Host "🎉 Ready to test on another computer!" -ForegroundColor Green
    Write-Host "   1. Copy the ZIP file to the target computer" -ForegroundColor Yellow
    Write-Host "   2. Extract all files" -ForegroundColor Yellow  
    Write-Host "   3. Run JobScheduleGenerator.exe" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create ZIP package: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}