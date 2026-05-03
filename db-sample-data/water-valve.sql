CREATE TABLE IF NOT EXISTS public.water_valve (
    data_time timestamp with time zone,
    valve_id integer,
    category_code text,
    valve_uid text,
    manager text,
    operation_type text,
    install_date date,
    valve_age_years integer,
    switch_valve_no text,
    valve_no text,
    diameter double precision,
    name text,
    ground_elevation double precision,
    buried_depth double precision,
    valve_type text,
    usage_status text,
    data_status text,
    note text,
    wkb_geometry geometry(Point,4326),
    _ctime timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    _mtime timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    ogc_fid serial PRIMARY KEY
);

CREATE INDEX IF NOT EXISTS water_valve_wkb_geometry_idx
    ON public.water_valve USING gist (wkb_geometry);

CREATE INDEX IF NOT EXISTS water_valve_install_date_idx
    ON public.water_valve (install_date);

CREATE OR REPLACE VIEW public.water_valve_map AS
SELECT *
FROM public.water_valve
WHERE valve_age_years IS NOT NULL;

INSERT INTO public.components ("index", name)
VALUES ('water_valve', '自來水系統閥類')
ON CONFLICT ("index") DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'water_valve',
    ARRAY['#A7D8FF', '#24B0DD', '#56B96D', '#F8CF58', '#ED6A45', '#8F98A3'],
    ARRAY['BarChart', 'DonutChart'],
    '座'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.component_maps WHERE "index" IN ('water_valve', 'water_valve_map');

INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES (
    'water_valve_map',
    '自來水系統閥類',
    'heatmap',
    'api',
    NULL,
    'valve_heatmap',
    '{
        "heatmap-weight": [
            "interpolate",
            ["linear"],
            ["to-number", ["get", "valve_age_years"]],
            0, 0.18,
            10, 0.26,
            25, 0.42,
            50, 0.66,
            80, 0.86,
            100, 1
        ],
        "heatmap-intensity": [
            "interpolate",
            ["linear"],
            ["zoom"],
            10, 0.55,
            14, 0.95,
            16, 1.3
        ],
        "heatmap-color": [
            "interpolate",
            ["linear"],
            ["heatmap-density"],
            0, "rgba(36,176,221,0)",
            0.18, "#24B0DD",
            0.38, "#56B96D",
            0.62, "#F8CF58",
            0.82, "#ED6A45",
            1, "#AF4137"
        ],
        "heatmap-radius": [
            "interpolate",
            ["linear"],
            ["zoom"],
            10, 10,
            12, 18,
            14, 30,
            16, 44
        ],
        "heatmap-opacity": [
            "interpolate",
            ["linear"],
            ["zoom"],
            10, 0.68,
            15, 0.84,
            17, 0.58
        ]
    }'::json,
    '[
        {"key":"valve_no","name":"閥類編號"},
        {"key":"switch_valve_no","name":"開關閥編號"},
        {"key":"install_date","name":"設置日期"},
        {"key":"valve_age_years","name":"閥齡"},
        {"key":"diameter","name":"口徑"},
        {"key":"valve_type","name":"開關閥型態"},
        {"key":"usage_status","name":"使用狀態"},
        {"key":"buried_depth","name":"埋設深度"}
    ]'::json
);

DELETE FROM public.query_charts
WHERE "index" = 'water_valve' AND city = 'taipei';

INSERT INTO public.query_charts (
    "index",
    history_config,
    map_config_ids,
    map_filter,
    time_from,
    time_to,
    update_freq,
    update_freq_unit,
    source,
    short_desc,
    long_desc,
    use_case,
    links,
    contributors,
    created_at,
    updated_at,
    query_type,
    query_chart,
    query_history,
    city
)
VALUES (
    'water_valve',
    NULL,
    ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'water_valve_map' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byLayer"}',
    'static',
    NULL,
    0,
    NULL,
    '臺北市政府工務局',
    '顯示臺北市自來水系統閥類點位，並依設置日期計算閥齡著色；1912 年設置日期視為未知。',
    '臺北市公共管線圖資_自來水系統閥類包含閥類位置、編號、口徑、設置日期、埋設深度、型態與使用狀態。地圖以閥齡呈現顏色，設置日期為 1912 年者在資料庫中存為 NULL，前端以灰色表示未知設置日期。',
    '可用於檢視自來水閥類分布、口徑級距與閥齡狀態，協助供水設施維護盤點與汰換優先序評估。',
    ARRAY['https://data.taipei/api/dataset/44c6fb09-8f51-403a-95a8-99a2387c2f05/resource/2046c65f-024f-4ded-ad25-5349b66a41ed/download'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'two_d',
    'SELECT age_bucket AS x_axis, COUNT(*)::float AS data FROM (SELECT CASE WHEN install_date IS NULL THEN ''未知'' WHEN valve_age_years < 10 THEN ''0-9年'' WHEN valve_age_years < 25 THEN ''10-24年'' WHEN valve_age_years < 50 THEN ''25-49年'' WHEN valve_age_years < 80 THEN ''50-79年'' ELSE ''80年以上'' END AS age_bucket, CASE WHEN install_date IS NULL THEN 0 WHEN valve_age_years < 10 THEN 1 WHEN valve_age_years < 25 THEN 2 WHEN valve_age_years < 50 THEN 3 WHEN valve_age_years < 80 THEN 4 ELSE 5 END AS sort_key FROM public.water_valve) d GROUP BY age_bucket, sort_key ORDER BY sort_key',
    NULL,
    'taipei'
);

INSERT INTO public.dashboards ("index", name, components, icon, created_at, updated_at)
VALUES (
    'water-valve-taipei',
    '自來水系統閥類',
    ARRAY[(SELECT id FROM public.components WHERE "index" = 'water_valve')],
    'valve',
    NOW(),
    NOW()
)
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name,
    components = EXCLUDED.components,
    icon = EXCLUDED.icon,
    updated_at = NOW();

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, 2
FROM public.dashboards d
WHERE d."index" = 'water-valve-taipei'
ON CONFLICT DO NOTHING;

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);
SELECT setval('public.component_maps_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.component_maps), true);
