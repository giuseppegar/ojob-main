-- Test data per verificare il funzionamento dei filtri temporali
-- Questo script inserisce dati di test per diversi periodi

-- Dati per la settimana corrente
INSERT INTO quality_monitoring (monitoring_path, total_pieces, good_pieces, rejected_pieces, timestamp) VALUES
('/monitoring/settimana_corrente_1', 100, 85, 15, NOW() - INTERVAL '1 day'),
('/monitoring/settimana_corrente_2', 150, 140, 10, NOW() - INTERVAL '2 days'),
('/monitoring/settimana_corrente_3', 80, 75, 5, NOW() - INTERVAL '3 hours');

-- Dati per la settimana scorsa
INSERT INTO quality_monitoring (monitoring_path, total_pieces, good_pieces, rejected_pieces, timestamp) VALUES
('/monitoring/settimana_scorsa_1', 200, 180, 20, NOW() - INTERVAL '8 days'),
('/monitoring/settimana_scorsa_2', 120, 110, 10, NOW() - INTERVAL '9 days'),
('/monitoring/settimana_scorsa_3', 90, 85, 5, NOW() - INTERVAL '10 days');

-- Dati per il mese scorso
INSERT INTO quality_monitoring (monitoring_path, total_pieces, good_pieces, rejected_pieces, timestamp) VALUES
('/monitoring/mese_scorso_1', 300, 280, 20, NOW() - INTERVAL '35 days'),
('/monitoring/mese_scorso_2', 250, 240, 10, NOW() - INTERVAL '40 days');

-- Ora inseriamo alcuni reject_details per questi records
-- Prima recuperiamo gli ID dei quality_monitoring appena inseriti

-- Reject details per settimana corrente
INSERT INTO reject_details (quality_monitoring_id, station, code, description, progressivo, quantity)
SELECT
    qm.id,
    'Stazione A',
    'DEF001',
    'Difetto superficie - settimana corrente',
    1,
    8
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/settimana_corrente_1';

INSERT INTO reject_details (quality_monitoring_id, station, code, description, progressivo, quantity)
SELECT
    qm.id,
    'Stazione B',
    'DEF002',
    'Dimensioni fuori tolleranza - settimana corrente',
    2,
    7
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/settimana_corrente_1';

-- Reject details per settimana scorsa
INSERT INTO reject_details (quality_monitoring_id, station, code, description, progressivo, quantity)
SELECT
    qm.id,
    'Stazione A',
    'DEF003',
    'Materiale danneggiato - settimana scorsa',
    1,
    15
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/settimana_scorsa_1';

INSERT INTO reject_details (quality_monitoring_id, station, code, description, progressivo, quantity)
SELECT
    qm.id,
    'Stazione C',
    'DEF004',
    'Problema assemblaggio - settimana scorsa',
    2,
    5
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/settimana_scorsa_1';

-- Reject details per mese scorso
INSERT INTO reject_details (quality_monitoring_id, station, code, description, progressivo, quantity)
SELECT
    qm.id,
    'Stazione A',
    'DEF005',
    'Controllo qualità fallito - mese scorso',
    1,
    12
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/mese_scorso_1';

INSERT INTO reject_details (quality_monitoring_id, station, code, description, progressivo, quantity)
SELECT
    qm.id,
    'Stazione B',
    'DEF006',
    'Specifiche non rispettate - mese scorso',
    2,
    8
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/mese_scorso_1';

-- Verifica dei dati inseriti
SELECT
    qm.monitoring_path,
    qm.total_pieces,
    qm.good_pieces,
    qm.rejected_pieces,
    qm.timestamp,
    COUNT(rd.id) as reject_details_count
FROM quality_monitoring qm
LEFT JOIN reject_details rd ON qm.id = rd.quality_monitoring_id
WHERE qm.monitoring_path LIKE '/monitoring/%'
GROUP BY qm.id, qm.monitoring_path, qm.total_pieces, qm.good_pieces, qm.rejected_pieces, qm.timestamp
ORDER BY qm.timestamp DESC;