-- Assets table for asset management
CREATE TABLE IF NOT EXISTS public.assets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  asset_type text NOT NULL CHECK (asset_type IN ('phone', 'wechat', 'sim_card', 'bank_card')),
  name text NOT NULL,
  serial_number text,
  bind_group text,
  monthly_cost numeric(12,2) DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'unbound')),
  assigned_to text,
  assigned_to_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  note text,
  purchase_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;

-- Policy: anyone logged in can read
CREATE POLICY "assets_select" ON public.assets
  FOR SELECT USING (true);

-- Policy: only admin/finance can insert
CREATE POLICY "assets_insert" ON public.assets
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- Policy: only admin/finance can update
CREATE POLICY "assets_update" ON public.assets
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- Policy: only admin/finance can delete
CREATE POLICY "assets_delete" ON public.assets
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS assets_updated_at ON public.assets;
CREATE TRIGGER assets_updated_at
  BEFORE UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_assets_type ON public.assets(asset_type);
CREATE INDEX IF NOT EXISTS idx_assets_status ON public.assets(status);
CREATE INDEX IF NOT EXISTS idx_assets_bind_group ON public.assets(bind_group);
CREATE INDEX IF NOT EXISTS idx_assets_assigned_to_id ON public.assets(assigned_to_id);
