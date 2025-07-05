
![Laravel](https://img.shields.io/badge/Laravel-10.0-red.svg)
![Filament](https://img.shields.io/badge/Filament-Admin-blue.svg)
![Livewire](https://img.shields.io/badge/Livewire-Ready-green.svg)
![TailwindCSS](https://img.shields.io/badge/TailwindCSS-3.x-teal.svg)

# 🧪 Prova Tecnica – Backend & Frontend Laravel | Oxylabs

Questo progetto è una prova tecnica sviluppata in **Laravel 10+**, con focus su:
- 🧱 scraping e importazione asincrona da API esterna
- 🧑‍💻 pannello admin con Filament
- ⚡ frontend dinamico con Livewire, AlpineJS e TailwindCSS

## 🧠 Obiettivo del progetto

- Estrarre dati da `https://sandbox.oxylabs.io/products`
- Importare prodotti nel database con un **Job asincrono**
- Gestire i dati tramite **Filament Admin**
- Visualizzare i prodotti pubblicamente con frontend dinamico

## Funzionalità disponibili:

- visualizzazione prodotti
- modifica ed eliminazione
- sorting e ricerca

## ⚙️ Installazione da zero ( Linux)

### ✅ Requisiti

I seguenti requisiti non devono essere presenti sul sistema, in quanto nella repository è presente il file setup.sh per Linux della famiglia di Debian, che installa tutto,

| Tool         | Versione consigliata |
|--------------|----------------------|
| PHP          | ≥ 8.2                |
| Composer     | ≥ 2.5                |
| Node.js      | ≥ 18.x               |
| NPM          | ≥ 9.x                |
| Git          | Per clonare la repo |
| MySQL / SQLite | Qualsiasi compatibile |
| Laravel CLI  | (opzionale)          |

### 📦 Setup automatizzato

Per scaricare il file setup.sh, apritelo e in alto a destra trovate i ... e cliccandoci trovate il link di Download.

Dopo averlo scaricato da terminale recatevi nella cartella in cui avete scaricato il file e vi basta dare i seguenti comandi:
```BASH
chmod +x setup.sh
.\setup.sh
```
oppure se non funziona e da errori con
```BASH
bash setup.sh
```
All'interno del terminale vi chiederà la password del vostro utente e avvierà l'intallazione di tutto:
- Per prima cosa aggiorna il sistema, poi installa:
- PHP + estensioni, Composer, GIT, Node.js + NPM, MySQL Server (per MySQL viene settata la password generica "123456" per l'utente root).

A questo punto viene clonata questa repo e inizia la configurazione di tutto il sistema:
- Viene creato il db laravel_database;
- Vengono installati Laravel e le sue dipendeze;
- Viene configurato il file .env con i parametri di connessione al DB e viene eseguita la migrazione e storage link;
- Viene installato Filament e configurato; a tal proposito viene chiesto l'id, che di defualt è admin, ed io consiglio di lasciare admin;
- Viene creato l'utente con il quale effettuare il login nel pannello di controllo;
- Viene installa DomCrawler Symfony utile per effettuare il crawling del sito https://sandbox.oxylabs.io/products e memorizzare i prodotti nel nostro DB;
- Viene settato un cron per poter tenere aggiornato il db con i prodotti del sito.

A questo punto vengono avviati: i servizi di Laravel, il Server di Laravel, il worker Laravel per un job async ed il setup è completo.

Se è andato tutto a buon fine il sito è possibile visitarlo dal link: http://127.0.0.1:8000/view/products
Mentre il login nel pannello di amministrazione è: http://127.0.0.1:8000/admin/login

## 👨‍💻 Autore e info utili

| Dettaglio            | Info                                  |
|----------------------|----------------------------------------|
| 👤 Sviluppatore       | [@smal82](https://github.com/smal82)   |
| 📅 Data progetto      | Luglio 2025                            |
| 🔧 Stack tecnologico  | Laravel, Filament, Livewire, AlpineJS, TailwindCSS |
---

## 🚧 Stato del progetto

🧪 In fase di verifica finale e ottimizzazione per deploy

## 📬 Contatti

Per feedback, domande o collaborazione:  
📫 [GitHub – smal82](https://github.com/smal82)

## 💡 Note extra

- Backend pronto per estensione in ambienti di produzione
- Codebase pulita e modulare
- Frontend personalizzabile con filtri, badge, categorie o ricerca live
