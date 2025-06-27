
#!/bin/bash

# Health Check - Überprüft ob alle Services korrekt laufen

source "$(dirname "$0")/common.sh"

perform_health_check() {
    local domain="$1"
    local ssl_enabled="$2"
    
    print_status "🏥 Starte Health Check..."

    # Services final neustarten
    print_status "Starte Services neu..."
    systemctl reload nginx
    sudo -u expense pm2 restart expense-backend

    # Final Health Check
    print_status "Führe abschließenden Health Check durch..."
    sleep 5

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

    # Backend Health Check
    if curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
        print_success "Backend ist erreichbar ✓"
    else
        print_error "Backend ist nicht erreichbar ✗"
        sudo -u expense pm2 logs expense-backend --lines 10
        return 1
    fi

    # Frontend Health Check
    if [ -n "$domain" ] && [ "$ssl_enabled" = "true" ]; then
        # HTTPS Check
        if curl -f -k https://$domain > /dev/null 2>&1; then
            print_success "Frontend (HTTPS) ist erreichbar ✓"
        else
            print_warning "Frontend (HTTPS) nicht erreichbar, prüfe HTTP..."
            if curl -f http://$domain > /dev/null 2>&1; then
                print_success "Frontend (HTTP) ist erreichbar ✓"
            else
                print_error "Frontend ist nicht erreichbar ✗"
                return 1
            fi
        fi
    elif [ -n "$domain" ]; then
        # HTTP Check mit Domain
        if curl -f http://$domain > /dev/null 2>&1; then
            print_success "Frontend (HTTP) ist erreichbar ✓"
        else
            print_error "Frontend (HTTP) ist nicht erreichbar ✗"
            return 1
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
                return 1
            fi
        fi
    fi

    print_success "✅ Health Check erfolgreich"
    return 0
}

print_summary() {
    local domain="$1"
    local ssl_enabled="$2"
    
    # Abschlussinformationen
    print_success "🎉 Installation erfolgreich abgeschlossen!"
    echo ""
    echo "📋 Zusammenfassung:"

    SERVER_IP=$(hostname -I | awk '{print $1}')

    if [ -n "$domain" ] && [ "$ssl_enabled" = "true" ]; then
        echo "   • 🔒 HTTPS Website: https://$domain"
        echo "   • 🔒 Backend API: https://$domain/api"
        echo "   • 🔒 SSL-Zertifikat: Automatisch installiert und konfiguriert"
        echo "   • 🔄 Auto-Renewal: Täglich um 12:00 Uhr geprüft"
    elif [ -n "$domain" ]; then
        echo "   • 🌐 HTTP Website: http://$domain"
        echo "   • 🌐 Backend API: http://$domain/api"
        echo "   • ⚠️  SSL: Konnte nicht eingerichtet werden (DNS-Problem?)"
    else
        echo "   • 🌐 Frontend: http://$SERVER_IP"
        echo "   • 🌐 Backend API: http://$SERVER_IP/api"
        echo "   • ℹ️  Für SSL mit Domain: bash deploy.sh --domain=deine-domain.com"
    fi

    echo "   • 📊 PM2 Status: pm2 status"
    echo "   • 📊 Logs anzeigen: pm2 logs expense-backend"
    echo "   • 🔧 Nginx Status: systemctl status nginx"

    if [ -n "$domain" ] && [ "$ssl_enabled" = "true" ]; then
        echo "   • 🔒 SSL Status: certbot certificates"
    fi

    echo ""
    echo "🔧 Wichtige Befehle:"
    echo "   • App neustarten: pm2 restart expense-backend"
    echo "   • Logs anzeigen: pm2 logs expense-backend"
    echo "   • Nginx testen: nginx -t"
    echo "   • Update: cd $APP_DIR && ./update.sh"

    if [ -n "$domain" ] && [ "$ssl_enabled" = "true" ]; then
        echo "   • SSL erneuern: certbot renew"
    fi

    echo ""
    echo "📁 Wichtige Pfade:"
    echo "   • App-Verzeichnis: $APP_DIR"
    echo "   • Frontend: $FRONTEND_DIR"
    echo "   • Backend: $BACKEND_DIR"
    echo "   • Datenbank: $BACKEND_DIR/expenses.db"

    if [ -n "$domain" ] && [ "$ssl_enabled" = "true" ]; then
        echo "   • SSL-Zertifikate: /etc/letsencrypt/live/$domain/"
    fi

    echo ""

    if [ -n "$domain" ] && [ "$ssl_enabled" = "true" ]; then
        print_success "🔒 Die Expense Tracker App ist jetzt sicher unter https://$domain erreichbar!"
    elif [ -n "$domain" ]; then
        print_success "🌐 Die Expense Tracker App ist unter http://$domain erreichbar!"
        print_warning "⚠️  Für SSL überprüfe deine DNS-Einstellungen und führe das Script erneut aus."
    else
        print_success "🌐 Die Expense Tracker App ist jetzt unter http://$SERVER_IP erreichbar!"
    fi

    print_status "🎯 Installation abgeschlossen! Bei Problemen führe 'pm2 logs expense-backend' aus."
}

# Ausführung wenn direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    perform_health_check "$1" "$2"
    print_summary "$1" "$2"
fi
