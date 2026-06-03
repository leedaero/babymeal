ALTER TABLE ingredients
  ADD COLUMN unit_type VARCHAR(10) NOT NULL DEFAULT 'weight',
  MODIFY COLUMN weight_per_cube INT DEFAULT NULL;
