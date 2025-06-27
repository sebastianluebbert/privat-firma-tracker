
# Expense Tracker Setup Anleitung

## 🚀 Ein-Klick Installation (Empfohlen)

### Automatische Installation auf Debian 12 Server:
```bash
# Als root ausführen:
curl -fsSL https://raw.githubusercontent.com/sebastianluebbert/privat-firma-tracker/main/deploy.sh | bash
```

**Das Script installiert automatisch:**
- Node.js 18
- PM2 (Process Manager)
- Nginx (Web Server)
- Klont das Repository
- Baut die App
- Konfiguriert alle Services
- Setzt Firewall-Regeln

**Nach der Installation:**
- Frontend: `http://DEINE-SERVER-IP`
- Backend API: `http://DEINE-SERVER-IP/api`
- Gesunde App: `http://DEINE-SERVER-IP/health`

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

## 📁 Wichtige Pfade

- **App-Verzeichnis:** `/var/www/expense-tracker`
- **Backend:** `/var/www/expense-tracker/backend`
- **Frontend:** `/var/www/expense-tracker/frontend`  
- **Datenbank:** `/var/www/expense-tracker/backend/expenses.db`
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

#### 4. Nginx Konfiguration (optional)
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
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
    }
}
```

#### 5. Einfacher Setup ohne Nginx
```bash
# Backend auf Port 3001 laufen lassen
# Frontend statisch über Python/Apache/etc. bereitstellen:
cd /var/www/expense-frontend
python3 -m http.server 8080
```

## 🔒 Sicherheit & Backups

### Automatische Backups einrichten:
```bash
# Crontab bearbeiten
sudo crontab -e

# Täglich um 3 Uhr Backup erstellen
0 3 * * * /var/www/expense-tracker/backup.sh
```

### Firewall-Status:
```bash
sudo ufw status
```

### SSL-Zertifikat (Certbot):
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d deine-domain.com
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

## Wichtige Hinweise
- SQLite-Datenbank wird automatisch in `backend/expenses.db` erstellt
- Backup der Datenbank regelmäßig erstellen: `./backup.sh`
- Logs überprüfen: `pm2 logs expense-backend`
- Für HTTPS: SSL-Zertifikat mit Certbot einrichten
