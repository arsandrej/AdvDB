INSERT INTO TRANSACTION_TYPES (code, description)
VALUES ('RECEIPT', 'Initial receipt of goods from a supplier'),
       ('SHIPMENT', 'Goods shipped out to a customer or destination'),
       ('TRANSFER', 'Internal movement of goods between bins')
ON CONFLICT (code) DO NOTHING;