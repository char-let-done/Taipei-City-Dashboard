CREATE TABLE IF NOT EXISTS public.water_pipe (
    data_time timestamp with time zone,
    segment_id integer,
    source_city text,
    source_resource_id text,
    category_code text,
    pipe_uid text,
    start_node_id text,
    end_node_id text,
    manager text,
    operation_type text,
    time_position text,
    pipe_no text,
    diameter_unit text,
    diameter_width double precision,
    diameter_height double precision,
    pipe_count double precision,
    material text,
    start_depth double precision,
    end_depth double precision,
    pipe_length double precision,
    pipe_type text,
    usage_status text,
    data_status text,
    note text,
    substance text,
    wkb_geometry geometry(LineString,4326),
    _ctime timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    _mtime timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    ogc_fid serial PRIMARY KEY
);

ALTER TABLE public.water_pipe
    ADD COLUMN IF NOT EXISTS source_city text;

UPDATE public.water_pipe
SET source_city = 'taipei'
WHERE source_city IS NULL;

CREATE INDEX IF NOT EXISTS water_pipe_wkb_geometry_idx
    ON public.water_pipe USING gist (wkb_geometry);

CREATE INDEX IF NOT EXISTS water_pipe_material_idx
    ON public.water_pipe (material);

CREATE INDEX IF NOT EXISTS water_pipe_source_city_idx
    ON public.water_pipe (source_city);

CREATE OR REPLACE VIEW public.water_pipe_map AS
SELECT *
FROM public.water_pipe
WHERE source_city = 'taipei'
  AND diameter_width >= 300;

CREATE OR REPLACE VIEW public.water_pipe_metrotaipei_map AS
SELECT *
FROM public.water_pipe
WHERE source_city = 'newtaipei'
   OR diameter_width >= 300;

INSERT INTO public.components ("index", name)
VALUES ('water_pipe', '自來水管線')
ON CONFLICT ("index") DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'water_pipe',
    ARRAY['#24B0DD', '#56D6E7', '#9FE7F5', '#2B78E4', '#7ED3B2', '#F8CF58'],
    ARRAY['BarChart', 'DonutChart'],
    '公尺'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.component_maps WHERE "index" IN ('water_pipe', 'water_pipe_map', 'water_pipe_metrotaipei_map');

INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES (
    'water_pipe_map',
    '自來水管線',
    'line',
    'api',
    NULL,
    NULL,
    '{
        "line-color": [
            "case",
            ["==", ["get", "usage_status"], "使用中"], "#24B0DD",
            ["==", ["get", "usage_status"], "營運中"], "#24B0DD",
            ["==", ["get", "usage_status"], "廢棄"], "#7A8A99",
            "#56D6E7"
        ],
        "line-opacity": 0.78,
        "line-width": [
            "interpolate",
            ["linear"],
            ["zoom"],
            10, 1.2,
            14, [
                "interpolate",
                ["linear"],
                ["to-number", ["get", "diameter_width"]],
                0, 1.4,
                100, 2.4,
                300, 4,
                1000, 7
            ],
            17, [
                "interpolate",
                ["linear"],
                ["to-number", ["get", "diameter_width"]],
                0, 2,
                100, 4,
                300, 7,
                1000, 12
            ]
        ],
        "line-cap": "round",
        "line-join": "round",
        "line-flow": true,
        "line-flow-color": "#E7FBFF",
        "line-flow-width": 2
    }'::json,
    '[
        {"key":"pipe_no","name":"管線編號"},
        {"key":"pipe_uid","name":"識別碼"},
        {"key":"source_city","name":"資料城市"},
        {"key":"material","name":"管線材料"},
        {"key":"diameter_width","name":"管徑寬度"},
        {"key":"diameter_unit","name":"尺寸單位"},
        {"key":"pipe_length","name":"管線長度"},
        {"key":"pipe_type","name":"管線型態"},
        {"key":"usage_status","name":"使用狀態"},
        {"key":"data_status","name":"資料狀態"},
        {"key":"substance","name":"輸送物質"}
    ]'::json
);

INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES (
    'water_pipe_metrotaipei_map',
    '自來水管線',
    'line',
    'api',
    NULL,
    NULL,
    '{
        "line-color": [
            "case",
            ["==", ["get", "source_city"], "newtaipei"], "#56D6E7",
            ["==", ["get", "usage_status"], "使用中"], "#24B0DD",
            ["==", ["get", "usage_status"], "營運中"], "#24B0DD",
            ["==", ["get", "usage_status"], "廢棄"], "#7A8A99",
            "#56D6E7"
        ],
        "line-opacity": 0.72,
        "line-width": [
            "interpolate",
            ["linear"],
            ["zoom"],
            10, 1,
            14, [
                "interpolate",
                ["linear"],
                ["coalesce", ["to-number", ["get", "diameter_width"]], 120],
                0, 1.4,
                100, 2.4,
                300, 4,
                1000, 7
            ],
            17, [
                "interpolate",
                ["linear"],
                ["coalesce", ["to-number", ["get", "diameter_width"]], 120],
                0, 2,
                100, 4,
                300, 7,
                1000, 12
            ]
        ],
        "line-cap": "round",
        "line-join": "round",
        "line-flow": true,
        "line-flow-color": "#E7FBFF",
        "line-flow-width": 2
    }'::json,
    '[
        {"key":"pipe_no","name":"管線編號"},
        {"key":"pipe_uid","name":"識別碼"},
        {"key":"source_city","name":"資料城市"},
        {"key":"material","name":"管線材料"},
        {"key":"diameter_width","name":"管徑寬度"},
        {"key":"diameter_unit","name":"尺寸單位"},
        {"key":"pipe_length","name":"管線長度"},
        {"key":"pipe_type","name":"管線型態"},
        {"key":"usage_status","name":"使用狀態"},
        {"key":"data_status","name":"資料狀態"},
        {"key":"substance","name":"輸送物質"}
    ]'::json
);

DELETE FROM public.query_charts
WHERE "index" = 'water_pipe' AND city IN ('taipei', 'metrotaipei');

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
    'water_pipe',
    NULL,
    ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'water_pipe_map' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byLayer"}',
    'static',
    NULL,
    0,
    NULL,
    '臺北市政府工務局',
    '顯示臺北市自來水系統管線分布，線寬依管徑呈現並以動態線段表現水流。',
    '臺北市公共管線圖資_自來水系統管線資料包含自來水管線線段、管徑、材料、長度、使用狀態與輸送物質等資訊。地圖以 LineString 呈現管線路網，並使用動態流線視覺化供水流動感。',
    '可用於檢視自來水管線路網分布、管徑級距、材料組成與使用狀態，協助供水設施盤點與跨圖層空間分析。',
    ARRAY['https://data.taipei/dataset/detail?id=af167303-0e5f-45dd-b624-a01f541565ce'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'two_d',
    'SELECT COALESCE(NULLIF(material, ''''), ''未分類'') AS x_axis, ROUND(SUM(COALESCE(pipe_length, ST_Length(wkb_geometry::geography)))::numeric, 2)::float AS data FROM public.water_pipe WHERE source_city = ''taipei'' GROUP BY x_axis ORDER BY data DESC LIMIT 12',
    NULL,
    'taipei'
);

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
    'water_pipe',
    NULL,
    ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'water_pipe_metrotaipei_map' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byLayer"}',
    'static',
    NULL,
    0,
    NULL,
    '臺北市政府工務局、新北市政府',
    '顯示雙北自來水系統管線分布，線寬依管徑呈現並以動態線段表現水流。',
    '雙北自來水系統管線資料整合臺北市公共管線圖資與新北市 iROAD 公共設施管線圖資，包含 LineString 管線路網及來源城市等欄位。臺北市資料保留管徑、材料、長度、使用狀態與輸送物質等屬性；新北市 ArcGIS 服務提供管線識別碼、類別碼、管理單位、補正狀態與線段幾何。',
    '可用於檢視雙北自來水管線路網分布、跨市銜接與資料覆蓋範圍，協助供水設施盤點與跨圖層空間分析。',
    ARRAY[
        'https://data.taipei/dataset/detail?id=af167303-0e5f-45dd-b624-a01f541565ce',
        'https://roadmt.maintenance.ntpc.gov.tw/iROAD'
    ],
    ARRAY['doit', 'ntpc'],
    NOW(),
    NOW(),
    'two_d',
    'SELECT x_axis, ROUND(SUM(data)::numeric, 2)::float AS data FROM (SELECT COALESCE(NULLIF(material, ''''), ''未分類'') AS x_axis, COALESCE(pipe_length, ST_Length(wkb_geometry::geography)) AS data FROM public.water_pipe WHERE source_city = ''taipei'' UNION ALL SELECT ''新北市自來水管線'' AS x_axis, ST_Length(wkb_geometry::geography) AS data FROM public.water_pipe WHERE source_city = ''newtaipei'') d GROUP BY x_axis ORDER BY data DESC LIMIT 12',
    NULL,
    'metrotaipei'
);

INSERT INTO public.dashboards ("index", name, components, icon, created_at, updated_at)
VALUES (
    'water-pipe-taipei',
    '自來水管線',
    ARRAY[(SELECT id FROM public.components WHERE "index" = 'water_pipe')],
    'water',
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
WHERE d."index" = 'water-pipe-taipei'
ON CONFLICT DO NOTHING;

INSERT INTO public.dashboards ("index", name, components, icon, created_at, updated_at)
VALUES (
    'water-pipe-metrotaipei',
    '自來水管線',
    ARRAY[(SELECT id FROM public.components WHERE "index" = 'water_pipe')],
    'water',
    NOW(),
    NOW()
)
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name,
    components = EXCLUDED.components,
    icon = EXCLUDED.icon,
    updated_at = NOW();

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, 3
FROM public.dashboards d
WHERE d."index" = 'water-pipe-metrotaipei'
ON CONFLICT DO NOTHING;

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);
SELECT setval('public.component_maps_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.component_maps), true);
