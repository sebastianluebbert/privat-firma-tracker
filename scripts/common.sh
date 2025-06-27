
#!/bin/bash

# Common functions and variables for all deployment scripts

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

# Konfiguration
REPO_URL="https://github.com/sebastianluebbert/privat-firma-tracker.git"
APP_DIR="/var/www/expense-tracker"
FRONTEND_DIR="$APP_DIR/frontend"
BACKEND_DIR="$APP_DIR/backend"
NGINX_AVAILABLE="/etc/nginx/sites-available/expense-tracker"
NGINX_ENABLED="/etc/nginx/sites-enabled/expense-tracker"
