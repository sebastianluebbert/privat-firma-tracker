
#!/bin/bash

# Nginx Setup - Konfiguriert Nginx für die App

source "$(dirname "$0")/common.sh"

setup_nginx() {
    local domain="$1"
    
    print_status "🌐 Starte Nginx-Setup..."

    # Nginx: Zuerst alle Standard-Sites deaktivieren
    print_status "Entferne Nginx Standard-Konfiguration..."
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-enabled/000-default

    # Nginx Konfiguration - HTTP oder HTTPS je nach Domain
    print_status "Konfiguriere Nginx..."

    if [ -n "$domain" ]; then
        # Nginx Konfiguration für Domain mit SSL-Vorbereitung
        cat > $NGINX_AVAILABLE << EOF
server {
    listen 80;
    server_name $domain;
    
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

    print_success "✅ Nginx-Setup abgeschlossen"
}

# Ausführung wenn direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_nginx "$1"
fi
