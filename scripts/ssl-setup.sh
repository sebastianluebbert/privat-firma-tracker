
#!/bin/bash

# SSL Setup - Richtet SSL-Zertifikat mit Let's Encrypt ein

source "$(dirname "$0")/common.sh"

setup_ssl() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        print_debug "Keine Domain angegeben, SSL-Setup übersprungen"
        return 0
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
        
        # Frontend .env für HTTPS aktualisieren
        cd $APP_DIR
        echo "VITE_API_URL=https://$domain" > .env
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

# Ausführung wenn direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ssl "$1"
fi
