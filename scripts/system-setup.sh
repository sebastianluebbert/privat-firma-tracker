
#!/bin/bash

# System Setup - Installiert alle benötigten Pakete und Services

source "$(dirname "$0")/common.sh"

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

# Ausführung wenn direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_system "$1"
fi
