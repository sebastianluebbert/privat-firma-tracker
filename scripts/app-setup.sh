
#!/bin/bash

# App Setup - Klont Repository, baut Backend und Frontend

source "$(dirname "$0")/common.sh"

setup_app() {
    local domain="$1"
    
    print_status "📦 Starte App-Setup..."

    # App-Verzeichnis erstellen
    print_status "Erstelle App-Verzeichnis..."
    mkdir -p $APP_DIR
    cd $APP_DIR

    # Repository klonen
    print_status "Klone Repository..."
    if [ -d ".git" ]; then
        print_status "Repository bereits vorhanden, führe Pull aus..."
        git pull origin main
    else
        git clone $REPO_URL .
    fi

    # Backend Setup
    print_status "Installiere Backend Dependencies..."
    cd $BACKEND_DIR
    npm install --production

    # Environment-Datei für Backend erstellen
    print_status "Erstelle Backend Environment-Datei..."
    cat > .env << EOF
PORT=3001
NODE_ENV=production
EOF

    # Backend starten BEVOR Frontend gebaut wird
    print_status "Starte Backend..."
    sudo -u expense pm2 delete expense-backend 2>/dev/null || true
    sudo -u expense pm2 start server.js --name "expense-backend"
    sudo -u expense pm2 save

    # Kurz warten bis Backend läuft
    print_status "Warte auf Backend-Start..."
    sleep 3

    # Backend Health Check
    print_status "Prüfe Backend Status..."
    if curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
        print_success "Backend läuft korrekt ✓"
    else
        print_warning "Backend noch nicht bereit, versuche weiter..."
        sleep 5
        if ! curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
            print_error "Backend startet nicht korrekt"
            sudo -u expense pm2 logs expense-backend --lines 20
            exit 1
        fi
    fi

    # Frontend Build
    print_status "Baue Frontend..."
    cd $APP_DIR

    # Environment für Frontend - mit oder ohne SSL
    if [ -n "$domain" ]; then
        echo "VITE_API_URL=https://$domain" > .env
        print_debug "Frontend API URL: https://$domain"
    else
        SERVER_IP=$(hostname -I | awk '{print $1}')
        echo "VITE_API_URL=http://$SERVER_IP" > .env
        print_debug "Frontend API URL: http://$SERVER_IP"
    fi

    # Node modules installieren und Frontend bauen
    npm install
    npm run build

    # Prüfen ob Build erfolgreich war
    if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
        print_error "Frontend Build fehlgeschlagen - dist/index.html nicht gefunden"
        ls -la dist/ || echo "dist/ Ordner existiert nicht"
        exit 1
    fi

    print_debug "Frontend Build erfolgreich - $(ls -la dist/ | wc -l) Dateien erstellt"

    # Frontend-Dateien nach /var/www verschieben
    print_status "Kopiere Frontend-Dateien..."
    rm -rf $FRONTEND_DIR
    mkdir -p $FRONTEND_DIR
    cp -r dist/* $FRONTEND_DIR/

    # Prüfen ob Frontend-Dateien korrekt kopiert wurden
    if [ ! -f "$FRONTEND_DIR/index.html" ]; then
        print_error "Frontend-Dateien nicht korrekt kopiert"
        ls -la $FRONTEND_DIR/
        exit 1
    fi

    print_debug "Frontend-Dateien kopiert: $(ls -la $FRONTEND_DIR/ | wc -l) Dateien"

    # Berechtigungen setzen
    print_status "Setze Berechtigungen..."
    chown -R expense:www-data $APP_DIR
    chmod -R 755 $APP_DIR

    print_success "✅ App-Setup abgeschlossen"
}

# Ausführung wenn direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_app "$1"
fi
