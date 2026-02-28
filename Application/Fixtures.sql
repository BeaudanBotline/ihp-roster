INSERT INTO venue_config (is_singleton, timezone, week_offset_epoch, late_to_early_min_start_gap_minutes)
VALUES (TRUE, 'UTC', DATE '2025-01-06', 600);

-- Pay Levels
INSERT INTO pay_levels (id, name, is_active) VALUES
('11111111-1111-1111-1111-111111111111', 'Standard Level 1', true),
('22222222-2222-2222-2222-222222222222', 'Supervisor Level 2', true);

-- Shift Types
INSERT INTO shift_types (id, name, default_pay_level_id, is_active) VALUES
('33333333-3333-3333-3333-333333333333', 'Ordinary', '11111111-1111-1111-1111-111111111111', true),
('44444444-4444-4444-4444-444444444444', 'Management', '22222222-2222-2222-2222-222222222222', true);

-- Slot Names
INSERT INTO slot_names (id, name, is_active) VALUES
('55555555-5555-5555-5555-555555555555', 'Early', true),
('66666666-6666-6666-6666-666666666666', 'Mid', true),
('77777777-7777-7777-7777-777777777777', 'Late', true);

