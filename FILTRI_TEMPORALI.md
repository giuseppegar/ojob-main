# Sistema di Filtri Temporali

Il sistema di filtri temporali permette di visualizzare i dati di quality monitoring e reject details per periodi specifici.

## Funzionalità Principali

### Filtri Disponibili

1. **Settimana Corrente** (predefinito)
   - Mostra dati da lunedì a domenica della settimana in corso
   - Si aggiorna automaticamente ogni settimana

2. **Settimana Scorsa**
   - Mostra dati della settimana precedente (lunedì-domenica)

3. **Mese Corrente**
   - Mostra tutti i dati del mese in corso

4. **Mese Scorso**
   - Mostra tutti i dati del mese precedente

5. **Periodo Personalizzato**
   - Permette di selezionare date di inizio e fine specifiche
   - Interfaccia date picker integrata

6. **Tutti i Dati**
   - Mostra tutti i dati senza filtri temporali

### Come Utilizzare i Filtri

1. **Accesso ai Filtri**
   - Vai alla scheda "Quality Dashboard"
   - Trova il widget "Filtro Periodo" in alto
   - Clicca per espandere le opzioni

2. **Selezione Filtro**
   - Seleziona una delle opzioni predefinite
   - Per "Periodo Personalizzato", usa i selettori di data
   - Clicca "Applica" per aggiornare i dati

3. **Reset**
   - Usa il pulsante "Reset" per tornare alla settimana corrente

### Logica Settimana

- **Inizio settimana**: Lunedì ore 00:00:00
- **Fine settimana**: Domenica ore 23:59:59
- **Aggiornamento automatico**: Ogni lunedì i filtri si aggiornano automaticamente

### Dati Filtrati

Il sistema filtra:
- **Quality Monitoring**: Record principali di monitoraggio qualità
- **Reject Details**: Tutti i dettagli degli scarti collegati
- **Visualizzazione**: Le statistiche mostrate sono calcolate solo sui dati filtrati

### Persistenza

- Le impostazioni di filtro vengono salvate automaticamente
- Al riavvio dell'app, l'ultimo filtro selezionato viene ripristinato
- Le date personalizzate vengono memorizzate

## File Tecnici

### Servizi
- `lib/services/filter_service.dart` - Logica di gestione filtri
- `lib/widgets/filter_widget.dart` - Interfaccia utente

### Database
- Le query vengono modificate dinamicamente con clausole WHERE temporali
- Utilizza il campo `timestamp` per il filtraggio

### Test
- `test_filter_data.sql` - Script per inserire dati di test

## Esempi di Utilizzo

### Scenario 1: Controllo Settimanale
1. All'inizio della settimana, il filtro "Settimana Corrente" è attivo
2. Visualizza solo i dati di lunedì-domenica correnti
3. Gli scarti precedenti non sono visibili

### Scenario 2: Analisi Storica
1. Seleziona "Periodo Personalizzato"
2. Imposta data inizio e fine per il periodo di interesse
3. Analizza trend e problemi storici

### Scenario 3: Confronto Mensile
1. Visualizza "Mese Corrente" per dati attuali
2. Cambia a "Mese Scorso" per confronto
3. Identifica miglioramenti o peggioramenti

## Note Implementative

- I filtri si applicano sia a quality_monitoring che a reject_details
- Le query sono ottimizzate con indici sui campi timestamp
- Il sistema è compatibile con PostgreSQL/Supabase
- L'interfaccia è responsive e supporta touch/mouse