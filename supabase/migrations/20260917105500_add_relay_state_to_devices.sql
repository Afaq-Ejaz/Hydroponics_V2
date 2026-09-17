-- Migration: Add relay_state to devices table and enable Realtime
-- Supports remote relay control (pump, actuators) described in Step 9 and Appendices A & B.

-- 1. Add relay_state column with a default of false (relay OFF)
ALTER TABLE public.devices
    ADD COLUMN IF NOT EXISTS relay_state BOOLEAN NOT NULL DEFAULT false;

-- 2. Allow authenticated members with system access to update relay_state
-- This allows direct-client updates or Supabase functions if needed,
-- while respecting Row Level Security (RLS).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'devices' AND policyname = 'Members update own system devices'
    ) THEN
        CREATE POLICY "Members update own system devices" 
            ON public.devices FOR UPDATE 
            USING (public.has_system_access(system_id))
            WITH CHECK (public.has_system_access(system_id));
    END IF;
END
$$;

-- 3. Add devices to supabase_realtime publication for live status & relay state sync
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'devices'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.devices;
    END IF;
END
$$;
