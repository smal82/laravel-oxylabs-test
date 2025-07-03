<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Programmazione automatica dei comandi Artisan.
     */
    protected function schedule(Schedule $schedule): void
    {
        // Esegui l'importazione ogni 10 minuti
        $schedule->command('import:products')->everyTenMinutes();
    }

    /**
     * Registra tutti i comandi custom da app/Console/Commands.
     */
    protected function commands(): void
    {
        $this->load(__DIR__ . '/Commands');

        require base_path('routes/console.php');
    }
}
