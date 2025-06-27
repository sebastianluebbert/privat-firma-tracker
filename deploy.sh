
#!/bin/bash

# Expense Tracker - Automatische Installation für Debian 12
# Verwendung: curl -fsSL https://raw.githubusercontent.com/[DEIN-USERNAME]/[DEIN-REPO]/main/deploy.sh | bash

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

# Konfiguration
REPO_URL="https://github.com/[DEIN-USERNAME]/[DEIN-REPO].git"
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

# System Update
print_status "Aktualisiere System..."
apt-get update -y
apt-get upgrade -y

# Node.js 18 installieren
print_status "Installiere Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Zusätzliche Pakete installieren
print_status "Installiere zusätzliche Pakete..."
apt-get install -y git nginx ufw build-essential

# PM2 global installieren
print_status "Installiere PM2..."
npm install -g pm2

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

# Frontend Build
print_status "Baue Frontend..."
cd $APP_DIR
npm install
echo "VITE_API_URL=http://localhost" > .env
npm run build

# Frontend-Dateien nach /var/www verschieben
print_status "Kopiere Frontend-Dateien..."
rm -rf $FRONTEND_DIR
mkdir -p $FRONTEND_DIR
cp -r dist/* $FRONTEND_DIR/

# Berechtigungen setzen
print_status "Setze Berechtigungen..."
chown -R expense:www-data $APP_DIR
chmod -R 755 $APP_DIR

# PM2 Setup
print_status "Konfiguriere PM2..."
cd $BACKEND_DIR
sudo -u expense pm2 start server.js --name "expense-backend"
sudo -u expense pm2 save
sudo -u expense pm2 startup

# Nginx Konfiguration
print_status "Konfiguriere Nginx..."
cat > $NGINX_AVAILABLE << EOF
server {
    listen 80;
    server_name _;
    
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

# Nginx Site aktivieren
ln -sf $NGINX_AVAILABLE $NGINX_ENABLED
rm -f /etc/nginx/sites-enabled/default

# Nginx testen und neu starten
nginx -t
systemctl restart nginx
systemctl enable nginx

# Firewall konfigurieren
print_status "Konfiguriere Firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 3001

# Services starten
print_status "Starte Services..."
systemctl start nginx
sudo -u expense pm2 restart expense-backend

# Health Check
print_status "Führe Health Check durch..."
sleep 5

# Backend Health Check
if curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
    print_success "Backend ist erreichbar ✓"
else
    print_error "Backend ist nicht erreichbar ✗"
fi

# Frontend Health Check
if curl -f http://localhost > /dev/null 2>&1; then
    print_success "Frontend ist erreichbar ✓"
else
    print_error "Frontend ist nicht erreichbar ✗"
fi

# Abschlussinformationen
print_success "🎉 Installation erfolgreich abgeschlossen!"
echo ""
echo "📋 Zusammenfassung:"
echo "   • Frontend: http://$(hostname -I | awk '{print $1}')"
echo "   • Backend API: http://$(hostname -I | awk '{print $1}')/api"
echo "   • Logs anzeigen: pm2 logs expense-backend"
echo "   • PM2 Status: pm2 status"
echo "   • Nginx Status: systemctl status nginx"
echo ""
echo "🔧 Wichtige Befehle:"
echo "   • App neustarten: pm2 restart expense-backend"
echo "   • Logs anzeigen: pm2 logs expense-backend"
echo "   • Update: cd $APP_DIR && git pull && npm run build && cp -r dist/* $FRONTEND_DIR/ && pm2 restart expense-backend"
echo ""
echo "📁 Pfade:"
echo "   • App-Verzeichnis: $APP_DIR"
echo "   • Backend: $BACKEND_DIR"
echo "   • Frontend: $FRONTEND_DIR"
echo "   • Datenbank: $BACKEND_DIR/expenses.db"
echo ""
print_success "Die Expense Tracker App ist jetzt unter http://$(hostname -I | awk '{print $1}') erreichbar!"
