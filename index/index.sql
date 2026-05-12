CREATE INDEX idx_inventory_product_variant_id_cover
    ON inventory (product_variant_id)
    INCLUDE (quantity, reserved_quantity);
drop index idx_inventory_product_variant_id_cover;

CREATE INDEX idx_im_inventory_transactions_id
    ON inventory_movements (inventory_transactions_id);
drop index idx_im_inventory_transactions_id;

CREATE INDEX idx_im_created_at
    ON inventory_movements (created_at);
drop index idx_im_created_at;

ANALYZE inventory_transactions;
ANALYZE inventory_movements;
ANALYZE inventory;