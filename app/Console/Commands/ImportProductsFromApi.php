<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;
use Symfony\Component\DomCrawler\Crawler;
use App\Models\Product;

class ImportProductsFromApi extends Command
{
    protected $signature = 'import:products';
    protected $description = 'Importa prodotti da Oxylabs nel DB, parsing HTML';

    public function handle()
    {
        $this->info('⏳ Importazione prodotti da Oxylabs in corso...');

        $response = Http::get('https://sandbox.oxylabs.io/products');

        if ($response->failed()) {
            $this->error('❌ Errore nella richiesta HTTP');
            return 1;
        }

        $html = $response->body();
        $crawler = new Crawler($html);

  $crawler->filter('.product-card')->each(function ($node) {
    $title = $node->filter('h4.title')->count() ? $node->filter('h4.title')->text() : 'Titolo sconosciuto';
    $priceRaw = $node->filter('.price-wrapper')->count() ? $node->filter('.price-wrapper')->text() : '0.00';
    $price = (float) str_replace([',', '€', ' '], ['.', '', ''], $priceRaw);
    $imageUrl = $node->filter('img.image')->count() ? $node->filter('img.image')->attr('src') : null;
    $description = $node->filter('p.description')->count() ? $node->filter('p.description')->text() : null;

    $categories = $node->filter('p.category span')->each(function ($cat) {
        return trim($cat->text());
    });
    $category = implode(', ', $categories);

    $availability = $node->filter('p.in-stock, p.out-of-stock')->count()
        ? $node->filter('p.in-stock, p.out-of-stock')->text()
        : 'Unknown';

    Product::updateOrCreate(
        ['title' => $title],
        [
            'price' => $price,
            'category' => $category,
            'description' => $description,
            'image_url' => $imageUrl,
        ]
    );
});


        $this->info('✅ Importazione completata con successo');
    }
}
