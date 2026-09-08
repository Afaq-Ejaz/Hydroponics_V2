-- Enable UUID generator
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Profiles (syncs with Supabase Auth users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 2. Hydroponic Systems
CREATE TABLE public.hydroponic_systems (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3. System Members (multi-tenancy & access control)
CREATE TYPE member_role AS ENUM ('owner', 'operator', 'viewer');

CREATE TABLE public.system_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id UUID NOT NULL REFERENCES public.hydroponic_systems(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role member_role NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (system_id, user_id)
);

-- 4. Devices (ESP32 hardware registration)
CREATE TABLE public.devices (
    id TEXT PRIMARY KEY, -- e.g., 'ESP32_01'
    system_id UUID NOT NULL REFERENCES public.hydroponic_systems(id) ON DELETE CASCADE,
    api_key_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 5. Sensor Readings (Wide/snapshot ingestion format)
CREATE TABLE public.sensor_readings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    system_id UUID NOT NULL REFERENCES public.hydroponic_systems(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    ph NUMERIC(4, 2),
    ec NUMERIC(5, 2),
    water_temperature NUMERIC(4, 2),
    water_level NUMERIC(5, 2),
    air_temperature NUMERIC(4, 2),
    humidity NUMERIC(5, 2),
    light_intensity NUMERIC(7, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 6. Alerts
CREATE TYPE alert_severity AS ENUM ('info', 'warning', 'critical');

CREATE TABLE public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id UUID NOT NULL REFERENCES public.hydroponic_systems(id) ON DELETE CASCADE,
    device_id TEXT REFERENCES public.devices(id) ON DELETE SET NULL,
    severity alert_severity NOT NULL DEFAULT 'warning',
    message TEXT NOT NULL,
    is_acknowledged BOOLEAN NOT NULL DEFAULT false,
    acknowledged_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- PERFORMANCE INDEXES
CREATE INDEX idx_sensor_readings_system_time 
    ON public.sensor_readings (system_id, recorded_at DESC);

CREATE INDEX idx_system_members_lookup 
    ON public.system_members (user_id, system_id);

CREATE INDEX idx_alerts_unacknowledged 
    ON public.alerts (system_id) 
    WHERE is_acknowledged = false;

-- ROW-LEVEL SECURITY (RLS)
CREATE OR REPLACE FUNCTION public.has_system_access(_system_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM public.system_members 
        WHERE system_id = _system_id 
          AND user_id = auth.uid()
    );
$$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hydroponic_systems ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

-- Profiles Policy
CREATE POLICY "Users view own profile" 
    ON public.profiles FOR SELECT USING (auth.uid() = id);

-- Systems & Members Policies
CREATE POLICY "Members view system" 
    ON public.hydroponic_systems FOR SELECT 
    USING (public.has_system_access(id));

CREATE POLICY "Members view system membership" 
    ON public.system_members FOR SELECT 
    USING (public.has_system_access(system_id));

CREATE POLICY "Members view devices" 
    ON public.devices FOR SELECT 
    USING (public.has_system_access(system_id));

-- Sensor Readings: Flutter can read, direct user inserts blocked (FastAPI writes)
CREATE POLICY "Members view sensor readings" 
    ON public.sensor_readings FOR SELECT 
    USING (public.has_system_access(system_id));

CREATE POLICY "Block user inserts on readings" 
    ON public.sensor_readings FOR INSERT 
    WITH CHECK (false);

-- Alerts Policies
CREATE POLICY "Members view alerts" 
    ON public.alerts FOR SELECT 
    USING (public.has_system_access(system_id));

-- REALTIME & USER SYNC
ALTER PUBLICATION supabase_realtime ADD TABLE public.sensor_readings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;

-- Automatically create profile entry when a user registers
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();