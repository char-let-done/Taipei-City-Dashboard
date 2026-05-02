-- Create tables for traceability_inspection and cas_product DAGs
-- Run before first DAG execution (save_dataframe_to_postgresql uses TRUNCATE)

CREATE TABLE IF NOT EXISTS public.traceability_inspection (
    sampling_location   TEXT,
    inspect_result      TEXT,
    raw_data            JSONB,
    data_time           TEXT
);

CREATE TABLE IF NOT EXISTS public.cas_product (
    material_name   TEXT,
    raw_data        JSONB,
    data_time       TEXT
);

-- 後端可依 ?slice= 選擇替代 SQL（見 traceability_cas_components.sql）
ALTER TABLE public.query_charts
    ADD COLUMN IF NOT EXISTS query_chart_slices jsonb DEFAULT '{}'::jsonb;
