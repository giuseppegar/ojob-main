#!/bin/bash

# Script per aggiornare il database tramite API REST di Supabase
# Esegue le modifiche necessarie alla tabella reject_details

SUPABASE_URL="http://192.168.1.225:8000"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"

echo "🔄 Tentativo di connessione al database..."

# Test di connessione
response=$(curl -s -w "%{http_code}" -o /dev/null "$SUPABASE_URL/rest/v1/quality_monitoring?select=id&limit=1" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY")

if [ "$response" != "200" ]; then
    echo "❌ Errore di connessione al database. Codice: $response"
    echo "💡 Opzioni alternative:"
    echo "   1. Usa l'interfaccia web di Supabase: $SUPABASE_URL"
    echo "   2. Installa PostgreSQL client: brew install postgresql"
    echo "   3. Chiedi all'amministratore del database di eseguire database_update.sql"
    exit 1
fi

echo "✅ Connessione al database riuscita!"
echo ""
echo "⚠️  ATTENZIONE: Le modifiche alla struttura della tabella non possono essere"
echo "   eseguite tramite API REST. Hai bisogno di:"
echo ""
echo "📋 ISTRUZIONI:"
echo "1. Accedi all'interfaccia web di Supabase: $SUPABASE_URL"
echo "2. Vai nella sezione 'SQL Editor' o 'Database'"
echo "3. Copia e incolla il contenuto del file 'database_update.sql'"
echo "4. Esegui lo script SQL"
echo ""
echo "📄 Il file database_update.sql contiene:"
echo "   - Aggiornamento tabella reject_details"
echo "   - Aggiunta colonne: code, description, progressivo"
echo "   - Ricostruzione indici e permessi"
echo ""
echo "🔧 Alternativa: installa PostgreSQL client con 'brew install postgresql'"
echo "   poi esegui: psql postgresql://postgres:supabase@192.168.1.225:5432/postgres -f database_update.sql"