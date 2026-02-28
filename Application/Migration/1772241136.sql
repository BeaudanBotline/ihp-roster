ALTER TABLE roster_slots DROP COLUMN IF EXISTS shift_type_id;
ALTER TABLE roster_slots ALTER COLUMN start_time DROP NOT NULL;
ALTER TABLE roster_slots ADD COLUMN IF NOT EXISTS row_index INT;
UPDATE roster_slots SET row_index = 0 WHERE row_index IS NULL;
ALTER TABLE roster_slots ALTER COLUMN row_index SET NOT NULL;
ALTER TABLE roster_slots ADD COLUMN IF NOT EXISTS note TEXT;
