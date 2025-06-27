#!/bin/bash

# Expense Tracker - Hauptinstallations-Script
# Verwendung: curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash
# Mit Domain: curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash -s -- --domain=example.com

set -e

# =============================================================================
# FARBEN UND HELPER FUNKTIONEN
# =============================================================================

# Farben für bessere Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print-Funktionen
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

print_debug() {
    echo -e "${YELLOW}[DEBUG]${NC} $1"
}

# Konfiguration
REPO_URL="https://github.com/sebastianluebbert/privat-firma-tracker.git"
APP_DIR="/var/www/expense-tracker"
FRONTEND_DIR="$APP_DIR/frontend"
BACKEND_DIR="$APP_DIR/backend"
NGINX_AVAILABLE="/etc/nginx/sites-available/expense-tracker"
NGINX_ENABLED="/etc/nginx/sites-enabled/expense-tracker"

# =============================================================================
# SYSTEM SETUP FUNKTIONEN
# =============================================================================

setup_system() {
    local domain="$1"
    
    print_status "🔧 Starte System-Setup..."

    # System-Check
    print_status "Überprüfe System-Voraussetzungen..."
    if [[ $EUID -ne 0 ]]; then
       print_error "Dieses Script muss als root ausgeführt werden (sudo)"
    fi

    if ! command -v lsb_release &> /dev/null; then
        print_error "lsb_release nicht gefunden. Stelle sicher, dass du Debian 12 verwendest."
    fi

    DEBIAN_VERSION=$(lsb_release -rs)
    if [[ "$DEBIAN_VERSION" != "12"* ]]; then
        print_warning "Warnung: Dieses Script ist für Debian 12 optimiert. Du verwendest Version $DEBIAN_VERSION"
    fi

    # System Update
    print_status "Aktualisiere System..."
    apt-get update -y
    apt-get upgrade -y

    # Node.js 18 installieren
    print_status "Installiere Node.js 18..."
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    else
        print_debug "Node.js bereits installiert: $(node --version)"
    fi

    # Zusätzliche Pakete installieren
    print_status "Installiere zusätzliche Pakete..."
    apt-get install -y git nginx ufw build-essential sqlite3

    # Certbot installieren wenn Domain angegeben
    if [ -n "$domain" ]; then
        print_status "Installiere Certbot für SSL..."
        apt-get install -y certbot python3-certbot-nginx
    fi

    # PM2 global installieren
    print_status "Installiere PM2..."
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
    else
        print_debug "PM2 bereits installiert"
    fi

    # Benutzer für die App erstellen (falls nicht vorhanden)
    if ! id "expense" &>/dev/null; then
        print_status "Erstelle Benutzer 'expense'..."
        useradd -m -s /bin/bash expense
        usermod -aG www-data expense
    fi

    # Firewall konfigurieren
    print_status "Konfiguriere Firewall..."
    ufw --force enable
    ufw allow ssh
    ufw allow 'Nginx Full'

    print_success "✅ System-Setup abgeschlossen"
}

# =============================================================================
# APP SETUP FUNKTIONEN
# =============================================================================

setup_app() {
    local domain="$1"
    
    print_status "📦 Starte App-Setup..."

    # Repository klonen oder aktualisieren
    if [ -d "$APP_DIR" ]; then
        print_status "Aktualisiere existierende Installation..."
        cd $APP_DIR
        git pull origin main
    else
        print_status "Klone Repository..."
        git clone $REPO_URL $APP_DIR
        cd $APP_DIR
    fi

    # App-Verzeichnisse erstellen
    mkdir -p $FRONTEND_DIR
    mkdir -p $BACKEND_DIR

    # Backend Setup
    print_status "Installiere Backend-Abhängigkeiten..."
    cd $APP_DIR/backend
    npm install --production
    
    # Backend-Dateien nach /var/www/expense-tracker/backend kopieren
    cp -r . $BACKEND_DIR/
    
    # PM2 stoppen falls läuft
    pm2 delete expense-backend 2>/dev/null || true
    
    # PM2 App starten
    print_status "Starte Backend mit PM2..."
    cd $BACKEND_DIR
    pm2 start server.js --name "expense-backend"
    pm2 save
    pm2 startup --silent || true

    # Warte bis Backend vollständig gestartet ist
    print_status "Warte auf Backend-Start..."
    sleep 10
    
    # Backend Health Check mit detailliertem Feedback
    print_status "Prüfe Backend-Verfügbarkeit..."
    BACKEND_READY=false
    for i in {1..30}; do
        print_debug "Versuch $i/30: Teste http://localhost:3001/api/health"
        
        if curl -s --connect-timeout 5 --max-time 10 http://localhost:3001/api/health > /dev/null 2>&1; then
            HEALTH_RESPONSE=$(curl -s http://localhost:3001/api/health)
            print_success "✅ Backend ist erreichbar: $HEALTH_RESPONSE"
            BACKEND_READY=true
            break
        fi
        
        if [ $i -eq 30 ]; then
            print_error "❌ Backend nicht erreichbar nach 30 Versuchen (5 Minuten)"
            print_error "PM2 Logs:"
            pm2 logs expense-backend --lines 20
            exit 1
        fi
        
        print_debug "Backend noch nicht bereit, warte 10 Sekunden..."
        sleep 10
    done

    if [ "$BACKEND_READY" = false ]; then
        print_error "Backend-Start fehlgeschlagen"
    fi

    # Frontend Setup - VEREINFACHTE .env Konfiguration
    print_status "Konfiguriere Frontend für Production..."
    cd $APP_DIR
    
    # .env für Frontend erstellen - Leere VITE_API_URL für relative URLs
    cat > .env << EOF
# Production Configuration
# Leere VITE_API_URL bedeutet: Verwende relative URLs über Nginx Proxy
VITE_API_URL=
EOF
    
    if [ -n "$domain" ]; then
        echo "# Domain: $domain" >> .env
    else
        SERVER_IP=$(hostname -I | awk '{print $1}')
        echo "# Server IP: $SERVER_IP" >> .env
    fi
    
    print_status "Baue Frontend..."
    npm install
    npm run build
    
    # Frontend-Build nach /var/www/expense-tracker/frontend kopieren
    cp -r dist/* $FRONTEND_DIR/

    # Berechtigungen setzen
    chown -R expense:www-data $APP_DIR
    chmod -R 755 $APP_DIR

    print_success "✅ App-Setup abgeschlossen"
}

# =============================================================================
# NGINX SETUP FUNKTIONEN
# =============================================================================

setup_nginx() {
    local domain="$1"
    
    print_status "🌐 Starte Nginx-Setup..."

    # Nginx-Konfiguration erstellen
    if [ -n "$domain" ]; then
        # Konfiguration mit Domain
        cat > $NGINX_AVAILABLE << EOF
server {
    listen 80;
    server_name $domain;
    
    # Frontend - Root location
    location / {
        root $FRONTEND_DIR;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API Proxy - Konsistente Weiterleitung
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        
        # Error handling
        proxy_intercept_errors on;
        error_page 502 503 504 /50x.html;
    }
}
EOF
    else
        # Konfiguration ohne Domain (IP-basiert)
        cat > $NGINX_AVAILABLE << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    # Frontend - Root location
    location / {
        root $FRONTEND_DIR;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API Proxy - Konsistente Weiterleitung
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        
        # Error handling
        proxy_intercept_errors on;
        error_page 502 503 504 /50x.html;
    }
}
EOF
    fi

    # 50x Error Page erstellen
    cat > $FRONTEND_DIR/50x.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Service Unavailable</title>
</head>
<body>
    <h1>Service Temporarily Unavailable</h1>
    <p>The backend service is currently unavailable. Please try again in a few moments.</p>
</body>
</html>
EOF

    # Site aktivieren
    ln -sf $NGINX_AVAILABLE $NGINX_ENABLED
    
    # Default site deaktivieren
    rm -f /etc/nginx/sites-enabled/default

    # Nginx testen und neustarten
    if ! nginx -t; then
        print_error "Nginx-Konfiguration ungültig"
        cat $NGINX_AVAILABLE
        exit 1
    fi
    
    systemctl restart nginx
    systemctl enable nginx

    print_success "✅ Nginx-Setup abgeschlossen"
}

# =============================================================================
# SSL SETUP FUNKTIONEN
# =============================================================================

setup_ssl() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        print_debug "Keine Domain angegeben, SSL-Setup übersprungen"
        return 1
    fi

    print_status "🔒 Starte SSL-Setup für Domain: $domain"

    # DNS-Check
    print_status "Überprüfe DNS-Einstellungen für $domain..."
    DOMAIN_IP=$(dig +short $domain | tail -1)
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        print_warning "⚠️  DNS-Warnung: $domain zeigt auf $DOMAIN_IP, aber Server hat IP $SERVER_IP"
        print_warning "SSL-Setup wird trotzdem versucht..."
    fi
    
    # Certbot SSL-Zertifikat anfordern
    print_status "Fordere SSL-Zertifikat an..."
    if certbot --nginx -d $domain --non-interactive --agree-tos --email admin@$domain --redirect; then
        print_success "✅ SSL-Zertifikat erfolgreich installiert!"
        
        # Frontend .env für HTTPS aktualisieren (weiterhin relative URLs)
        cd $APP_DIR
        cat > .env << EOF
# Production: Use relative URLs through Nginx proxy
# Domain: $domain (HTTPS enabled)
# Backend wird über Nginx-Proxy unter /api/ erreichbar sein
VITE_API_URL=
EOF
        npm run build
        cp -r dist/* $FRONTEND_DIR/
        
        # Auto-Renewal testen
        print_status "Teste automatische Zertifikat-Erneuerung..."
        certbot renew --dry-run
        
        # Cron-Job für Auto-Renewal
        if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab -
            print_success "Auto-Renewal Cron-Job eingerichtet"
        fi
        
        return 0
    else
        print_warning "❌ SSL-Zertifikat konnte nicht installiert werden. App läuft weiter über HTTP."
        return 1
    fi
}

# =============================================================================
# HEALTH CHECK FUNKTIONEN
# =============================================================================

perform_health_check() {
    local domain="$1"
    local ssl_enabled="$2"
    
    print_status "🏥 Führe Health Check durch..."

    # Backend Health Check - Direkt zum Backend
    print_status "Prüfe Backend (direkt)..."
    if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
        print_success "✅ Backend läuft direkt"
    else
        print_error "❌ Backend nicht direkt erreichbar"
        pm2 logs expense-backend --lines 10
        return 1
    fi

    # Frontend/Nginx Health Check
    if [ -n "$domain" ]; then
        if [ "$ssl_enabled" = true ]; then
            BASE_URL="https://$domain"
        else
            BASE_URL="http://$domain"
        fi
    else
        SERVER_IP=$(hostname -I | awk '{print $1}')
        BASE_URL="http://$SERVER_IP"
    fi

    print_status "Prüfe Frontend unter $BASE_URL..."
    if curl -s "$BASE_URL" > /dev/null 2>&1; then
        print_success "✅ Frontend erreichbar"
    else
        print_warning "⚠️  Frontend möglicherweise nicht erreichbar"
    fi

    # API über Nginx testen
    print_status "Prüfe API über Nginx unter $BASE_URL/api/health..."
    if curl -s "$BASE_URL/api/health" > /dev/null 2>&1; then
        print_success "✅ API über Nginx erreichbar"
    else
        print_warning "⚠️  API über Nginx nicht erreichbar"
        print_debug "Nginx-Fehlerlog:"
        tail -n 5 /var/log/nginx/error.log 2>/dev/null || echo "Keine Nginx-Logs verfügbar"
    fi

    # PM2 Status
    print_status "Prüfe PM2 Status..."
    if pm2 list | grep expense-backend | grep online > /dev/null; then
        print_success "✅ PM2 Backend läuft"
    else
        print_error "❌ PM2 Backend nicht aktiv"
        pm2 status
        return 1
    fi

    # Nginx Status
    print_status "Prüfe Nginx Status..."
    if systemctl is-active --quiet nginx; then
        print_success "✅ Nginx läuft"
    else
        print_error "❌ Nginx nicht aktiv"
        systemctl status nginx
        return 1
    fi

    return 0
}

print_summary() {
    local domain="$1"
    local ssl_enabled="$2"
    
    echo ""
    echo "🎉 =================================================================="
    echo "🎉  EXPENSE TRACKER ERFOLGREICH INSTALLIERT!"
    echo "🎉 =================================================================="
    echo ""
    
    if [ -n "$domain" ]; then
        if [ "$ssl_enabled" = true ]; then
            print_success "🌐 App verfügbar unter: https://$domain"
            print_success "🔒 SSL/HTTPS ist aktiv und konfiguriert"
            print_success "🔄 SSL Auto-Renewal läuft täglich um 12:00 Uhr"
        else
            print_success "🌐 App verfügbar unter: http://$domain"
            print_warning "⚠️  SSL konnte nicht eingerichtet werden"
        fi
        print_success "🔗 API verfügbar unter: $domain/api"
        print_success "💚 Health Check: $domain/health"
    else
        SERVER_IP=$(hostname -I | awk '{print $1}')
        print_success "🌐 App verfügbar unter: http://$SERVER_IP"
        print_success "🔗 API verfügbar unter: http://$SERVER_IP/api"
        print_success "💚 Health Check: http://$SERVER_IP/health"
        print_warning "💡 Für HTTPS verwende: bash deploy.sh --domain=deine-domain.com"
    fi
    
    echo ""
    echo "📋 NÜTZLICHE BEFEHLE:"
    echo "   • Logs anzeigen:     pm2 logs expense-backend"
    echo "   • App neustarten:    pm2 restart expense-backend"
    echo "   • Status prüfen:     pm2 status"
    echo "   • Backup erstellen:  cd /var/www/expense-tracker && ./backup.sh"
    
    if [ "$ssl_enabled" = true ]; then
        echo "   • SSL Status:        sudo certbot certificates"
        echo "   • SSL erneuern:      sudo certbot renew"
    fi
    
    echo ""
    echo "📂 WICHTIGE PFADE:"
    echo "   • App-Verzeichnis:   /var/www/expense-tracker"
    echo "   • Datenbank:         /var/www/expense-tracker/backend/expenses.db"
    echo "   • Backups:           /var/backups/expense-tracker"
    echo ""
    print_success "🚀 Installation abgeschlossen! Viel Spaß mit dem Expense Tracker!"
}

# =============================================================================
# HAUPTAUSFÜHRUNG
# =============================================================================

echo "🚀 Starte automatische Installation des Expense Trackers..."

# Parameter parsen
DOMAIN=""
for arg in "$@"
do
    case $arg in
        --domain=*)
        DOMAIN="${arg#*=}"
        shift
        ;;
        *)
        ;;
    esac
done

# Domain-Check
if [ -n "$DOMAIN" ]; then
    print_status "Domain erkannt: $DOMAIN"
    print_status "SSL wird automatisch mit Let's Encrypt konfiguriert"
else
    print_warning "Keine Domain angegeben. App wird nur über HTTP verfügbar sein."
    print_status "Für SSL mit Domain verwenden: bash deploy.sh --domain=deine-domain.com"
fi

# Schritt 1: System Setup
setup_system "$DOMAIN"

# Schritt 2: App Setup
setup_app "$DOMAIN"

# Schritt 3: Nginx Setup
setup_nginx "$DOMAIN"

# Schritt 4: SSL Setup (optional)
SSL_ENABLED=false
if [ -n "$DOMAIN" ]; then
    if setup_ssl "$DOMAIN"; then
        SSL_ENABLED=true
    fi
fi

# Schritt 5: Health Check und Zusammenfassung
if perform_health_check "$DOMAIN" "$SSL_ENABLED"; then
    print_summary "$DOMAIN" "$SSL_ENABLED"
else
    print_error "Health Check fehlgeschlagen. Überprüfe die Logs mit: pm2 logs expense-backend"
fi
