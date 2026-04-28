json.payload do
  json.array! @items do |item|
    json.partial! 'api/v1/accounts/kanban/items/partials/item', formats: [:json], item: item
  end
end
