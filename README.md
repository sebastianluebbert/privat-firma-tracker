

# 💰 Expense Tracker

Ein privater Ausgaben-Tracker für Sebi & Alex mit automatischem Deployment und SSL.

## ✨ Features

- 💸 Ausgaben für zwei Partner tracken
- 📊 Automatische Saldierung und Vermögensstand
- 🎯 Kategorisierung von Ausgaben
- 📱 Responsive Design
- 🔄 Real-time Updates
- 💾 SQLite Datenbank
- 🚀 Ein-Klick Deployment
- 🔒 **Automatisches HTTPS/SSL mit Let's Encrypt**
- 🔄 **SSL Auto-Renewal**

## 🚀 Installation

### Automatisches Deployment (Debian 12)

**HTTP-Only (ohne Domain):**
```bash
# Als root auf deinem Server:
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash
```

**HTTPS mit SSL (mit Domain):**
```bash
# Als root auf deinem Server (Domain durch deine ersetzen):
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash -s -- --domain=deine-domain.com
```

Das war's! Die App ist danach unter `https://deine-domain.com` oder `http://DEINE-SERVER-IP` erreichbar.

### SSL nachträglich hinzufügen

```bash
# Für bestehende HTTP-Installation:
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/setup-ssl.sh | bash -s -- --domain=deine-domain.com
```

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

## 🔒 SSL & Sicherheit

### Automatisches HTTPS Setup:
- **Let's Encrypt Zertifikate** werden automatisch installiert
- **HTTP → HTTPS Redirect** wird konfiguriert
- **Auto-Renewal** läuft täglich um 12:00 Uhr
- **DNS-Validierung** vor SSL-Setup

### SSL-Befehle:
```bash
# SSL-Status prüfen
sudo certbot certificates

# SSL manuell erneuern
sudo certbot renew

# SSL-Logs anzeigen
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

## 🔧 Wartung

```bash
# App aktualisieren
cd /var/www/expense-tracker
./update.sh

# Backup erstellen
./backup.sh

# Logs anzeigen
pm2 logs expense-backend

# SSL-Status prüfen (wenn SSL aktiv)
sudo certbot certificates
```

## 🏗️ Technologie-Stack

- **Frontend:** React, TypeScript, Tailwind CSS, Shadcn/UI
- **Backend:** Node.js, Express.js, SQLite
- **Deployment:** PM2, Nginx
- **SSL:** Let's Encrypt, Certbot
- **Development:** Vite

## 📁 Projekt-Struktur

```
expense-tracker/
├── src/                    # Frontend React App
├── backend/               # Node.js Backend
│   ├── server.js         # Express Server
│   └── expenses.db       # SQLite Datenbank
├── deploy.sh             # Automatisches Deployment
├── setup-ssl.sh          # SSL nachträglich einrichten
├── update.sh             # Update Script
└── backup.sh             # Backup Script
```

## 🔒 Sicherheitsfeatures

- **HTTPS/SSL** mit Let's Encrypt
- **Automatische SSL-Erneuerung**
- **Firewall-Konfiguration**
- **Sichere API-Endpoints**
- **Automatische Backups**
- **DNS-Validierung**

## ⚠️ Voraussetzungen für SSL

Für automatisches HTTPS benötigst du:
- **Domain** (z.B. `meine-domain.com`)
- **DNS A-Record** der auf deinen Server zeigt
- **Port 80 und 443** müssen erreichbar sein
- **Gültige E-Mail** für Let's Encrypt

### DNS-Konfiguration Beispiel:
```
Typ: A
Name: @ (für Hauptdomain) oder subdomain
Wert: DEINE-SERVER-IP-ADRESSE
TTL: 3600
```

## 📞 Support

Bei Problemen siehe [SETUP.md](SETUP.md) für detaillierte Anweisungen oder prüfe die Logs:

```bash
# App-Logs
pm2 logs expense-backend

# Nginx-Logs
sudo tail -f /var/log/nginx/error.log

# SSL-Logs (falls SSL aktiv)
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

### Häufige Probleme:

**SSL funktioniert nicht:**
- DNS-Einstellungen prüfen: `dig deine-domain.com`
- Firewall prüfen: `sudo ufw status`
- Certbot-Logs prüfen: `sudo tail -f /var/log/letsencrypt/letsencrypt.log`

**App nicht erreichbar:**
- PM2 Status: `pm2 status`
- Nginx Status: `sudo systemctl status nginx`
- Port-Konflikte: `sudo lsof -i :3001`

---

**Erstellt mit ❤️ für die private Ausgabenverwaltung**

