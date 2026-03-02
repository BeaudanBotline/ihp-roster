-- Default venue for development
INSERT INTO venues (id, name, status) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Dev Venue', 'active');

-- Venue config (one per venue)
INSERT INTO venue_config (venue_id, timezone, week_offset_epoch, late_to_early_min_start_gap_minutes)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'UTC', DATE '2025-01-06', 600);

-- Pay Levels
INSERT INTO pay_levels (id, venue_id, name, is_active) VALUES
('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Standard Level 1', true),
('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Supervisor Level 2', true);

-- Shift Types
INSERT INTO shift_types (id, venue_id, name, default_pay_level_id, is_active) VALUES
('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Ordinary', '11111111-1111-1111-1111-111111111111', true),
('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Management', '22222222-2222-2222-2222-222222222222', true);

-- Slot Names
INSERT INTO slot_names (id, venue_id, name, is_active) VALUES
('55555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Early', true),
('66666666-6666-6666-6666-666666666666', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Mid', true),
('77777777-7777-7777-7777-777777777777', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Late', true);
