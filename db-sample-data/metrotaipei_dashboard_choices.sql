-- =====================================================
-- Metro Taipei dashboard choices
-- =====================================================

BEGIN;

-- Component 239 is used by the active_choice dashboard. Some local DBs have
-- the component/chart from older imports but are missing query_charts rows.
INSERT INTO public.components ("index", name)
VALUES ('eco_cup_brand', '循環杯品牌據點統計')
ON CONFLICT ("index") DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'eco_cup_brand',
    ARRAY['#4CAF50'],
    ARRAY['BarChart'],
    '家'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.query_charts
WHERE "index" = 'eco_cup_brand'
  AND city IN ('taipei', 'metrotaipei');

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
    'eco_cup_brand',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    1,
    'month',
    '環保署/各連鎖品牌',
    '顯示臺北市循環杯品牌據點數量。',
    '統計臺北市循環杯友善據點依品牌分布的數量。',
    '可用於比較不同品牌在循環杯友善據點服務中的覆蓋狀況。',
    '{}',
    '{doit}',
    NOW(),
    NOW(),
    'two_d',
    E'SELECT brand AS x_axis, COUNT(*)::float AS data FROM public.eco_cup_store WHERE city = ''臺北市'' GROUP BY brand ORDER BY data DESC',
    NULL,
    'taipei'
),
(
    'eco_cup_brand',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    1,
    'month',
    '環保署/各連鎖品牌',
    '顯示雙北循環杯品牌據點數量。',
    '統計臺北市與新北市循環杯友善據點依品牌分布的數量。',
    '可用於比較不同品牌在雙北循環杯友善據點服務中的覆蓋狀況。',
    '{}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'two_d',
    E'SELECT brand AS x_axis, COUNT(*)::float AS data FROM public.eco_cup_store WHERE city IN (''臺北市'', ''新北市'') GROUP BY brand ORDER BY data DESC',
    NULL,
    'metrotaipei'
);

-- The risk dashboard is available in both Taipei and Metro Taipei. These
-- components are Taipei-sourced, so Metro Taipei uses the same chart queries
-- where no separate New Taipei source exists.
DELETE FROM public.query_charts
WHERE "index" IN (
    'water_valve',
    'infectious_food_disease_district',
    'infectious_food_disease_monthly'
)
  AND city = 'metrotaipei';

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
SELECT
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
    NOW(),
    NOW(),
    query_type,
    query_chart,
    query_history,
    'metrotaipei'
FROM public.query_charts
WHERE "index" IN (
    'water_valve',
    'infectious_food_disease_district',
    'infectious_food_disease_monthly'
)
  AND city = 'taipei';

-- Remove regular dashboard choices except the three requested ones below.
-- Keep reserved map-layer dashboards because the frontend loads them directly.
DELETE FROM public.dashboard_groups
WHERE dashboard_id IN (
    SELECT id
    FROM public.dashboards
    WHERE "index" NOT IN (
        'risk',
        'active_choice',
        'sport',
        'map-layers-taipei',
        'map-layers-metrotaipei'
    )
);

DELETE FROM public.dashboards
WHERE "index" NOT IN (
    'risk',
    'active_choice',
    'sport',
    'map-layers-taipei',
    'map-layers-metrotaipei'
);

INSERT INTO public.dashboards ("index", name, components, icon, updated_at, created_at)
VALUES
(
    'risk',
    '風險',
    ARRAY[
        (SELECT id::integer FROM public.components WHERE "index" = 'water_pipe'),
        (SELECT id::integer FROM public.components WHERE "index" = 'water_valve'),
        (SELECT id::integer FROM public.components WHERE "index" = 'infectious_food_disease_district'),
        (SELECT id::integer FROM public.components WHERE "index" = 'infectious_food_disease_monthly')
    ],
    'warning',
    NOW(),
    NOW()
),
(
    'active_choice',
    '主動選擇',
    ARRAY[
        (SELECT id::integer FROM public.components WHERE "index" = 'dengue_confirmed_cases'),
        (SELECT id::integer FROM public.components WHERE "index" = 'public_market'),
        (SELECT id::integer FROM public.components WHERE "index" = 'traceability_inspection'),
        (SELECT id::integer FROM public.components WHERE "index" = 'cas_product'),
        (SELECT id::integer FROM public.components WHERE "index" = 'restaurant_overview'),
        (SELECT id::integer FROM public.components WHERE "index" = 'eco_cup_store'),
        (SELECT id::integer FROM public.components WHERE "index" = 'eco_cup_brand'),
        (SELECT id::integer FROM public.components WHERE "index" = 'eco_cup_district')
    ],
    'restaurant',
    NOW(),
    NOW()
),
(
    'sport',
    '運動',
    ARRAY[
        (SELECT id::integer FROM public.components WHERE "index" = 'sports_venue'),
        (SELECT id::integer FROM public.components WHERE "index" = 'sports_center')
    ],
    'sports_soccer',
    NOW(),
    NOW()
)
,
(
    'map-layers-taipei',
    '圖資資訊',
    ARRAY[
        (SELECT id::integer FROM public.components WHERE "index" = 'bike_map'),
        (SELECT id::integer FROM public.components WHERE "index" = 'eco_cup_store'),
        (SELECT id::integer FROM public.components WHERE "index" = 'eco_cup_district')
    ],
    'public',
    NOW(),
    NOW()
),
(
    'map-layers-metrotaipei',
    '圖資資訊',
    ARRAY[
        (SELECT id::integer FROM public.components WHERE "index" = 'bike_map'),
        (SELECT id::integer FROM public.components WHERE "index" = 'eco_cup_store'),
        (SELECT id::integer FROM public.components WHERE "index" = 'eco_cup_district')
    ],
    'public',
    NOW(),
    NOW()
)
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name,
    components = EXCLUDED.components,
    icon = EXCLUDED.icon,
    updated_at = NOW();

DELETE FROM public.dashboard_groups
WHERE dashboard_id IN (
    SELECT id
    FROM public.dashboards
    WHERE "index" IN (
        'risk',
        'active_choice',
        'sport',
        'map-layers-taipei',
        'map-layers-metrotaipei'
    )
);

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
VALUES
    ((SELECT id FROM public.dashboards WHERE "index" = 'risk'), 2),
    ((SELECT id FROM public.dashboards WHERE "index" = 'risk'), 3),
    ((SELECT id FROM public.dashboards WHERE "index" = 'active_choice'), 2),
    ((SELECT id FROM public.dashboards WHERE "index" = 'active_choice'), 3),
    ((SELECT id FROM public.dashboards WHERE "index" = 'sport'), 2),
    ((SELECT id FROM public.dashboards WHERE "index" = 'sport'), 3),
    ((SELECT id FROM public.dashboards WHERE "index" = 'map-layers-taipei'), 2),
    ((SELECT id FROM public.dashboards WHERE "index" = 'map-layers-metrotaipei'), 3)
ON CONFLICT DO NOTHING;

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);
SELECT setval('public.dashboards_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.dashboards), true);

COMMIT;
