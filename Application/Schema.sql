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
    CONSTRAINT staff_user_id_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
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
    CONSTRAINT shift_types_default_pay_level_id_fk FOREIGN KEY (default_pay_level_id) REFERENCES pay_levels (id) ON DELETE RESTRICT
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
    CONSTRAINT day_names_weekday_index_unique UNIQUE (weekday_index)
);

CREATE TABLE pay_level_day_rules (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    pay_level_id UUID NOT NULL,
    day_name_id UUID NOT NULL,
    multiplier NUMERIC(6, 3) DEFAULT 1.000 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT pay_level_day_rules_unique UNIQUE (pay_level_id, day_name_id),
    CONSTRAINT pay_level_day_rules_pay_level_id_fk FOREIGN KEY (pay_level_id) REFERENCES pay_levels (id) ON DELETE CASCADE,
    CONSTRAINT pay_level_day_rules_day_name_id_fk FOREIGN KEY (day_name_id) REFERENCES day_names (id) ON DELETE RESTRICT
);

CREATE TABLE venue_config (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    is_singleton BOOLEAN DEFAULT TRUE NOT NULL,
    timezone TEXT NOT NULL,
    week_offset_epoch DATE NOT NULL,
    late_to_early_min_start_gap_minutes INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT venue_config_is_singleton_unique UNIQUE (is_singleton)
);

CREATE TABLE roster_weeks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    week_offset INT NOT NULL,
    is_live BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT roster_weeks_week_offset_unique UNIQUE (week_offset)
);

CREATE TABLE roster_days (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    roster_week_id UUID NOT NULL,
    day_offset INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT roster_days_unique UNIQUE (roster_week_id, day_offset),
    CONSTRAINT roster_days_roster_week_id_fk FOREIGN KEY (roster_week_id) REFERENCES roster_weeks (id) ON DELETE CASCADE
);

CREATE TABLE roster_slots (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    roster_day_id UUID NOT NULL,
    staff_id UUID,
    slot_name_id UUID NOT NULL,
    shift_type_id UUID NOT NULL,
    start_time TIME NOT NULL,
    duration_minutes INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT roster_slots_roster_day_id_fk FOREIGN KEY (roster_day_id) REFERENCES roster_days (id) ON DELETE CASCADE,
    CONSTRAINT roster_slots_staff_id_fk FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE SET NULL,
    CONSTRAINT roster_slots_slot_name_id_fk FOREIGN KEY (slot_name_id) REFERENCES slot_names (id) ON DELETE RESTRICT,
    CONSTRAINT roster_slots_shift_type_id_fk FOREIGN KEY (shift_type_id) REFERENCES shift_types (id) ON DELETE RESTRICT
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
    CONSTRAINT staff_availability_staff_id_fk FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
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
    CONSTRAINT leave_requests_staff_id_fk FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
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
    CONSTRAINT timesheet_entries_staff_id_fk FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE,
    CONSTRAINT timesheet_entries_approved_by_user_id_fk FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
);
