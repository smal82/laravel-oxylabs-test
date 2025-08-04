#!/bin/bash

# Gestione del file di log: Elimina il log precedente all'avvio
LOGFILE="setup.log"
rm -f "$LOGFILE" || true # Elimina il file di log, ignorando errori se non esiste

# Abilita la modalità "fail-fast": lo script si interrompe al primo comando fallito.
set -e
# Reindirizza stdout e stderr sia alla console che al file di log.
exec > >(tee -a "$LOGFILE") 2>&1

echo "📋 Avvio script multipiattaforme - $(date)"

# 🔍 Rileva la distribuzione e imposta il gestore di pacchetti.
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')

# Definisci il percorso del progetto Laravel.
PROJECT_DIR="/var/www/html/laravel-oxylabs-test"

# Imposta i comandi e i gruppi in base alla distribuzione.
if [[ "$DISTRO" =~ ^(ubuntu|debian|linuxmint|elementary)$ ]]; then
    PM="apt"
    UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
    INSTALL_CMD="sudo apt install -y"
    WEBSERVER_GROUP="www-data"
elif [[ "$DISTRO" =~ ^(fedora|centos|almalinux)$ ]]; then
    PM="dnf"
    UPDATE_CMD="sudo dnf upgrade --refresh -y"
    INSTALL_CMD="sudo dnf install -y"
    WEBSERVER_GROUP="apache"
elif [[ "$DISTRO" =~ ^(arch|manjaro)$ ]]; then
    PM="pacman"
    UPDATE_CMD="sudo pacman -Syu --noconfirm" # Sincronizza e aggiorna i pacchetti
    INSTALL_CMD="sudo pacman -S --noconfirm --needed" # Installa pacchetti solo se necessari o da aggiornare
    WEBSERVER_GROUP="http" # Gruppo tipico per web server su Arch (es. apache, nginx)
else
    echo "🚫 Distribuzione non supportata: $DISTRO"
    exit 1
fi
echo "✅ Distribuzione: $DISTRO | Package manager: $PM"

echo "🔧 Imposto limite inotify..."
REQUIRED_WATCHES=524288
CURRENT_WATCHES=$(cat /proc/sys/fs/inotify/max_user_watches)

if (( CURRENT_WATCHES < REQUIRED_WATCHES )); then
    echo "Il valore attuale di fs.inotify.max_user_watches ($CURRENT_WATCHES) è inferiore a $REQUIRED_WATCHES."
    echo "Aggiorno fs.inotify.max_user_watches a $REQUIRED_WATCHES..."
    echo "fs.inotify.max_user_watches=$REQUIRED_WATCHES" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
else
    echo "Il valore attuale di fs.inotify.max_user_watches ($CURRENT_WATCHES) è già >= $REQUIRED_WATCHES. Nessuna modifica necessaria."
fi

echo "🧰 [1] Aggiornamento pacchetti di sistema..."
eval "$UPDATE_CMD"

# Sezione comune per l'installazione dei pacchetti e configurazione di Laravel
echo "🐘 [2] Installazione PHP + estensioni..."
if [[ "$PM" == "pacman" ]]; then
    # Assicurati che php-intl sia installato esplicitamente
    echo "Installazione/verifica php-intl..."
    if ! pacman -Q php-intl &> /dev/null; then # Usa -Q per il controllo esatto del pacchetto
        echo "Pacchetto php-intl non trovato, installazione in corso..."
        eval "$INSTALL_CMD php-intl" || { echo "Errore critico: Impossibile installare php-intl. Verifica i tuoi repository." ; exit 1; }
        echo "php-intl installato con successo."
    else
        echo "php-intl già installato."
    fi

    # Installa gli altri pacchetti PHP essenziali (se non già presenti)
    eval "$INSTALL_CMD php php-fpm php-gd unzip curl"
    echo "Verifica e abilitazione estensioni PHP in php.ini..."
    # Trova il percorso del php.ini utilizzato dalla CLI
    PHP_INI_PATH=$(php -i | grep "Loaded Configuration File" | awk '{print $NF}')
    if [ -z "$PHP_INI_PATH" ]; then
        echo "Avviso: Impossibile trovare il file php.ini. Tentativo di usare il percorso predefinito."
        PHP_INI_PATH="/etc/php/php.ini" # Percorso comune su Arch
    fi

    # Assicurati che le estensioni siano abilitate scommentando le righe nel php.ini e aggiungendo .so se necessario.
    # LOGICA per pdo_mysql (già risolta)
    sudo sed -i 's/^[;]*extension=pdo_mysql\(.so\)*$/extension=pdo_mysql.so/' "$PHP_INI_PATH" || true
    # LOGICA per intl (già risolta)
    sudo sed -i 's/^[;]*extension=intl\(.so\)*$/extension=intl.so/' "$PHP_INI_PATH" || true
    # NUOVA LOGICA per iconv
    sudo sed -i 's/^[;]*extension=iconv\(.so\)*$/extension=iconv.so/' "$PHP_INI_PATH" || true
    # Altre estensioni (gestite in modo più semplice, si assume siano nel formato corretto con .so)
    sudo sed -i 's/^;extension=mysqli.so/extension=mysqli.so/' "$PHP_INI_PATH" || true
    sudo sed -i 's/^;extension=xml.so/extension=xml.so/' "$PHP_INI_PATH" || true
    echo "Estensioni PHP essenziali (intl, iconv, mysqli, pdo_mysql, xml) abilitate (se presenti e commentate)."


else
    # Pacchetti PHP per Debian/Ubuntu e Fedora/Red Hat
    eval "$INSTALL_CMD php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysqlnd php-intl unzip curl php-dom"
fi

echo "📦 [3] Installazione Composer..."
# Composer è disponibile direttamente nei repository per la maggior parte delle distribuzioni.
# Tenta l'installazione via gestore pacchetti, altrimenti usa lo script curl.
if [[ "$PM" == "pacman" ]]; then
    eval "$INSTALL_CMD composer" || {
        echo "Composer non trovato nei repository Arch, installazione tramite script..."
        curl -sS https://getcomposer.org/installer | php
        sudo mv composer.phar /usr/local/bin/composer
    }
elif ! command -v composer &> /dev/null; then
    echo "Composer non trovato. Installazione tramite script..."
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
else
    echo "Composer già installato."
fi

echo "🖥️ [4] Installazione Git..."
eval "$INSTALL_CMD git"

echo "🔧 [5] Installazione Node.js + NPM..."
if [[ "$PM" == "apt" || "$PM" == "dnf" ]]; then
    eval "$INSTALL_CMD nodejs npm"
    if ! node -v | grep -q "v18"; then
        echo "⚠️ Node.js non è v18 — installo la versione consigliata..."
        if [[ "$PM" == "apt" ]]; then
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            eval "$INSTALL_CMD nodejs"
        elif [[ "$PM" == "dnf" ]]; then
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            eval "$INSTALL_CMD nodejs"
        fi
    fi
elif [[ "$PM" == "pacman" ]]; then
    eval "$INSTALL_CMD nodejs npm"
fi

echo "🗄️ [6] Installazione MySQL Server..."
if [[ "$PM" == "apt" ]]; then
    eval "$INSTALL_CMD mariadb-server"
    sudo systemctl enable --now mysql
elif [[ "$PM" == "dnf" ]]; then
    eval "$INSTALL_CMD mariadb-server" # Su Fedora/Ultramarine è mariadb-server
    sudo systemctl enable --now mariadb
elif [[ "$PM" == "pacman" ]]; then
    eval "$INSTALL_CMD mariadb" # Su Arch è mariadb
    # Inizializza la directory dei dati di MariaDB prima di avviare il servizio
    echo "Inizializzazione della directory dei dati di MariaDB..."
    # Aggiunto '|| true' per ignorare l'errore se già inizializzato, rendendo lo script più robusto a esecuzioni multiple.
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql || true
    sudo systemctl enable --now mariadb
fi

echo "🔑 [7] Configuro database con utente e database Laravel..."
if [[ "$PM" == "pacman" ]]; then
    # Usa il comando 'mariadb' invece di 'mysql' per Arch-based
    sudo mariadb <<EOF
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';
FLUSH PRIVILEGES;
EOF
else
    # Per le altre distribuzioni, continua a usare il comando 'mysql'
    sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';
FLUSH PRIVILEGES;
EOF
fi


echo "🧼 [8] Rimuovo index.html Apache..."
sudo rm -f /var/www/html/index.html || echo "Avviso: index.html di Apache non trovato/rimosso."
echo "📁 [9] Clonazione progetto Laravel..."
# Controlla se la cartella esiste e la elimina con sudo se necessario
if [ -d "$PROJECT_DIR" ]; then
    echo "Rilevata cartella progetto esistente ($PROJECT_DIR). Eliminazione in corso..."
    sudo rm -rf "$PROJECT_DIR"
    echo "Cartella progetto eliminata."
fi
# sudo git clone https://github.com/smal82/laravel-oxylabs-test.git "$PROJECT_DIR"
sudo git clone git@github.com:smal82/laravel-oxylabs-test.git "$PROJECT_DIR"

cd "$PROJECT_DIR"
sudo rm -f "$PROJECT_DIR/setup.sh"
sudo rm -f "$PROJECT_DIR/setup2.sh"

echo "🔐 [10] Imposto permessi su cartella progetto..."
# Imposta i permessi per l'utente corrente che eseguirà php artisan serve
CURRENT_USER=$(whoami)
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$PROJECT_DIR"
sudo chmod -R 775 "$PROJECT_DIR" # Consenti a utente e gruppo (stesso utente) di scrivere

echo "⚠️ Autorizzo directory per Git..."
git config --global --add safe.directory "$PROJECT_DIR"

echo "📦 Installazione dipendenze Laravel..."
# Aggiunto --ignore-platform-reqs per bypassare i controlli delle estensioni PHP di Composer
# se le estensioni sono installate ma Composer non le rileva correttamente.
composer install --no-interaction --ignore-platform-reqs
npm install --yes

echo "🧹 Pulizia cache Laravel..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

if [ ! -f ".env" ]; then
    echo "📝 Creo .env..."
    cp .env.example .env
    php artisan key:generate
else
    echo "✅ File .env già presente"
fi

echo "✏️ Aggiorno configurazione MySQL in .env..."
if [[ "$PM" == "pacman" ]]; then
    # Su Arch, usa mariadb come DB_CONNECTION
    sed -i '/DB_CONNECTION=/c\DB_CONNECTION=mariadb' .env
    echo "Configurazione .env per MariaDB (Arch-based)."
else
    # Per le altre distribuzioni, usa mysql
    sed -i '/DB_CONNECTION=/c\DB_CONNECTION=mysql' .env
    echo "Configurazione .env per MySQL."
fi

# Forzare DB_HOST a 127.0.0.1 per evitare ambiguità con localhost
sed -i '/DB_HOST=/c\DB_HOST=127.0.0.1' .env
sed -i '/DB_PORT=/c\DB_PORT=3306' .env
sed -i '/DB_DATABASE=/c\DB_DATABASE=laravel_oxylabs_test_database' .env
sed -i '/DB_USERNAME=/c\DB_USERNAME=laravel_oxylabs_test_user' .env
sed -i '/DB_PASSWORD=/c\DB_PASSWORD=kA[Q+LgF-~1C' .env

echo "📦 Migrazione + storage link..."
php artisan migrate --force
php artisan storage:link

echo "🧹 Pulizia finale Laravel..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

echo "🎛️ Installazione Filament..."
php artisan filament:install --panels
composer dump-autoload
php artisan optimize:clear

echo "👤 Creo utente admin..."
php artisan make:filament-user

echo "🔄 Sostituisco AdminPanelProvider.php..."
mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak
mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php
composer dump-autoload
php artisan optimize:clear

echo "🧩 Installo DomCrawler Symfony..."
composer require symfony/dom-crawler --no-interaction

echo "📦 Importo prodotti..."
php artisan import:products || echo "⚠️ Import fallita"

echo "🕰️ Configuro cron..."
if ! command -v crontab &> /dev/null; then
    echo "Installazione di cronie..."
    if [[ "$PM" == "pacman" ]]; then
        eval "$INSTALL_CMD cronie"
        sudo systemctl enable --now cronie.service # Su Arch è cronie.service
    else
        # Per Debian/Ubuntu e Fedora/Ultramarine
        eval "$INSTALL_CMD cronie" # O nome equivalente del pacchetto cron
        sudo systemctl enable --now cronie || sudo systemctl enable --now crond # Tenta cronie o crond
    fi
else
    echo "Cronie (crontab) già installato."
fi
croncmd="* * * * * cd $PROJECT_DIR && php artisan schedule:run >> /dev/null 2>&1"
( crontab -l 2>/dev/null | grep -v -F "$croncmd" ; echo "$croncmd" ) | crontab -

echo "🎨 Compilo frontend..."
nohup npm run dev > storage/logs/dev.log 2>&1 &

echo "🚀 Avvio Laravel..."
nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &
nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &

echo ""
echo "✅ Setup completato su $DISTRO!"
echo "🔒 Admin → http://127.0.0.1:8000/admin/login"
echo "🛒 Frontend → http://127.0.0.1:8000/view/products"
echo ""




