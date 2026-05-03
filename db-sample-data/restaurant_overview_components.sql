-- =====================================================
-- 餐廳總覽（合併組件）配置 SQL
-- 適用 postgres-manager (dashboardmanager)
-- 合併：環保餐廳、溯源餐廳、穆斯林餐廳、衛生餐廳
-- 前端透過 compositeComponents 設定動態切換子組件
-- =====================================================

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);

-- ===== 0. Fix map_config_ids for sub-components =====
-- The demo COPY may assign different component_maps IDs than expected.
-- Patch query_charts to reference the actual IDs by index lookup.

UPDATE public.query_charts
SET map_config_ids = ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'muslim_restaurant_tpe' ORDER BY id DESC LIMIT 1)]
WHERE "index" = 'muslim_restaurant' AND city = 'taipei';

UPDATE public.query_charts
SET map_config_ids = ARRAY[
    (SELECT id FROM public.component_maps WHERE "index" = 'muslim_restaurant_tpe' ORDER BY id DESC LIMIT 1),
    (SELECT id FROM public.component_maps WHERE "index" = 'muslim_restaurant_ntpc' ORDER BY id DESC LIMIT 1)
]
WHERE "index" = 'muslim_restaurant' AND city = 'metrotaipei';

UPDATE public.query_charts
SET map_config_ids = ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'hygiene_restaurant_tpe' ORDER BY id DESC LIMIT 1)]
WHERE "index" = 'hygiene_restaurant' AND city = 'taipei';

UPDATE public.query_charts
SET map_config_ids = ARRAY[
    (SELECT id FROM public.component_maps WHERE "index" = 'hygiene_restaurant_tpe' ORDER BY id DESC LIMIT 1),
    (SELECT id FROM public.component_maps WHERE "index" = 'hygiene_restaurant_ntpc' ORDER BY id DESC LIMIT 1)
]
WHERE "index" = 'hygiene_restaurant' AND city = 'metrotaipei';

-- ===== 1. 組件 =====

INSERT INTO public.components ("index", name)
VALUES ('restaurant_overview', '餐廳總覽')
ON CONFLICT ("index") DO UPDATE SET name = EXCLUDED.name;

-- ===== 2. 圖表設定（預設使用溯源餐廳的配置） =====

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'restaurant_overview',
    ARRAY['#ffcc80','#f57c00','#e65100','#fb8c00','#ff9800','#ffa726','#ffb74d','#ef6c00','#ffe0b2'],
    ARRAY['BarChart','TreemapChart'],
    '間'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

-- ===== 3. 地圖圖層（預設使用溯源餐廳，子組件切換時前端動態替換） =====
-- 不新增 map 層，沿用已有的 traceable_restaurant 圖層作為預設

-- ===== 4. 查詢設定（預設使用溯源餐廳的查詢） =====

DELETE FROM public.query_charts WHERE "index" = 'restaurant_overview';

INSERT INTO public.query_charts (
    "index", history_config,
    map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
)
VALUES
(
    'restaurant_overview',
    NULL,
    ARRAY[(SELECT id FROM public.component_maps WHERE "index" = 'traceable_restaurant_tpe' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byParam","byParam":{"xParam":"cuisine_type"}}',
    'static', NULL, 1, 'month',
    '衛生局',
    '顯示臺北市各類餐廳（溯源、衛生、環保、穆斯林）按類別之分布數量。',
    '整合臺北市溯源餐廳、衛生優良餐廳、環保餐廳及穆斯林友善餐廳四大類別資料，可透過左側篩選按鈕切換不同餐廳類型之圖表與地圖。',
    '可用於快速比較不同類型餐廳之分布情形，作為市民查詢餐廳及政策推廣成效之綜合參考。',
    ARRAY[]::text[],
    ARRAY['doit'],
    NOW(), NOW(),
    'two_d',
    (SELECT query_chart FROM public.query_charts WHERE "index" = 'traceable_restaurant' AND city = 'taipei'),
    NULL,
    'taipei'
),
(
    'restaurant_overview',
    NULL,
    ARRAY[
        (SELECT id FROM public.component_maps WHERE "index" = 'traceable_restaurant_tpe' ORDER BY id DESC LIMIT 1),
        (SELECT id FROM public.component_maps WHERE "index" = 'traceable_restaurant_ntpc' ORDER BY id DESC LIMIT 1)
    ],
    '{"mode":"byParam","byParam":{"xParam":"cuisine_type"}}',
    'static', NULL, 1, 'month',
    '衛生局',
    '顯示雙北各類餐廳按類別之分布數量。',
    '整合雙北溯源餐廳、衛生優良餐廳、環保餐廳及穆斯林友善餐廳四大類別資料，涵蓋臺北市與新北市兩地資料。',
    '可用於比較雙北不同類型餐廳之分布差異，協助市民查詢餐廳，並作為雙北政策推廣成效之參考依據。',
    ARRAY[]::text[],
    ARRAY['doit','ntpc'],
    NOW(), NOW(),
    'two_d',
    (SELECT query_chart FROM public.query_charts WHERE "index" = 'traceable_restaurant' AND city = 'metrotaipei'),
    NULL,
    'metrotaipei'
);

-- ===== 5. 從儀表板移除四個獨立餐廳組件 =====

UPDATE public.dashboards
SET components = array_remove(components, (SELECT id FROM public.components WHERE "index" = 'green_restaurant')),
    updated_at = NOW()
WHERE (SELECT id FROM public.components WHERE "index" = 'green_restaurant') = ANY(components);

UPDATE public.dashboards
SET components = array_remove(components, (SELECT id FROM public.components WHERE "index" = 'traceable_restaurant')),
    updated_at = NOW()
WHERE (SELECT id FROM public.components WHERE "index" = 'traceable_restaurant') = ANY(components);

UPDATE public.dashboards
SET components = array_remove(components, (SELECT id FROM public.components WHERE "index" = 'muslim_restaurant')),
    updated_at = NOW()
WHERE (SELECT id FROM public.components WHERE "index" = 'muslim_restaurant') = ANY(components);

UPDATE public.dashboards
SET components = array_remove(components, (SELECT id FROM public.components WHERE "index" = 'hygiene_restaurant')),
    updated_at = NOW()
WHERE (SELECT id FROM public.components WHERE "index" = 'hygiene_restaurant') = ANY(components);

-- ===== 6. 加入餐廳總覽到儀表板 =====

UPDATE public.dashboards
SET components = array_append(components, (SELECT id FROM public.components WHERE "index" = 'restaurant_overview')),
    updated_at = NOW()
WHERE "index" IN ('food_safety_health', 'food_safety_health_tpe', 'food_safety_health_newtpe')
  AND NOT ((SELECT id FROM public.components WHERE "index" = 'restaurant_overview') = ANY(components));

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);
