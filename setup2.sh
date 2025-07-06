#!/bin/bash

set -e

echo "🔧 Imposto limite inotify per watchers..."
echo -ne "\033]0;🔧 Imposto limite inotify per watchers...\007"
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "🧰 [1] Aggiornamento pacchetti..."
echo -ne "\033]0;🧰 [1] Aggiornamento pacchetti...\007"
sudo apt update && sudo apt upgrade -y

echo "🖥️ [2] Installazione Git..."
echo -ne "\033]0;🖥️ [2] Installazione Git...\007"
sudo apt install -y git

echo "🔧 [3] Installazione Node.js + NPM..."
echo -ne "\033]0;🔧 [3] Installazione Node.js + NPM...\007"
sudo apt install -y nodejs npm

echo "🔑 [4] Configuro MySQL con utente e database per Laravel (gestione esistenza utente)..."
echo -ne "\033]0;🔑 [4] Configuro MySQL con utente e database per Laravel...\007"

sudo mysql <<EOF
# Crea il database se non esiste già
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Crea il nuovo utente
CREATE USER 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';

# Concedi i privilegi al nuovo utente sul database
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';

# Applica i cambiamenti dei privilegi
FLUSH PRIVILEGES;
EOF

echo "Utente 'laravel_oxylabs_test_user' e database 'laravel_oxylabs_test_database' creati e configurati con successo!"

echo "📁 [5] Clonazione progetto Laravel nella posizione corretta..."
echo -ne "\003]0;📁 [5] Clonazione progetto Laravel...\007"
sudo git clone https://github.com/smal82/laravel-oxylabs-test.git /var/www/html/laravel-oxylabs-test
cd /var/www/html/laravel-oxylabs-test
sudo rm -f /var/www/html/laravel-oxylabs-test/setup.sh

echo "🔐 [6] Imposto permessi su cartella progetto..."
echo -ne "\033]0;🔐 [6] Imposto permessi su cartella progetto...\007"
sudo chown -R www-data:www-data .
sudo chmod -R 755 .

echo "👤 [7] Rilevo utente corrente..."
echo -ne "\033]0;👤 [7] Rilevo utente corrente...\007"
CURRENT_USER=$(whoami)
echo "✅ Utente rilevato: $CURRENT_USER"

echo "🔧 [8] Imposto permessi sulla cartella Laravel per $CURRENT_USER..."
echo -ne "\033]0;🔧 [8] Imposto permessi sulla cartella Laravel per $CURRENT_USER...\007"
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" /var/www/html/laravel-oxylabs-test

echo "⚠️ [9] Autorizzo la directory per Git..."
echo -ne "\033]0;⚠️ [0] Autorizzo la directory per Git...\007"
git config --global --add safe.directory /var/www/html/laravel-oxylabs-test

echo "📦 [10] Installazione Composer..."
echo -ne "\033]0;📦 [10] Installazione Composer...\007"
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "📦 [11] Installazione dipendenze Laravel..."
echo -ne "\033]0;📦 [11] Installazione dipendenze Laravel...\007"
composer install
npm install

echo "🧹 [12] Pulizia cache Laravel..."
echo -ne "\033]0;🧹 [12] Pulizia cache Laravel...\007"
php artisan config:clear
php artisan route:clear
php artisan view:clear

# CONFIGURA .env
if [ ! -f ".env" ]; then
    echo "📝 Creo .env..."
    cp .env.example .env
    php artisan key:generate
else
    echo "✅ File .env già presente — salto creazione."
fi

echo "✏️ [13] Correggo configurazione MySQL in .env..."
echo -ne "\033]0;✏️ [13] Correggo configurazione MySQL in .env...\007"
sed -i '/DB_CONNECTION=/c\DB_CONNECTION=mysql' .env
sed -i '/DB_HOST=/c\DB_HOST=127.0.0.1' .env
sed -i '/DB_PORT=/c\DB_PORT=3306' .env
sed -i '/DB_DATABASE=/c\DB_DATABASE=laravel_oxylabs_test_database' .env
sed -i '/DB_USERNAME=/c\DB_USERNAME=laravel_oxylabs_test_user' .env # USIAMO L'UTENTE CREATO
sed -i '/DB_PASSWORD=/c\DB_PASSWORD=kA[Q+LgF-~1C' .env     # CON LA SUA PASSWORD

sudo rm -f /var/www/html/laravel-oxylabs-test/.env.example

echo "📦 [14] Eseguo migrazione e storage link..."
echo -ne "\033]0;📦 [14] Eseguo migrazione e storage link...\007"
php artisan migrate
php artisan storage:link

echo "🧹 [15] Pulizia cache Laravel (finale)..."
echo -ne "\033]0;🧹 [15] Pulizia cache Laravel (finale)...\007"
php artisan config:clear
php artisan route:clear
php artisan view:clear

echo "🎛️ [16] Installazione Filament..."
echo -ne "\033]0;🎛️ [16] Installazione Filament...\007"
# Lasciamo che Filament installi i suoi file di default.
php artisan filament:install --panels

# Importante: Eseguire dump-autoload e pulizia cache DOPO l'installazione di Filament
echo "🔃 [17] Composer dump-autoload e pulizia cache dopo installazione Filament..."
echo -ne "\033]0;🔃 [17] Composer dump-autoload e pulizia cache dopo installazione Filament...\007"
composer dump-autoload
php artisan optimize:clear # Pulisce tutte le cache nuovamente

echo "👤 [18] Creo utente admin..."
echo -ne "\033]0;👤 [18] Creo utente admin...\007"
php artisan make:filament-user

echo "🔄  [19] Backup di AdminPanelProvider.php e sostituzione con la versione personalizzata..."
echo -ne "\033]0;🔄 [19] Backup di AdminPanelProvider.php e sostituzione con la versione personalizzata...\007"
# Backup del file generato da Filament
mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak
# Sostituzione con il file personalizzato.
mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php

# Pulizia cache dopo la sostituzione del provider
echo "🔃 [20] Composer dump-autoload e pulizia cache dopo sostituzione AdminPanelProvider.php..."
echo -ne "\033]0;🔃 [20] Composer dump-autoload e pulizia cache dopo sostituzione AdminPanelProvider.php...\007"
composer dump-autoload
php artisan optimize:clear # Pulisce tutte le cache nuovamente

echo "🧩 [21] Installo DomCrawler Symfony..."
echo -ne "\033]0;🧩 [21] Installo DomCrawler Symfony...\007"
composer require symfony/dom-crawler

echo "📦 [22] Importo prodotti nel database..."
echo -ne "\033]0;📦  [22] Importo prodotti nel database...\007"
php artisan import:products || echo "⚠️ Import fallita. Controlla /api/import o il Job."

echo "🕰️ [23] Configuro cron per importazione automatica ogni 10 minuti..."
echo -ne "\033]0;🕰️ [23] Configuro cron per importazione automatica ogni 10 minuti...\007"
croncmd="* * * * * cd /var/www/html/laravel-oxylabs-test && php artisan schedule:run >> /dev/null 2>&1"
( crontab -l | grep -v -F "$croncmd" ; echo "$croncmd" ) | crontab -

# Avvio servizi Laravel
echo "🎨 [24] Compilo frontend (npm run dev)..."
echo -ne "\033]0;🎨 [24] Compilo frontend (npm run dev)...\\007"
nohup npm run dev > storage/logs/dev.log 2>&1 &

echo "🚀 [25] Avvio Laravel server..."
echo -ne "\033]0;🚀 [25] Avvio Laravel server...\007"
nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &

echo "📬  [26] Avvio worker Laravel per job async..."
echo -ne "\033]0;📬 [26] Avvio worker Laravel per job async...\007"
nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &

echo ""
echo "✅ Setup completato e Laravel è operativo!"
echo "🔒 Admin → http://127.0.0.1:8000/admin/login"
echo "🛒 Frontend → http://127.0.0.1:8000/view/products"
echo "📦 Worker attivo per importazione prodotti async"
