
# 💰 Expense Tracker

Ein privater Ausgaben-Tracker für Sebi & Alex mit automatischem Deployment.

## ✨ Features

- 💸 Ausgaben für zwei Partner tracken
- 📊 Automatische Saldierung und Vermögensstand
- 🎯 Kategorisierung von Ausgaben
- 📱 Responsive Design
- 🔄 Real-time Updates
- 💾 SQLite Datenbank
- 🚀 Ein-Klick Deployment

## 🚀 Installation

### Automatisches Deployment (Debian 12)

```bash
# Als root auf deinem Server:
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash
```

Das war's! Die App ist danach unter `http://DEINE-SERVER-IP` erreichbar.

### Lokale Entwicklung

```bash
# Repository klonen
git clone https://github.com/sebastianluebbert/privat-firma-tracker.git
cd expense-tracker

# Backend starten
cd backend
npm install
npm run dev

# Frontend starten (neues Terminal)
npm install
npm run dev
```

## 📋 Verwendung

1. **Ausgabe hinzufügen:** Partner auswählen, Beschreibung, Betrag und Kategorie eingeben
2. **Saldo ansehen:** Automatische Berechnung wer wieviel ausgegeben hat
3. **Filter:** Klick auf Partner-Kachel filtert nach diesem Partner
4. **Löschen:** Ausgaben können über das Papierkorb-Icon gelöscht werden

## 🔧 Wartung

```bash
# App aktualisieren
cd /var/www/expense-tracker
./update.sh

# Backup erstellen
./backup.sh

# Logs anzeigen
pm2 logs expense-backend
```

## 🏗️ Technologie-Stack

- **Frontend:** React, TypeScript, Tailwind CSS, Shadcn/UI
- **Backend:** Node.js, Express.js, SQLite
- **Deployment:** PM2, Nginx
- **Development:** Vite

## 📁 Projekt-Struktur

```
expense-tracker/
├── src/                    # Frontend React App
├── backend/               # Node.js Backend
│   ├── server.js         # Express Server
│   └── expenses.db       # SQLite Datenbank
├── deploy.sh             # Automatisches Deployment
├── update.sh             # Update Script
└── backup.sh             # Backup Script
```

## 🔒 Sicherheit

- Automatische Backups
- Firewall-Konfiguration
- SSL-ready (mit Certbot)
- Sichere API-Endpoints

## 📞 Support

Bei Problemen siehe [SETUP.md](SETUP.md) für detaillierte Anweisungen oder prüfe die Logs:

```bash
pm2 logs expense-backend
```

---

**Erstellt mit ❤️ für die private Ausgabenverwaltung**
