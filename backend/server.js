
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// SQLite Datenbank initialisieren
const dbPath = path.join(__dirname, 'expenses.db');
const db = new sqlite3.Database(dbPath);

// Tabelle erstellen falls sie nicht existiert
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS expenses (
    id TEXT PRIMARY KEY,
    partner TEXT NOT NULL,
    description TEXT NOT NULL,
    amount REAL NOT NULL,
    date TEXT NOT NULL,
    category TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
});

// Routes
// GET alle Ausgaben
app.get('/api/expenses', (req, res) => {
  db.all('SELECT * FROM expenses ORDER BY date DESC', (err, rows) => {
    if (err) {
      console.error('Fehler beim Abrufen der Ausgaben:', err);
      res.status(500).json({ error: 'Fehler beim Abrufen der Ausgaben' });
      return;
    }
    res.json(rows);
  });
});

// POST neue Ausgabe hinzufügen
app.post('/api/expenses', (req, res) => {
  const { partner, description, amount, date, category } = req.body;
  const id = Date.now().toString();

  if (!partner || !description || !amount || !date || !category) {
    res.status(400).json({ error: 'Alle Felder sind erforderlich' });
    return;
  }

  db.run(
    'INSERT INTO expenses (id, partner, description, amount, date, category) VALUES (?, ?, ?, ?, ?, ?)',
    [id, partner, description, amount, date, category],
    function(err) {
      if (err) {
        console.error('Fehler beim Hinzufügen der Ausgabe:', err);
        res.status(500).json({ error: 'Fehler beim Hinzufügen der Ausgabe' });
        return;
      }
      res.json({ id, partner, description, amount, date, category });
    }
  );
});

// DELETE Ausgabe löschen
app.delete('/api/expenses/:id', (req, res) => {
  const { id } = req.params;

  db.run('DELETE FROM expenses WHERE id = ?', [id], function(err) {
    if (err) {
      console.error('Fehler beim Löschen der Ausgabe:', err);
      res.status(500).json({ error: 'Fehler beim Löschen der Ausgabe' });
      return;
    }
    
    if (this.changes === 0) {
      res.status(404).json({ error: 'Ausgabe nicht gefunden' });
      return;
    }
    
    res.json({ message: 'Ausgabe erfolgreich gelöscht' });
  });
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server läuft' });
});

// Server starten
app.listen(PORT, () => {
  console.log(`Server läuft auf Port ${PORT}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Server wird beendet...');
  db.close((err) => {
    if (err) {
      console.error('Fehler beim Schließen der Datenbank:', err);
    } else {
      console.log('Datenbankverbindung geschlossen.');
    }
    process.exit(0);
  });
});
