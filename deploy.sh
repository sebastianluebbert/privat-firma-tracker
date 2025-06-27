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
    
    # PM2 App starten (vor Frontend-Build!)
    print_status "Starte Backend mit PM2..."
    cd $BACKEND_DIR
    pm2 delete expense-backend 2>/dev/null || true
    pm2 start server.js --name "expense-backend"
    pm2 save
    pm2 startup --silent || true

    # Warte kurz bis Backend läuft
    sleep 3
    
    # Backend Health Check
    print_status "Prüfe Backend-Verfügbarkeit..."
    for i in {1..10}; do
        if curl -s http://localhost:3001/api/health > /dev/null; then
            print_success "Backend läuft und ist erreichbar"
            break
        fi
        if [ $i -eq 10 ]; then
            print_error "Backend nicht erreichbar nach 10 Versuchen"
        fi
        sleep 2
    done

    # Frontend Setup
    print_status "Baue Frontend..."
    cd $APP_DIR
    
    # .env für Frontend erstellen (leer für relative URLs)
    echo "# Production: Use relative URLs through Nginx proxy" > .env
    if [ -n "$domain" ]; then
        echo "# Domain: $domain" >> .env
    else
        SERVER_IP=$(hostname -I | awk '{print $1}')
        echo "# Server IP: $SERVER_IP" >> .env
    fi
    # Lasse VITE_API_URL leer für relative URLs
    echo "VITE_API_URL=" >> .env
    
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
    
    # Frontend
    location / {
        root $FRONTEND_DIR;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # CORS Headers
        add_header Access-Control-Allow-Origin \$http_origin always;
        add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
        
        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin \$http_origin;
            add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization";
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type 'text/plain; charset=utf-8';
            add_header Content-Length 0;
            return 204;
        }
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3001/api/health;
        proxy_set_header Host \$host;
    }
}
EOF
    else
        # Konfiguration ohne Domain (IP-basiert)
        cat > $NGINX_AVAILABLE << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    # Frontend
    location / {
        root $FRONTEND_DIR;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # CORS Headers
        add_header Access-Control-Allow-Origin \$http_origin always;
        add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
        
        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin \$http_origin;
            add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization";
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type 'text/plain; charset=utf-8';
            add_header Content-Length 0;
            return 204;
        }
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3001/api/health;
        proxy_set_header Host \$host;
    }
}
EOF
    fi

    # Site aktivieren
    ln -sf $NGINX_AVAILABLE $NGINX_ENABLED
    
    # Default site deaktivieren
    rm -f /etc/nginx/sites-enabled/default

    # Nginx testen und neustarten
    nginx -t
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
        
        # Frontend .env für HTTPS aktualisieren (trotzdem relative URLs verwenden)
        cd $APP_DIR
        echo "# Production: Use relative URLs through Nginx proxy" > .env
        echo "# Domain: $domain (HTTPS enabled)" >> .env
        echo "VITE_API_URL=" >> .env
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

    # Backend Health Check
    print_status "Prüfe Backend..."
    if curl -s http://localhost:3001/api/health > /dev/null; then
        print_success "✅ Backend läuft"
    else
        print_error "❌ Backend nicht erreichbar"
        return 1
    fi

    # Frontend Health Check
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
    if curl -s "$BASE_URL" > /dev/null; then
        print_success "✅ Frontend erreichbar"
    else
        print_warning "⚠️  Frontend möglicherweise nicht erreichbar"
        return 1
    fi

    # PM2 Status
    print_status "Prüfe PM2 Status..."
    pm2 list | grep expense-backend | grep online > /dev/null
    if [ $? -eq 0 ]; then
        print_success "✅ PM2 Backend läuft"
    else
        print_error "❌ PM2 Backend nicht aktiv"
        return 1
    fi

    # Nginx Status
    print_status "Prüfe Nginx Status..."
    if systemctl is-active --quiet nginx; then
        print_success "✅ Nginx läuft"
    else
        print_error "❌ Nginx nicht aktiv"
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
        print_success "🔗 API verfügbar unter: https://$domain/api"
        print_success "💚 Health Check: https://$domain/health"
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
    print_error "Health Check fehlgeschlagen. Überprüfe die Logs."
fi
