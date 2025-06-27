
#!/bin/bash

# Expense Tracker - Update Script
# Verwendung: ./update.sh

set -e

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Konfiguration
APP_DIR="/var/www/expense-tracker"
FRONTEND_DIR="$APP_DIR/frontend"
BACKEND_DIR="$APP_DIR/backend"

print_status "🔄 Starte Update des Expense Trackers..."

# Zum App-Verzeichnis wechseln
cd $APP_DIR

# Backup der Datenbank erstellen
print_status "Erstelle Datenbank-Backup..."
cp $BACKEND_DIR/expenses.db $BACKEND_DIR/expenses.backup.$(date +%Y%m%d_%H%M%S).db

# Repository aktualisieren
print_status "Aktualisiere Repository..."
git pull origin main

# Backend Dependencies aktualisieren
print_status "Aktualisiere Backend Dependencies..."
cd $BACKEND_DIR
npm install --production

# Frontend neu bauen
print_status "Baue Frontend neu..."
cd $APP_DIR
npm install
npm run build

# Frontend-Dateien aktualisieren
print_status "Aktualisiere Frontend-Dateien..."
rm -rf $FRONTEND_DIR/*
cp -r dist/* $FRONTEND_DIR/

# Berechtigungen setzen
chown -R expense:www-data $APP_DIR

# Backend neustarten
print_status "Starte Backend neu..."
sudo -u expense pm2 restart expense-backend

# Nginx neuladen
print_status "Lade Nginx neu..."
nginx -t && systemctl reload nginx

print_success "✅ Update erfolgreich abgeschlossen!"
print_status "Die App ist unter http://$(hostname -I | awk '{print $1}') erreichbar"
