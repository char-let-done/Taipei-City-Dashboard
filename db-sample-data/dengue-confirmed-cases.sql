-- =====================================================
-- 登革熱確定病例統計 (dengue_confirmed_cases) - 資料表與組件配置
-- =====================================================

-- 資料表
CREATE TABLE IF NOT EXISTS public.dengue_confirmed_cases (
    onset_date text,
    diagnosis_date text,
    report_date text,
    gender text,
    age_group text,
    residence_city text,
    residence_district text,
    residence_village text,
    is_imported text,
    infection_country text,
    confirmed_cases integer,
    serotype text,
    lng double precision,
    lat double precision,
    wkb_geometry geometry(Point, 4326),
    data_time timestamp with time zone,
    _ctime timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    _mtime timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    ogc_fid serial PRIMARY KEY
);

CREATE INDEX IF NOT EXISTS dengue_confirmed_cases_wkb_geometry_idx
    ON public.dengue_confirmed_cases USING gist (wkb_geometry);

CREATE INDEX IF NOT EXISTS dengue_confirmed_cases_diagnosis_date_idx
    ON public.dengue_confirmed_cases (diagnosis_date);

CREATE OR REPLACE VIEW public.dengue_confirmed_cases_taipei AS
SELECT *
FROM public.dengue_confirmed_cases
WHERE residence_city IN ('台北市', '臺北市');

-- =====================================================
-- 組件配置 (Manager DB)
-- =====================================================

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);

INSERT INTO public.components ("index", name)
VALUES ('dengue_confirmed_cases', '登革熱確定病例統計')
ON CONFLICT ("index") DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'dengue_confirmed_cases',
    ARRAY['#ED6A45', '#F8CF58', '#56B96D', '#24B0DD', '#E170A6', '#AF4137'],
    ARRAY['TimelineStackedChart'],
    '例'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.component_maps
WHERE "index" IN ('dengue_confirmed_cases', 'dengue_confirmed_cases_taipei');

INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES
(
    'dengue_confirmed_cases_taipei',
    '登革熱確定病例',
    'heatmap',
    'api',
    NULL,
    NULL,
    '{"heatmap-weight":["interpolate",["linear"],["zoom"],10,0.7,16,1],"heatmap-intensity":["interpolate",["linear"],["zoom"],10,0.8,14,1.6,16,2.4],"heatmap-color":["interpolate",["linear"],["heatmap-density"],0,"rgba(36,176,221,0)",0.2,"#24B0DD",0.45,"#56B96D",0.7,"#F8CF58",1,"#ED6A45"],"heatmap-radius":["interpolate",["linear"],["zoom"],10,12,12,22,14,36,16,52],"heatmap-opacity":["interpolate",["linear"],["zoom"],10,0.72,15,0.86,17,0.62]}',
    '[{"key":"diagnosis_date","name":"研判日期"},{"key":"onset_date","name":"發病日"},{"key":"residence_city","name":"居住縣市"},{"key":"residence_district","name":"居住區域"},{"key":"age_group","name":"年齡層"},{"key":"gender","name":"性別"},{"key":"is_imported","name":"境外移入"},{"key":"infection_country","name":"感染國家"},{"key":"serotype","name":"血清型"}]'
),
(
    'dengue_confirmed_cases',
    '登革熱確定病例',
    'heatmap',
    'api',
    NULL,
    NULL,
    '{"heatmap-weight":["interpolate",["linear"],["zoom"],10,0.7,16,1],"heatmap-intensity":["interpolate",["linear"],["zoom"],10,0.8,14,1.6,16,2.4],"heatmap-color":["interpolate",["linear"],["heatmap-density"],0,"rgba(36,176,221,0)",0.2,"#24B0DD",0.45,"#56B96D",0.7,"#F8CF58",1,"#ED6A45"],"heatmap-radius":["interpolate",["linear"],["zoom"],10,12,12,22,14,36,16,52],"heatmap-opacity":["interpolate",["linear"],["zoom"],10,0.72,15,0.86,17,0.62]}',
    '[{"key":"diagnosis_date","name":"研判日期"},{"key":"onset_date","name":"發病日"},{"key":"residence_city","name":"居住縣市"},{"key":"residence_district","name":"居住區域"},{"key":"age_group","name":"年齡層"},{"key":"gender","name":"性別"},{"key":"is_imported","name":"境外移入"},{"key":"infection_country","name":"感染國家"},{"key":"serotype","name":"血清型"}]'
);

DELETE FROM public.query_charts
WHERE "index" = 'dengue_confirmed_cases' AND city IN ('taipei', 'metrotaipei');

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
VALUES
(
    'dengue_confirmed_cases',
    NULL,
    ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'dengue_confirmed_cases_taipei' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byParam","byParam":{"xParam":"is_imported"}}',
    'static',
    NULL,
    1,
    'day',
    '疾病管制署',
    '顯示臺北市登革熱確定病例分布與月份趨勢。',
    '登革熱確定病例統計資料來自疾病管制署開放資料，包含發病日、個案研判日、居住地區、年齡層、性別、是否境外移入、感染國家及血清型等資訊。透過地圖可檢視病例空間分布，圖表則呈現各月份確診案例數量趨勢，有助於掌握疫情時空變化。',
    '可用於疫情監測、公共衛生分析與防疫資源配置。透過病例分布與時間趨勢，可識別高風險區域與季節性模式，作為病媒蚊防治與衛教宣導之參考依據。',
    ARRAY['https://od.cdc.gov.tw/eic/Dengue_Daily.json'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'time',
    'WITH parsed AS (
        SELECT
            DATE_TRUNC(''month'', TO_DATE(diagnosis_date, ''YYYY/MM/DD'')) AS x_axis,
            CASE residence_city WHEN ''台北市'' THEN ''臺北市'' ELSE residence_city END AS y_axis,
            confirmed_cases
        FROM public.dengue_confirmed_cases
        WHERE diagnosis_date IS NOT NULL AND diagnosis_date != ''''
            AND residence_city IN (''台北市'', ''臺北市'')
    )
    SELECT x_axis, y_axis, SUM(confirmed_cases)::float AS data
    FROM parsed
    WHERE x_axis >= (SELECT MAX(x_axis) FROM parsed) - INTERVAL ''12 months''
    GROUP BY x_axis, y_axis
    ORDER BY x_axis',
    NULL,
    'taipei'
),
(
    'dengue_confirmed_cases',
    NULL,
    ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'dengue_confirmed_cases' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byParam","byParam":{"xParam":"is_imported"}}',
    'static',
    NULL,
    1,
    'day',
    '疾病管制署',
    '顯示雙北登革熱確定病例分布與月份趨勢。',
    '登革熱確定病例統計資料來自疾病管制署開放資料，包含發病日、個案研判日、居住縣市、居住地區、年齡層、性別、是否境外移入、感染國家及血清型等資訊。雙北版本涵蓋臺北市與新北市，透過地圖可檢視病例空間分布，圖表則呈現各月份確診案例數量趨勢，有助於掌握疫情時空變化。',
    '可用於雙北疫情監測、公共衛生分析與防疫資源配置。透過病例分布與時間趨勢，可識別高風險區域與季節性模式，作為病媒蚊防治與衛教宣導之參考依據。',
    ARRAY['https://od.cdc.gov.tw/eic/Dengue_Daily.json'],
    ARRAY['doit', 'ntpc'],
    NOW(),
    NOW(),
    'time',
    'WITH parsed AS (
        SELECT
            DATE_TRUNC(''month'', TO_DATE(diagnosis_date, ''YYYY/MM/DD'')) AS x_axis,
            CASE residence_city WHEN ''台北市'' THEN ''臺北市'' ELSE residence_city END AS y_axis,
            confirmed_cases
        FROM public.dengue_confirmed_cases
        WHERE diagnosis_date IS NOT NULL AND diagnosis_date != ''''
            AND residence_city IN (''台北市'', ''臺北市'', ''新北市'')
    )
    SELECT x_axis, y_axis, SUM(confirmed_cases)::float AS data
    FROM parsed
    WHERE x_axis >= (SELECT MAX(x_axis) FROM parsed) - INTERVAL ''12 months''
    GROUP BY x_axis, y_axis
    ORDER BY x_axis',
    NULL,
    'metrotaipei'
);

-- 將組件加入儀表板 (假設有一個健康相關儀表板，這裡示範新增)
-- 如需加入現有儀表板，請依據實際需求調整
INSERT INTO public.dashboards ("index", name, components, icon, created_at, updated_at)
VALUES (
    'dengue-confirmed-cases-metrotaipei',
    '雙北登革熱確定病例',
    ARRAY[(SELECT id FROM public.components WHERE "index" = 'dengue_confirmed_cases')],
    'virus',
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
WHERE d."index" = 'dengue-confirmed-cases-metrotaipei'
ON CONFLICT DO NOTHING;

SELECT setval('public.component_maps_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.component_maps), true);
