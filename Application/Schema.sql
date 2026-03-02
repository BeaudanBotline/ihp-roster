-- Your database schema. Use the Schema Designer at http://localhost:8001/ to add some tables.
CREATE TABLE users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    user_role TEXT DEFAULT 'staff' NOT NULL,
    is_profile_completed BOOLEAN DEFAULT FALSE NOT NULL,
    locked_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    failed_login_attempts INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE TABLE staff (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    user_id UUID,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    ideal_shifts_per_week INT DEFAULT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
);
CREATE TABLE pay_levels (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE TABLE shift_types (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    default_pay_level_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    FOREIGN KEY (default_pay_level_id) REFERENCES pay_levels (id) ON DELETE RESTRICT
);
CREATE TABLE slot_names (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE TABLE day_names (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    weekday_index INT NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(weekday_index)
);
CREATE TABLE pay_level_day_rules (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    pay_level_id UUID NOT NULL,
    day_name_id UUID NOT NULL,
    multiplier NUMERIC(6,3) DEFAULT 1.0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(pay_level_id, day_name_id),
    FOREIGN KEY (pay_level_id) REFERENCES pay_levels (id) ON DELETE CASCADE,
    FOREIGN KEY (day_name_id) REFERENCES day_names (id) ON DELETE RESTRICT
);
CREATE TABLE venue_config (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    is_singleton BOOLEAN DEFAULT TRUE NOT NULL,
    timezone TEXT NOT NULL,
    week_offset_epoch DATE NOT NULL,
    late_to_early_min_start_gap_minutes INT DEFAULT 0 NOT NULL,
    staff_timesheet_edit_window_days INT DEFAULT 7 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(is_singleton)
);
CREATE TABLE roster_weeks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    week_offset INT NOT NULL,
    is_live BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(week_offset)
);
CREATE TABLE roster_days (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    roster_week_id UUID NOT NULL,
    day_offset INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(roster_week_id, day_offset),
    FOREIGN KEY (roster_week_id) REFERENCES roster_weeks (id) ON DELETE CASCADE
);
CREATE TABLE roster_slots (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    roster_day_id UUID NOT NULL,
    staff_id UUID,
    slot_name_id UUID NOT NULL,
    row_index INT NOT NULL,
    start_time TIME,
    duration_minutes INT,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    FOREIGN KEY (roster_day_id) REFERENCES roster_days (id) ON DELETE CASCADE,
    FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE SET NULL,
    FOREIGN KEY (slot_name_id) REFERENCES slot_names (id) ON DELETE RESTRICT
);
CREATE TABLE staff_availability (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    staff_id UUID NOT NULL,
    weekday_index INT,
    specific_date DATE,
    is_available BOOLEAN NOT NULL,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
);
CREATE TABLE leave_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    staff_id UUID NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT DEFAULT 'pending' NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
);
CREATE TABLE timesheet_entries (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    staff_id UUID NOT NULL,
    worked_on DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    break_minutes INT DEFAULT 0 NOT NULL,
    is_approved BOOLEAN DEFAULT FALSE NOT NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by_user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE,
    FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE OR REPLACE FUNCTION resolve_effective_pay_level(p_staff_id UUID, p_shift_type_id UUID, p_day_of_week INT)
RETURNS UUID
AS $$
    SELECT
        COALESCE(
            (
                SELECT st.default_pay_level_id
                FROM shift_types st
                JOIN pay_level_day_rules pldr ON pldr.pay_level_id = st.default_pay_level_id
                JOIN day_names dn ON dn.id = pldr.day_name_id
                WHERE st.id = p_shift_type_id
                    AND dn.weekday_index = p_day_of_week
                LIMIT 1
            ),
            (
                SELECT st.default_pay_level_id
                FROM shift_types st
                WHERE st.id = p_shift_type_id
                LIMIT 1
            )
        );
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION calculate_timesheet_pay(p_entry_id UUID)
RETURNS JSONB
AS $$
    WITH entry_data AS (
        SELECT te.*
        FROM timesheet_entries te
        WHERE te.id = p_entry_id
        LIMIT 1
    ),
    first_shift_type AS (
        SELECT st.id AS shift_type_id
        FROM shift_types st
        WHERE st.is_active = TRUE
        ORDER BY st.created_at ASC, st.id ASC
        LIMIT 1
    ),
    resolved AS (
        SELECT
            e.id,
            e.staff_id,
            e.worked_on,
            e.start_time,
            e.end_time,
            e.break_minutes,
            GREATEST((EXTRACT(EPOCH FROM (e.end_time - e.start_time)) / 60)::INT - e.break_minutes, 0) AS paid_minutes,
            resolve_effective_pay_level(
                e.staff_id,
                (SELECT shift_type_id FROM first_shift_type),
                EXTRACT(DOW FROM e.worked_on)::INT
            ) AS pay_level_id
        FROM entry_data e
    ),
    payload AS (
        SELECT jsonb_build_object(
            'entryId', r.id,
            'staffId', r.staff_id,
            'workedOn', r.worked_on,
            'breakMinutes', r.break_minutes,
            'paidMinutes', r.paid_minutes,
            'segments', jsonb_build_array(
                jsonb_build_object(
                    'segment', 'whole_shift',
                    'minutes', r.paid_minutes,
                    'payLevelId', r.pay_level_id,
                    'multiplier', COALESCE((
                        SELECT pldr.multiplier
                        FROM pay_level_day_rules pldr
                        JOIN day_names dn ON dn.id = pldr.day_name_id
                        WHERE pldr.pay_level_id = r.pay_level_id
                            AND dn.weekday_index = EXTRACT(DOW FROM r.worked_on)::INT
                        LIMIT 1
                    ), 1.0),
                    'baseRate', 0,
                    'amount', 0
                )
            ),
            'totals', jsonb_build_object(
                'paidMinutes', r.paid_minutes,
                'totalAmount', 0
            )
        ) AS pay_json
        FROM resolved r
    )
    SELECT COALESCE(
        (SELECT pay_json FROM payload),
        jsonb_build_object(
            'entryId', p_entry_id,
            'error', 'timesheet_entry_not_found',
            'segments', jsonb_build_array(),
            'totals', jsonb_build_object('paidMinutes', 0, 'totalAmount', 0)
        )
    );
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION calculate_timesheet_pay_range(p_staff_id UUID, p_from_date DATE, p_to_date DATE)
RETURNS JSONB
AS $$
    SELECT COALESCE(
        jsonb_agg(calculate_timesheet_pay(te.id) ORDER BY te.worked_on ASC, te.id ASC),
        jsonb_build_array()
    )
    FROM timesheet_entries te
    WHERE te.staff_id = p_staff_id
        AND te.worked_on >= p_from_date
        AND te.worked_on <= p_to_date;
$$ LANGUAGE SQL;
