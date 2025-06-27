

# Expense Tracker Setup Anleitung

## 🚀 Ein-Klick Installation (Empfohlen)

### Automatische Installation auf Debian 12 Server:

**Ohne SSL (nur HTTP):**
```bash
# Als root ausführen:
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash
```

**Mit automatischem SSL (HTTPS):**
```bash
# Als root ausführen (Domain durch deine ersetzen):
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash -s -- --domain=deine-domain.com
```

**Das Script installiert automatisch:**
- Node.js 18
- PM2 (Process Manager)
- Nginx (Web Server)
- **SSL/HTTPS mit Let's Encrypt (bei Domain-Angabe)**
- **Automatische SSL-Erneuerung**
- Klont das Repository
- Baut die App
- Konfiguriert alle Services
- Setzt Firewall-Regeln

**Nach der Installation:**
- **Mit SSL:** `https://deine-domain.com`
- **Ohne SSL:** `http://DEINE-SERVER-IP`
- Backend API: `https://deine-domain.com/api` oder `http://DEINE-SERVER-IP/api`
- Health Check: `https://deine-domain.com/health`

## 🔒 SSL nachträglich einrichten

Falls du zuerst ohne Domain installiert hast, kannst du SSL nachträglich hinzufügen:

```bash
# SSL für bestehende Installation einrichten:
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/setup-ssl.sh | bash -s -- --domain=deine-domain.com
```

**Voraussetzungen für SSL:**
- Domain muss auf deinen Server zeigen (DNS A-Record)
- Port 80 und 443 müssen erreichbar sein
- Gültige E-Mail-Adresse für Let's Encrypt

## 🔄 Updates & Wartung

### App aktualisieren:
```bash
cd /var/www/expense-tracker
./update.sh
```

### Datenbank-Backup erstellen:
```bash
./backup.sh
```

### Logs anzeigen:
```bash
pm2 logs expense-backend
```

### Services verwalten:
```bash
# Status anzeigen
pm2 status
systemctl status nginx

# Neustarten
pm2 restart expense-backend
systemctl restart nginx
```

### SSL-Befehle:
```bash
# SSL-Zertifikat Status anzeigen
sudo certbot certificates

# SSL manuell erneuern
sudo certbot renew

# SSL-Erneuerung testen
sudo certbot renew --dry-run
```

## 📁 Wichtige Pfade

- **App-Verzeichnis:** `/var/www/expense-tracker`
- **Backend:** `/var/www/expense-tracker/backend`
- **Frontend:** `/var/www/expense-tracker/frontend`  
- **Datenbank:** `/var/www/expense-tracker/backend/expenses.db`
- **SSL-Zertifikate:** `/etc/letsencrypt/live/deine-domain.com/`
- **Backups:** `/var/backups/expense-tracker`
- **Logs:** `pm2 logs expense-backend`

## 🛠️ Manuelle Installation (Alternative)

### Lokale Entwicklung

#### Backend starten
```bash
cd backend
npm install
npm run dev
```

#### Frontend starten
```bash
npm run dev
```

### Production Setup auf deinem Server

#### 1. Backend installieren
```bash
# Node.js installieren (falls nicht vorhanden)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Backend-Dateien auf Server kopieren
scp -r backend/ user@your-server:/var/www/expense-backend/

# Auf dem Server:
cd /var/www/expense-backend
npm install --production
```

#### 2. PM2 für Process Management (empfohlen)
```bash
sudo npm install -g pm2
cd /var/www/expense-backend
pm2 start server.js --name "expense-backend"
pm2 startup
pm2 save
```

#### 3. Frontend builden und deployen
```bash
# Lokal:
echo "VITE_API_URL=https://your-domain.com" > .env
npm run build

# Build-Ordner auf Server kopieren:
scp -r dist/ user@your-server:/var/www/expense-frontend/
```

#### 4. Nginx Konfiguration mit SSL
```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # Frontend
    location / {
        root /var/www/expense-frontend;
        try_files $uri $uri/ /index.html;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### 5. SSL manuell einrichten
```bash
# Certbot installieren
sudo apt install certbot python3-certbot-nginx

# SSL-Zertifikat anfordern
sudo certbot --nginx -d deine-domain.com

# Auto-Renewal testen
sudo certbot renew --dry-run
```

## 🔒 Sicherheit & Backups

### Automatische Backups einrichten:
```bash
# Crontab bearbeiten
sudo crontab -e

# Täglich um 3 Uhr Backup erstellen
0 3 * * * /var/www/expense-tracker/backup.sh
```

### SSL Auto-Renewal:
```bash
# Prüfen ob Cron-Job existiert
sudo crontab -l | grep certbot

# Manuell hinzufügen falls nötig
sudo crontab -e
# Dann hinzufügen:
0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx
```

### Firewall-Status:
```bash
sudo ufw status
```

## 🆘 Troubleshooting

### App läuft nicht:
```bash
# PM2 Status prüfen
pm2 status
pm2 logs expense-backend

# Nginx Status prüfen  
sudo systemctl status nginx
sudo nginx -t
```

### SSL-Probleme:
```bash
# SSL-Zertifikat Status
sudo certbot certificates

# Nginx SSL-Test
sudo nginx -t

# SSL-Logs prüfen
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Domain DNS prüfen
dig deine-domain.com
nslookup deine-domain.com
```

### Datenbank-Probleme:
```bash
# Backup wiederherstellen
cd /var/www/expense-tracker/backend
cp expenses.backup.DATUM.db expenses.db
pm2 restart expense-backend
```

### Port-Konflikte:
```bash
# Welcher Prozess nutzt Port 3001?
sudo lsof -i :3001
sudo netstat -tulpn | grep :3001
```

### SSL-Zertifikat erneuern:
```bash
# Manuell erneuern
sudo certbot renew

# Spezifische Domain erneuern
sudo certbot renew --cert-name deine-domain.com
```

## ⚠️ Wichtige Hinweise

### SSL-Voraussetzungen:
- **Domain muss auf Server zeigen** (DNS A-Record konfigurieren)
- **Port 80 und 443 müssen offen sein** (Firewall-Einstellungen prüfen)
- **Gültige E-Mail für Let's Encrypt** (wird automatisch als admin@domain.com gesetzt)

### DNS-Konfiguration:
```
Typ: A
Name: @ (oder deine-subdomain)
Wert: DEINE-SERVER-IP
TTL: 3600 (oder automatisch)
```

### Backup-Strategie:
- SQLite-Datenbank wird automatisch in `backend/expenses.db` erstellt
- **Tägliche Backups:** `./backup.sh` ausführen
- **SSL-Zertifikate:** Automatische Erneuerung alle 60 Tage
- **Code-Updates:** Mit `./update.sh` durchführen

