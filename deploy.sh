
#!/bin/bash

# Expense Tracker - Automatische Installation für Debian 12 mit SSL
# Verwendung: curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash
# Mit Domain: curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash -s -- --domain=example.com

set -e

echo "🚀 Starte automatische Installation des Expense Trackers..."

# Farben für bessere Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
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

# Konfiguration
REPO_URL="https://github.com/sebastianluebbert/privat-firma-tracker.git"
APP_DIR="/var/www/expense-tracker"
FRONTEND_DIR="$APP_DIR/frontend"
BACKEND_DIR="$APP_DIR/backend"
NGINX_AVAILABLE="/etc/nginx/sites-available/expense-tracker"
NGINX_ENABLED="/etc/nginx/sites-enabled/expense-tracker"

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

# Domain-Check
if [ -n "$DOMAIN" ]; then
    print_status "Domain erkannt: $DOMAIN"
    print_status "SSL wird automatisch mit Let's Encrypt konfiguriert"
else
    print_warning "Keine Domain angegeben. App wird nur über HTTP verfügbar sein."
    print_status "Für SSL mit Domain verwenden: bash deploy.sh --domain=deine-domain.com"
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
if [ -n "$DOMAIN" ]; then
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
if [ -n "$DOMAIN" ]; then
    echo "VITE_API_URL=https://$DOMAIN" > .env
    print_debug "Frontend API URL: https://$DOMAIN"
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

# Nginx: Zuerst alle Standard-Sites deaktivieren
print_status "Entferne Nginx Standard-Konfiguration..."
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/000-default

# Nginx Konfiguration - HTTP oder HTTPS je nach Domain
print_status "Konfiguriere Nginx..."

if [ -n "$DOMAIN" ]; then
    # Nginx Konfiguration für Domain mit SSL-Vorbereitung
    cat > $NGINX_AVAILABLE << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Temporary für Certbot
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Frontend
    location / {
        root $FRONTEND_DIR;
        try_files \$uri \$uri/ /index.html;
        index index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3001/api/health;
        proxy_set_header Host \$host;
    }
}
EOF
else
    # Nginx Konfiguration für IP-only (HTTP)
    cat > $NGINX_AVAILABLE << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    root $FRONTEND_DIR;
    index index.html;
    
    # Frontend
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3001/api/health;
        proxy_set_header Host \$host;
    }
}
EOF
fi

# Nginx Site aktivieren
ln -sf $NGINX_AVAILABLE $NGINX_ENABLED

# Nginx Konfiguration testen
print_status "Teste Nginx Konfiguration..."
if ! nginx -t; then
    print_error "Nginx Konfiguration fehlerhaft"
    cat $NGINX_AVAILABLE
    exit 1
fi

print_debug "Nginx Konfiguration OK"

# Nginx neu starten
systemctl restart nginx
systemctl enable nginx

# Firewall konfigurieren
print_status "Konfiguriere Firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# Debug: Nginx und PM2 Status
print_debug "=== SERVICE STATUS ==="
print_debug "PM2 Status:"
sudo -u expense pm2 status || true
print_debug "Nginx Status:"
systemctl status nginx --no-pager -l || true
print_debug "Aktive Nginx Sites:"
ls -la /etc/nginx/sites-enabled/
print_debug "Frontend Dateien:"
ls -la $FRONTEND_DIR/ | head -10

# SSL-Zertifikat automatisch einrichten
SSL_ENABLED=false
if [ -n "$DOMAIN" ]; then
    print_status "🔒 Richte SSL-Zertifikat ein..."
    
    # DNS-Check
    print_status "Überprüfe DNS-Einstellungen für $DOMAIN..."
    DOMAIN_IP=$(dig +short $DOMAIN | tail -1)
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        print_warning "⚠️  DNS-Warnung: $DOMAIN zeigt auf $DOMAIN_IP, aber Server hat IP $SERVER_IP"
        print_warning "SSL-Setup wird trotzdem versucht..."
    fi
    
    # Certbot SSL-Zertifikat anfordern
    print_status "Fordere SSL-Zertifikat an..."
    if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect; then
        print_success "✅ SSL-Zertifikat erfolgreich installiert!"
        
        # Frontend .env für HTTPS aktualisieren
        cd $APP_DIR
        echo "VITE_API_URL=https://$DOMAIN" > .env
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
        
        SSL_ENABLED=true
    else
        print_warning "❌ SSL-Zertifikat konnte nicht installiert werden. App läuft weiter über HTTP."
        SSL_ENABLED=false
    fi
fi

# Services final neustarten
print_status "Starte Services neu..."
systemctl reload nginx
sudo -u expense pm2 restart expense-backend

# Final Health Check
print_status "Führe abschließenden Health Check durch..."
sleep 5

# Backend Health Check
if curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
    print_success "Backend ist erreichbar ✓"
else
    print_error "Backend ist nicht erreichbar ✗"
    sudo -u expense pm2 logs expense-backend --lines 10
fi

# Frontend Health Check
if [ -n "$DOMAIN" ] && [ "$SSL_ENABLED" = true ]; then
    # HTTPS Check
    if curl -f -k https://$DOMAIN > /dev/null 2>&1; then
        print_success "Frontend (HTTPS) ist erreichbar ✓"
    else
        print_warning "Frontend (HTTPS) nicht erreichbar, prüfe HTTP..."
        if curl -f http://$DOMAIN > /dev/null 2>&1; then
            print_success "Frontend (HTTP) ist erreichbar ✓"
        else
            print_error "Frontend ist nicht erreichbar ✗"
        fi
    fi
elif [ -n "$DOMAIN" ]; then
    # HTTP Check mit Domain
    if curl -f http://$DOMAIN > /dev/null 2>&1; then
        print_success "Frontend (HTTP) ist erreichbar ✓"
    else
        print_error "Frontend (HTTP) ist nicht erreichbar ✗"
    fi
else
    # IP-only Check
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if curl -f http://$SERVER_IP > /dev/null 2>&1; then
        print_success "Frontend ist erreichbar ✓"
    else
        print_error "Frontend ist nicht erreichbar ✗"
        print_debug "Versuche localhost..."
        if curl -f http://localhost > /dev/null 2>&1; then
            print_success "Frontend über localhost erreichbar ✓"
        else
            print_error "Frontend auch über localhost nicht erreichbar ✗"
        fi
    fi
fi

# Abschlussinformationen
print_success "🎉 Installation erfolgreich abgeschlossen!"
echo ""
echo "📋 Zusammenfassung:"

SERVER_IP=$(hostname -I | awk '{print $1}')

if [ -n "$DOMAIN" ] && [ "$SSL_ENABLED" = true ]; then
    echo "   • 🔒 HTTPS Website: https://$DOMAIN"
    echo "   • 🔒 Backend API: https://$DOMAIN/api"
    echo "   • 🔒 SSL-Zertifikat: Automatisch installiert und konfiguriert"
    echo "   • 🔄 Auto-Renewal: Täglich um 12:00 Uhr geprüft"
elif [ -n "$DOMAIN" ]; then
    echo "   • 🌐 HTTP Website: http://$DOMAIN"
    echo "   • 🌐 Backend API: http://$DOMAIN/api"
    echo "   • ⚠️  SSL: Konnte nicht eingerichtet werden (DNS-Problem?)"
else
    echo "   • 🌐 Frontend: http://$SERVER_IP"
    echo "   • 🌐 Backend API: http://$SERVER_IP/api"
    echo "   • ℹ️  Für SSL mit Domain: bash deploy.sh --domain=deine-domain.com"
fi

echo "   • 📊 PM2 Status: pm2 status"
echo "   • 📊 Logs anzeigen: pm2 logs expense-backend"
echo "   • 🔧 Nginx Status: systemctl status nginx"

if [ -n "$DOMAIN" ] && [ "$SSL_ENABLED" = true ]; then
    echo "   • 🔒 SSL Status: certbot certificates"
fi

echo ""
echo "🔧 Wichtige Befehle:"
echo "   • App neustarten: pm2 restart expense-backend"
echo "   • Logs anzeigen: pm2 logs expense-backend"
echo "   • Nginx testen: nginx -t"
echo "   • Update: cd $APP_DIR && ./update.sh"

if [ -n "$DOMAIN" ] && [ "$SSL_ENABLED" = true ]; then
    echo "   • SSL erneuern: certbot renew"
fi

echo ""
echo "📁 Wichtige Pfade:"
echo "   • App-Verzeichnis: $APP_DIR"
echo "   • Frontend: $FRONTEND_DIR"
echo "   • Backend: $BACKEND_DIR"
echo "   • Datenbank: $BACKEND_DIR/expenses.db"

if [ -n "$DOMAIN" ] && [ "$SSL_ENABLED" = true ]; then
    echo "   • SSL-Zertifikate: /etc/letsencrypt/live/$DOMAIN/"
fi

echo ""

if [ -n "$DOMAIN" ] && [ "$SSL_ENABLED" = true ]; then
    print_success "🔒 Die Expense Tracker App ist jetzt sicher unter https://$DOMAIN erreichbar!"
elif [ -n "$DOMAIN" ]; then
    print_success "🌐 Die Expense Tracker App ist unter http://$DOMAIN erreichbar!"
    print_warning "⚠️  Für SSL überprüfe deine DNS-Einstellungen und führe das Script erneut aus."
else
    print_success "🌐 Die Expense Tracker App ist jetzt unter http://$SERVER_IP erreichbar!"
fi

print_status "🎯 Installation abgeschlossen! Bei Problemen führe 'pm2 logs expense-backend' aus."
