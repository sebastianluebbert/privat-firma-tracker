
#!/bin/bash

# Expense Tracker - Hauptinstallations-Script
# Verwendung: curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash
# Mit Domain: curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash -s -- --domain=example.com

set -e

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common functions laden
source "$SCRIPT_DIR/scripts/common.sh"

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
source "$SCRIPT_DIR/scripts/system-setup.sh"
setup_system "$DOMAIN"

# Schritt 2: App Setup
source "$SCRIPT_DIR/scripts/app-setup.sh"
setup_app "$DOMAIN"

# Schritt 3: Nginx Setup
source "$SCRIPT_DIR/scripts/nginx-setup.sh"
setup_nginx "$DOMAIN"

# Schritt 4: SSL Setup (optional)
SSL_ENABLED=false
if [ -n "$DOMAIN" ]; then
    source "$SCRIPT_DIR/scripts/ssl-setup.sh"
    if setup_ssl "$DOMAIN"; then
        SSL_ENABLED=true
    fi
fi

# Schritt 5: Health Check und Zusammenfassung
source "$SCRIPT_DIR/scripts/health-check.sh"
if perform_health_check "$DOMAIN" "$SSL_ENABLED"; then
    print_summary "$DOMAIN" "$SSL_ENABLED"
else
    print_error "Health Check fehlgeschlagen. Überprüfe die Logs."
fi
