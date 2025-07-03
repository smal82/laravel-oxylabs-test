<?php
namespace App\Livewire;

use App\Models\Product;
use Livewire\Component;
use Livewire\WithPagination;

class ViewProducts extends Component
{
    use WithPagination;

    public string $sort = 'created_at';
    public string $direction = 'desc';

    public function sortBy($field)
    {
        if ($this->sort === $field) {
            $this->direction = $this->direction === 'asc' ? 'desc' : 'asc';
        } else {
            $this->sort = $field;
            $this->direction = 'asc';
        }
    }

    public function render()
{
    return view('livewire.view-products', [
        'products' => \App\Models\Product::orderBy($this->sort, $this->direction)->paginate(25),
    ]);
}


}

