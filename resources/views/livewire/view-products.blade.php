<div class="p-6 max-w-7xl mx-auto">
    <h1 class="text-3xl font-bold mb-6">🕹️ I tuoi giochi</h1>

    <div class="mb-4 flex gap-4">
        <button wire:click="sortBy('title')" class="text-blue-600 underline">Ordina per Titolo</button>
        <button wire:click="sortBy('price')" class="text-blue-600 underline">Ordina per Prezzo</button>
        <button wire:click="sortBy('created_at')" class="text-blue-600 underline">Ordina per Data</button>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
        @forelse ($products as $product)
            <div class="border rounded-lg p-4 shadow hover:shadow-lg transition">
                <h2 class="text-xl font-semibold mb-2">{{ $product->title }}</h2>
                <p class="text-sm text-gray-600 mb-2">{{ $product->category }}</p>
                <p class="text-lg font-bold text-green-600 mb-2">€ {{ number_format($product->price, 2) }}</p>                
                <p class="text-sm mt-2 line-clamp-3">{{ $product->description }}</p>
            </div>
        @empty
            <p>Nessun prodotto trovato.</p>
        @endforelse
    </div>

    <div class="mt-6">
        {{ $products->links() }}
    </div>
</div>

