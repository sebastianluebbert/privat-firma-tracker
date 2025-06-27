
#!/bin/bash

# Expense Tracker - Backup Script
# Verwendung: ./backup.sh

set -e

# Konfiguration
BACKEND_DIR="/var/www/expense-tracker/backend"
BACKUP_DIR="/var/backups/expense-tracker"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup-Verzeichnis erstellen
mkdir -p $BACKUP_DIR

# Datenbank-Backup
echo "Erstelle Datenbank-Backup..."
cp $BACKEND_DIR/expenses.db $BACKUP_DIR/expenses_$DATE.db

# Alte Backups löschen (älter als 30 Tage)
find $BACKUP_DIR -name "expenses_*.db" -mtime +30 -delete

echo "✅ Backup erstellt: $BACKUP_DIR/expenses_$DATE.db"

# Optional: Backup komprimieren
gzip $BACKUP_DIR/expenses_$DATE.db
echo "📦 Backup komprimiert: $BACKUP_DIR/expenses_$DATE.db.gz"
