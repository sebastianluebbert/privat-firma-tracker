
# Expense Tracker Setup Anleitung

## Lokale Entwicklung

### Backend starten
```bash
cd backend
npm install
npm run dev
```

### Frontend starten
```bash
npm run dev
```

## Production Setup auf deinem Server

### 1. Backend installieren
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

### 2. PM2 für Process Management (empfohlen)
```bash
sudo npm install -g pm2
cd /var/www/expense-backend
pm2 start server.js --name "expense-backend"
pm2 startup
pm2 save
```

### 3. Frontend builden und deployen
```bash
# Lokal:
echo "VITE_API_URL=https://your-domain.com" > .env
npm run build

# Build-Ordner auf Server kopieren:
scp -r dist/ user@your-server:/var/www/expense-frontend/
```

### 4. Nginx Konfiguration (optional)
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

### 5. Einfacher Setup ohne Nginx
```bash
# Backend auf Port 3001 laufen lassen
# Frontend statisch über Python/Apache/etc. bereitstellen:
cd /var/www/expense-frontend
python3 -m http.server 8080
```

## Wichtige Hinweise
- SQLite-Datenbank wird automatisch in `backend/expenses.db` erstellt
- Backup der Datenbank regelmäßig erstellen: `cp expenses.db expenses.backup.db`
- Logs überprüfen: `pm2 logs expense-backend`
