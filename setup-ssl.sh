
#!/bin/bash

# SSL Setup für bestehende Expense Tracker Installation
# Verwendung: ./setup-ssl.sh --domain=deine-domain.com

set -e

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

# Root-Check
if [[ $EUID -ne 0 ]]; then
   print_error "Dieses Script muss als root ausgeführt werden (sudo)"
fi

# Domain-Check
if [ -z "$DOMAIN" ]; then
    print_error "Domain ist erforderlich. Verwendung: ./setup-ssl.sh --domain=deine-domain.com"
fi

print_status "🔒 SSL-Setup für Domain: $DOMAIN"

# Konfiguration
APP_DIR="/var/www/expense-tracker"
FRONTEND_DIR="$APP_DIR/frontend"
NGINX_AVAILABLE="/etc/nginx/sites-available/expense-tracker"

# Prüfen ob App installiert ist
if [ ! -d "$APP_DIR" ]; then
    print_error "Expense Tracker ist nicht installiert. Führe zuerst deploy.sh aus."
fi

# Certbot installieren
print_status "Installiere Certbot..."
apt-get update
apt-get install -y certbot python3-certbot-nginx

# DNS-Check
print_status "Überprüfe DNS-Einstellungen für $DOMAIN..."
DOMAIN_IP=$(dig +short $DOMAIN | tail -1)
SERVER_IP=$(hostname -I | awk '{print $1}')

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    print_warning "⚠️  DNS-Warnung: $DOMAIN zeigt auf $DOMAIN_IP, aber Server hat IP $SERVER_IP"
    print_warning "Stelle sicher, dass deine Domain korrekt auf diesen Server zeigt."
    read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "SSL-Setup abgebrochen."
    fi
fi

# Nginx Konfiguration für Domain aktualisieren
print_status "Aktualisiere Nginx-Konfiguration für Domain..."
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
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3001/api/health;
        proxy_set_header Host \$host;
    }
}
EOF

# Nginx neu laden
nginx -t && systemctl reload nginx

# SSL-Zertifikat anfordern
print_status "Fordere SSL-Zertifikat an..."
if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect; then
    print_success "✅ SSL-Zertifikat erfolgreich installiert!"
    
    # Frontend .env aktualisieren
    print_status "Aktualisiere Frontend-Konfiguration für HTTPS..."
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
    
    print_success "🔒 SSL erfolgreich eingerichtet!"
    print_success "Die App ist jetzt unter https://$DOMAIN erreichbar"
    
else
    print_error "❌ SSL-Zertifikat konnte nicht installiert werden."
    print_error "Überprüfe deine DNS-Einstellungen und versuche es erneut."
fi
