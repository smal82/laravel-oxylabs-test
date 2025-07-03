<?php

namespace App\Jobs;

use App\Models\Product;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ImportProductsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle(): void
    {
        $products = json_decode(file_get_contents(base_path('products.json')), true);

        foreach ($products as $index => $data) {
    try {
        $product = Product::create([
            'title' => $data['title'],
            'price' => self::normalizePrice($data['price']),
            'description' => $data['description'],
            'category' => $data['category'],
        ]);

        $product->image()->create([
            'url' => $data['image_url'],
        ]);

        \Log::info("✅ Prodotto #{$index} importato: {$data['title']}");
    } catch (\Throwable $e) {
        \Log::error("❌ Errore nel prodotto #{$index}: {$data['title']}");
        \Log::error($e->getMessage());
    }
}

    }
    private static function normalizePrice(string $price): float
{
    // Rimuove spazi, simboli €, ecc.
    $clean = str_replace(['€', ' ', ','], ['', '', '.'], $price);

    // Lascia solo cifre e punto decimale
    $clean = preg_replace('/[^\d.]/', '', $clean);

    return (float) $clean;
}

}

