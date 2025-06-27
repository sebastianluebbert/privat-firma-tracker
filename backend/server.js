
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({
  origin: true,
  credentials: true,
  methods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// SQLite Datenbank initialisieren
const dbPath = path.join(__dirname, 'expenses.db');
console.log('=================================');
console.log('Backend Server startet...');
console.log('Datenbank-Pfad:', dbPath);
console.log('Port:', PORT);
console.log('=================================');

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('FEHLER beim Öffnen der Datenbank:', err);
    process.exit(1);
  } else {
    console.log('✅ SQLite-Datenbank erfolgreich verbunden');
  }
});

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
  )`, (err) => {
    if (err) {
      console.error('FEHLER beim Erstellen der Tabelle:', err);
      process.exit(1);
    } else {
      console.log('✅ Expenses-Tabelle ist bereit');
    }
  });
});

// Routes
// GET alle Ausgaben
app.get('/api/expenses', (req, res) => {
  console.log('📋 GET /api/expenses aufgerufen');
  db.all('SELECT * FROM expenses ORDER BY date DESC', (err, rows) => {
    if (err) {
      console.error('❌ Fehler beim Abrufen der Ausgaben:', err);
      res.status(500).json({ error: 'Fehler beim Abrufen der Ausgaben' });
      return;
    }
    console.log(`✅ ${rows.length} Ausgaben gefunden`);
    res.json(rows);
  });
});

// POST neue Ausgabe hinzufügen
app.post('/api/expenses', (req, res) => {
  console.log('➕ POST /api/expenses aufgerufen mit:', req.body);
  const { partner, description, amount, date, category } = req.body;
  const id = Date.now().toString();

  if (!partner || !description || !amount || !date || !category) {
    console.error('❌ Fehlende Felder:', { partner, description, amount, date, category });
    res.status(400).json({ error: 'Alle Felder sind erforderlich' });
    return;
  }

  db.run(
    'INSERT INTO expenses (id, partner, description, amount, date, category) VALUES (?, ?, ?, ?, ?, ?)',
    [id, partner, description, amount, date, category],
    function(err) {
      if (err) {
        console.error('❌ Fehler beim Hinzufügen der Ausgabe:', err);
        res.status(500).json({ error: 'Fehler beim Hinzufügen der Ausgabe' });
        return;
      }
      console.log('✅ Neue Ausgabe hinzugefügt:', id);
      res.json({ id, partner, description, amount, date, category });
    }
  );
});

// DELETE Ausgabe löschen
app.delete('/api/expenses/:id', (req, res) => {
  const { id } = req.params;
  console.log('🗑️  DELETE /api/expenses/' + id + ' aufgerufen');

  db.run('DELETE FROM expenses WHERE id = ?', [id], function(err) {
    if (err) {
      console.error('❌ Fehler beim Löschen der Ausgabe:', err);
      res.status(500).json({ error: 'Fehler beim Löschen der Ausgabe' });
      return;
    }
    
    if (this.changes === 0) {
      console.log('⚠️  Ausgabe nicht gefunden:', id);
      res.status(404).json({ error: 'Ausgabe nicht gefunden' });
      return;
    }
    
    console.log('✅ Ausgabe gelöscht:', id);
    res.json({ message: 'Ausgabe erfolgreich gelöscht' });
  });
});

// Health check
app.get('/api/health', (req, res) => {
  console.log('💚 Health check aufgerufen');
  res.json({ 
    status: 'OK', 
    message: 'Server läuft',
    timestamp: new Date().toISOString(),
    port: PORT,
    database: 'connected'
  });
});

// Catch-all für unbekannte API-Routes
app.use('/api/*', (req, res) => {
  console.log('❓ Unbekannte API-Route aufgerufen:', req.method, req.path);
  res.status(404).json({ error: 'API-Route nicht gefunden' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('💥 Unerwarteter Fehler:', err);
  res.status(500).json({ error: 'Interner Server-Fehler' });
});

// Server starten
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 ================================');
  console.log(`🚀  SERVER LÄUFT AUF PORT ${PORT}`);
  console.log(`🚀  API verfügbar unter http://localhost:${PORT}/api`);
  console.log(`🚀  Health check: http://localhost:${PORT}/api/health`);
  console.log('🚀 ================================');
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  console.log(`${signal} empfangen, beende Server...`);
  server.close(() => {
    console.log('Server geschlossen');
    db.close((err) => {
      if (err) {
        console.error('Fehler beim Schließen der Datenbank:', err);
      } else {
        console.log('Datenbankverbindung geschlossen.');
      }
      process.exit(0);
    });
  });
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('💥 Uncaught Exception:', err);
  gracefulShutdown('UNCAUGHT_EXCEPTION');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('💥 Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('UNHANDLED_REJECTION');
});
