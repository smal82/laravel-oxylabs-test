#!/bin/bash

# Gestione del file di log: Elimina il log precedente all'avvio
LOGFILE="setup.log"
rm -f "$LOGFILE" || true # Elimina il file di log, ignorando errori se non esiste

# Abilita la modalità "fail-fast": lo script si interrompe al primo comando fallito.
set -e
# Reindirizza stdout e stderr sia alla console che al file di log.
exec > >(tee -a "$LOGFILE") 2>&1

echo "📋 Avvio script multipiattaforme - $(date)"

# Definisci il percorso del progetto Laravel.
PROJECT_DIR="/var/www/html/laravel-oxylabs-test"

echo  "ℹ️ Rileva il nome esatto della distribuzione."
if [ -f "/etc/mx-version" ]; then
    DISTRO="MX Linux"
else
    # Fallback per altre distribuzioni
    DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
fi

# 🔍 Rileva il gestore di pacchetti e imposta le variabili di conseguenza.
# Questo metodo non si basa sul nome della distribuzione, ma sull'esistenza del comando.
if command -v apt &> /dev/null; then
    PM="apt"
    UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
    INSTALL_CMD="sudo apt install -y"
    WEBSERVER_GROUP="www-data"
elif command -v dnf &> /dev/null; then
    PM="dnf"
    UPDATE_CMD="sudo dnf upgrade --refresh -y"
    INSTALL_CMD="sudo dnf install -y"
    WEBSERVER_GROUP="apache"
elif command -v pacman &> /dev/null; then
    PM="pacman"
    UPDATE_CMD="sudo pacman -Syu --noconfirm --disable-download-timeout"
    INSTALL_CMD="sudo pacman -S --noconfirm --needed"
    WEBSERVER_GROUP="http"
elif command -v zypper &> /dev/null; then
    PM="zypper"
    UPDATE_CMD="sudo zypper refresh && sudo zypper update -y"
    INSTALL_CMD="sudo zypper install -y"
    WEBSERVER_GROUP="wwwrun"
elif command -v pkg &> /dev/null; then
    PM="pkg"
    UPDATE_CMD="sudo pkg update -f && sudo pkg upgrade -y"
    INSTALL_CMD="sudo pkg install -y"
    WEBSERVER_GROUP="www"  # valore comune nei BSD, ma può variare
else
    # Se nessun gestore di pacchetti supportato è stato trovato, esci.
    echo "🚫 Nessun gestore di pacchetti supportato (apt, dnf, pacman, zypper, pkg) è stato trovato."
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
if [[ "$DISTRO" == "neon" ]]; then
sudo apt-get update && sudo pkcon update -y
else
eval "$UPDATE_CMD"
fi

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
elif [[ "$PM" == "zypper" ]]; then
    PHP_VERSION="8"
    REQUIRED_PKGS=(
        "php$PHP_VERSION"
        "php$PHP_VERSION-cli"
        "php$PHP_VERSION-mbstring"
        "php$PHP_VERSION-bcmath"
        "php$PHP_VERSION-curl"
        "php$PHP_VERSION-zip"
        "php$PHP_VERSION-mysql"
        "php$PHP_VERSION-intl"
        "php$PHP_VERSION-dom"
        "php$PHP_VERSION-phar"
        "unzip"
        "curl"
    )

    for pkg in "${REQUIRED_PKGS[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            echo "✅ $pkg già installato."
        else
            echo "📦 Installazione $pkg..."
            sudo zypper install -y "$pkg" || {
                echo "❌ Errore nell’installazione di $pkg — controlla i repository."
                exit 1
            }
        fi
    done
else
    # Pacchetti PHP per Debian/Ubuntu e Fedora/Red Hat
    eval "$INSTALL_CMD php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysqlnd php-intl unzip curl php-dom"
fi

echo "📦 [3] Installazione Composer..."

if [[ "$PM" == "zypper" ]]; then
    # OpenSUSE: Composer è nel pacchetto php-composer (a seconda della versione di PHP)
    PHP_VERSION="8"  # o imposta dinamicamente se vuoi
    eval "$INSTALL_CMD php$PHP_VERSION-composer" || {
        echo "⚠️ Installazione tramite pacchetto fallita. Provo con lo script ufficiale..."
        PHP_BIN=$(command -v php$PHP_VERSION)
        if [[ -z "$PHP_BIN" ]]; then
            echo "🚫 PHP non trovato. Impossibile installare Composer."
            exit 1
        fi
        curl -sS https://getcomposer.org/installer | "$PHP_BIN"
        sudo mv composer.phar /usr/local/bin/composer
    }

elif [[ "$PM" == "pacman" ]]; then
    # Arch Linux: composer è nei repo ufficiali
    eval "$INSTALL_CMD composer" || {
        echo "⚠️ Composer non trovato nei repository Arch, installazione tramite script..."
        PHP_BIN=$(command -v php)
        if [[ -z "$PHP_BIN" ]]; then
            echo "🚫 PHP non trovato. Impossibile installare Composer."
            exit 1
        fi
        curl -sS https://getcomposer.org/installer | "$PHP_BIN"
        sudo mv composer.phar /usr/local/bin/composer
    }

else
    # Altre distro (Debian, Fedora, BSD...) → fallback con script
    if ! command -v composer &> /dev/null; then
        echo "Composer non trovato. Installazione tramite script..."
        PHP_BIN=$(command -v php || command -v php8 || command -v php82 || command -v php81)
        if [[ -z "$PHP_BIN" ]]; then
            echo "🚫 PHP non trovato. Impossibile installare Composer."
            exit 1
        fi
        curl -sS https://getcomposer.org/installer | "$PHP_BIN"
        sudo mv composer.phar /usr/local/bin/composer
    else
        echo "Composer già installato."
    fi
fi


echo "🖥️ [4] Installazione Git..."
eval "$INSTALL_CMD git"

echo "🔧 [5] Installazione Node.js + NPM..."

if [[ "$PM" == "apt" || "$PM" == "zypper" ]]; then
    echo "📦 Installazione nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"

    echo "📥 Installazione Node.js v18..."
    nvm install 18
    nvm use 18

elif [[ "$PM" == "dnf" ]]; then
    echo "📦 Installazione tramite DNF..."

    if command -v node &> /dev/null; then
        CURRENT_NODE_VERSION=$(node -v)
        echo "➡️ Versione rilevata: $CURRENT_NODE_VERSION"

        if ! echo "$CURRENT_NODE_VERSION" | grep -q "v18"; then
            echo "🧹 Rimozione Node.js incompatibile..."
            sudo dnf remove -y nodejs nodejs-full-i18n || echo "⚠️ Errore durante la rimozione."
        else
            echo "✅ Node.js v18 già presente. Salto rimozione."
        fi
    else
        echo "🚫 Node.js non rilevato."
    fi

    if ! command -v node &> /dev/null || ! node -v | grep -q "v18"; then
        echo "🌐 Configuro repo Nodesource..."
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo dnf install -y nodejs --allowerasing
        echo "✅ Node.js v18 installato: $(node -v)"
    fi

    if ! command -v npm &> /dev/null; then
        echo "📦 NPM non rilevato — installo manualmente..."
        sudo dnf install -y npm || echo "❌ Impossibile installare NPM."
    fi

elif [[ "$PM" == "pacman" ]]; then
    echo "📦 Installazione tramite Pacman..."

    if ! command -v node &> /dev/null || ! node -v | grep -q "v18"; then
        echo "⚠️ Node.js v18 non trovato — installo..."
        eval "$INSTALL_CMD nodejs npm"
    else
        echo "✅ Node.js v18 già presente. Salto installazione."
    fi

    if ! command -v npm &> /dev/null; then
        echo "📦 NPM non rilevato — installo manualmente..."
        eval "$INSTALL_CMD npm"
    fi

else
    echo "⚠️ Gestore di pacchetti non riconosciuto: '$PM' — salto installazione."
fi

# Verifica finale
echo "🔍 Verifica finale..."
command -v node &> /dev/null && echo "✅ Node.js: $(node -v)" || echo "❌ Node.js non disponibile"
command -v npm &> /dev/null && echo "✅ NPM: $(npm -v)" || echo "❌ NPM non disponibile"

echo "🗄️ [6] Installazione MySQL Server..."
if [[ "$PM" == "apt" ]]; then
    eval "$INSTALL_CMD mariadb-server"
    if [[ "$DISTRO" == "MX Linux" ]]; then
        if ! sudo service mariadb status >/dev/null 2>&1; then
            echo "Il servizio mariadb non è attivo. Avvio e abilitazione..."
            sudo service mariadb start
            sudo update-rc.d mysql enable
        else
            echo "Il servizio mariadb è già in esecuzione. Ignoro l'avvio."
        fi
    else
        sudo systemctl enable --now mysql
    fi

elif [[ "$PM" == "dnf" ]]; then
    eval "$INSTALL_CMD mariadb-server"
    sudo systemctl enable --now mariadb

elif [[ "$PM" == "pacman" ]]; then
    eval "$INSTALL_CMD mariadb"
    echo "Inizializzazione della directory dei dati di MariaDB..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql || true
    sudo systemctl enable --now mariadb

elif [[ "$PM" == "zypper" ]]; then
    eval "$INSTALL_CMD mariadb mariadb-tools"
    echo "Inizializzazione della directory dei dati di MariaDB..."
    sudo systemctl enable --now mariadb
    sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql || true
fi

echo "🧹 Eseguo pulizia dei pacchetti di sistema..."
if [[ "$PM" == "apt" || "$PM" == "dnf" || "$PM" == "zypper" ]]; then
    sudo "$PM" autoremove -y || true
elif [[ "$PM" == "pacman" ]]; then
    set +e
    ORPHANS=$(pacman -Qdtq)
    if [ -n "$ORPHANS" ]; then
        echo "Trovati pacchetti orfani da rimuovere: $ORPHANS"
        sudo pacman -Rns $ORPHANS --noconfirm
    else
        echo "Nessun pacchetto orfano da rimuovere."
    fi
    set -e
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
sudo git clone https://github.com/smal82/laravel-oxylabs-test.git "$PROJECT_DIR"
# sudo git clone git@github.com:smal82/laravel-oxylabs-test.git "$PROJECT_DIR"

cd "$PROJECT_DIR"
sudo rm -f "$PROJECT_DIR/setup.sh"
sudo rm -f "$PROJECT_DIR/setup2.sh"

echo "🔐 [10] Imposto permessi su cartella progetto..."
# Imposta i permessi per l'utente corrente che eseguirà php artisan serve
if [[ "$PM" == "zypper" ]]; then
# Definisce l'utente corrente
CURRENT_USER=$(whoami)
# Inizializza la variabile per il gruppo del server web
WEBSERVER_GROUP_FOUND=""

# Cerca il gruppo corretto del server web
for group_name in wwwrun www-data apache; do
    if getent group "$group_name" &> /dev/null; then
        WEBSERVER_GROUP_FOUND="$group_name"
        break
    fi
done

if [ -n "$WEBSERVER_GROUP_FOUND" ]; then
    echo "✅ Gruppo del server web '$WEBSERVER_GROUP_FOUND' trovato."
    # Aggiungo l'utente corrente al gruppo del server web se non ne fa già parte
    if ! groups "$CURRENT_USER" | grep -q "\b$WEBSERVER_GROUP_FOUND\b"; then
        echo "➕ Aggiungo l'utente '$CURRENT_USER' al gruppo '$WEBSERVER_GROUP_FOUND'..."
        sudo usermod -a -G "$WEBSERVER_GROUP_FOUND" "$CURRENT_USER"
        echo "❗ Per rendere effettivo il cambiamento, esegui 'newgrp $WEBSERVER_GROUP_FOUND' o riavvia il terminale."
    else
        echo "✅ L'utente '$CURRENT_USER' è già membro del gruppo '$WEBSERVER_GROUP_FOUND'."
    fi
    # Imposto l'utente e il gruppo del server web come proprietari della directory
    sudo chown -R "$CURRENT_USER":"$WEBSERVER_GROUP_FOUND" "$PROJECT_DIR"
else
    echo "⚠️ Avviso: Nessun gruppo comune del server web (wwwrun, www-data, apache) è stato trovato."
    # Imposto il gruppo su "users" come fallback
    FALLBACK_GROUP="users"
    if getent group "$FALLBACK_GROUP" &> /dev/null; then
        echo "✅ Gruppo di fallback '$FALLBACK_GROUP' trovato. Assegno la proprietà all'utente e a questo gruppo."
        sudo chown -R "$CURRENT_USER":"$FALLBACK_GROUP" "$PROJECT_DIR"
    else
        echo "❌ Errore: Anche il gruppo di fallback 'users' non è stato trovato. Assegno la proprietà solo all'utente."
        sudo chown -R "$CURRENT_USER" "$PROJECT_DIR"
    fi
fi

sudo chmod -R 775 "$PROJECT_DIR" # Consenti a utente e gruppo di leggere, scrivere ed eseguire
else
CURRENT_USER=$(whoami)
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$PROJECT_DIR"
sudo chmod -R 775 "$PROJECT_DIR" # Consenti a utente e gruppo (stesso utente) di scrivere
fi

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
    echo "Configurazione .env per MariaDB."
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
if [[ "$PM" == "zypper" ]]; then
    echo "🧩 Controllo e installazione php8-fileinfo..."
    
    if ! php -m | grep -iq fileinfo; then
        sudo zypper install -y php8-fileinfo

        # Verifica post-installazione
        if php -m | grep -iq fileinfo; then
            echo "✅ Estensione fileinfo abilitata."
        else
            echo "❌ Estensione fileinfo ancora non attiva dopo l'installazione. Controlla a mano."
            exit 1
        fi
    else
        echo "✅ fileinfo già attiva."
    fi
fi

composer require symfony/dom-crawler --no-interaction

echo "📦 Importo prodotti..."
php artisan import:products || echo "⚠️ Import fallita"

echo "🕰️ Configuro cron..."
if ! command -v crontab &> /dev/null; then
    echo "Installazione di cronie..."
    if [[ "$PM" == "pacman" ]]; then
        eval "$INSTALL_CMD cronie"
        sudo systemctl enable --now cronie.service
    elif [[ "$PM" == "zypper" ]]; then
        eval "$INSTALL_CMD cron"
        sudo systemctl enable --now cron.service
    else
        eval "$INSTALL_CMD cronie"
        # Fedora / Debian / Ubuntu tipicamente hanno cronie.service o crond.service
        sudo systemctl enable --now cronie.service || sudo systemctl enable --now crond.service
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
