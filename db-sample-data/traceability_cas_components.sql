-- =====================================================
-- 產銷履歷抽驗結果 + CAS 認證產品 組件配置 SQL
-- 需先執行 traceability_cas_tables.sql 建表
--
-- slice：後端 GET /component/:id/chart?slice=<key> 時，若 query_chart_slices
--         JSON 內有該 key，則改用對應的 query_type + query_chart（多維圖表用）；
--         不帶 slice 時仍用 query_chart 主查詢（合格／不合格匯總）。
-- =====================================================

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);

-- ===== 1. 產銷履歷抽驗結果 =====

INSERT INTO public.components ("index", name)
VALUES ('traceability_inspection', '產銷履歷抽驗結果')
ON CONFLICT ("index") DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'traceability_inspection',
    ARRAY[
        '#2ECC71','#E74C3C','#3498DB','#9B59B6','#F39C12','#1ABC9C','#E67E22','#34495E',
        '#16A085','#D35400','#8E44AD','#27AE60'
    ],
    ARRAY['TraceabilityInspectionRich'],
    '件'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.query_charts
WHERE "index" = 'traceability_inspection';

INSERT INTO public.query_charts (
    "index", history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
)
VALUES
(
    'traceability_inspection',
    NULL, NULL, NULL,
    'current', NULL, 1, 'hour',
    '農業部農業開放資料平臺',
    '產銷履歷農產品抽驗合格率與多維分析。',
    '透過農業部產銷履歷農產品抽驗結果 API，整合合格／不合格構成、行政區堆疊、熱門品項（Treemap）、檢驗備註（Note）、按月合格率（民國 SamplingDate）與高不合格率品項等視角。',
    '適用於食安監控與農產品品質追蹤。',
    ARRAY['https://data.moa.gov.tw/api.aspx'],
    ARRAY['doit'],
    NOW(), NOW(),
    'two_d',
    'SELECT inspect_result AS x_axis, COUNT(*)::integer AS data FROM traceability_inspection WHERE inspect_result IS NOT NULL GROUP BY inspect_result ORDER BY inspect_result DESC',
    NULL,
    'taipei'
),
(
    'traceability_inspection',
    NULL, NULL, NULL,
    'current', NULL, 1, 'hour',
    '農業部農業開放資料平臺',
    '產銷履歷農產品抽驗合格率與多維分析。',
    '透過農業部產銷履歷農產品抽驗結果 API，整合合格／不合格構成、行政區堆疊、熱門品項（Treemap）、檢驗備註（Note）、按月合格率（民國 SamplingDate）與高不合格率品項等視角。',
    '適用於食安監控與農產品品質追蹤。',
    ARRAY['https://data.moa.gov.tw/api.aspx'],
    ARRAY['doit'],
    NOW(), NOW(),
    'two_d',
    'SELECT inspect_result AS x_axis, COUNT(*)::integer AS data FROM traceability_inspection WHERE inspect_result IS NOT NULL GROUP BY inspect_result ORDER BY inspect_result DESC',
    NULL,
    'metrotaipei'
);

-- ===== 2. CAS 認證產品分佈 =====

INSERT INTO public.components ("index", name)
VALUES ('cas_product', 'CAS 認證產品分佈')
ON CONFLICT ("index") DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'cas_product',
    ARRAY['#3498DB','#E67E22','#2ECC71','#9B59B6','#E74C3C','#1ABC9C','#F39C12','#34495E'],
    ARRAY['TreemapChart'],
    '項'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.query_charts
WHERE "index" = 'cas_product';

INSERT INTO public.query_charts (
    "index", history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
)
VALUES
(
    'cas_product',
    NULL, NULL, NULL,
    'current', NULL, 1, 'hour',
    '農業部農業開放資料平臺',
    'CAS 優良農產品認證產品類別分佈。',
    '透過農業部 CAS 產品查詢 API，以樹狀圖呈現各材料類別（肉品、蛋品、水產等）通過 CAS 認證的產品數量，面積越大代表該類認證產品越多。',
    '適用於食安監控與優良農產品推廣。',
    ARRAY['https://data.moa.gov.tw/api.aspx'],
    ARRAY['doit'],
    NOW(), NOW(),
    'two_d',
    'SELECT material_name AS x_axis, COUNT(*)::integer AS data FROM cas_product WHERE material_name IS NOT NULL GROUP BY material_name ORDER BY data DESC',
    NULL,
    'taipei'
),
(
    'cas_product',
    NULL, NULL, NULL,
    'current', NULL, 1, 'hour',
    '農業部農業開放資料平臺',
    'CAS 優良農產品認證產品類別分佈。',
    '透過農業部 CAS 產品查詢 API，以樹狀圖呈現各材料類別（肉品、蛋品、水產等）通過 CAS 認證的產品數量，面積越大代表該類認證產品越多。',
    '適用於食安監控與優良農產品推廣。',
    ARRAY['https://data.moa.gov.tw/api.aspx'],
    ARRAY['doit'],
    NOW(), NOW(),
    'two_d',
    'SELECT material_name AS x_axis, COUNT(*)::integer AS data FROM cas_product WHERE material_name IS NOT NULL GROUP BY material_name ORDER BY data DESC',
    NULL,
    'metrotaipei'
);

-- 抽驗元件：slice 對應 SQL（GET /component/:id/chart?slice=…）
UPDATE public.query_charts
SET query_chart_slices = jsonb_build_object(
    'district_stack', jsonb_build_object(
        'query_type', 'three_d',
        'query_chart', $SQLDISTRICT$
WITH base AS (
    SELECT COALESCE(
             CASE
               WHEN sampling_location ~ '(?:臺北市|台北市|新北市).+?區'
                 THEN (regexp_match(sampling_location, '(?:臺北市|台北市|新北市)(.+?區)'))[1]
               ELSE NULL
             END,
             '其他') AS district,
           inspect_result
    FROM traceability_inspection
    WHERE inspect_result IS NOT NULL AND sampling_location IS NOT NULL
),
districts AS (
    SELECT DISTINCT district FROM base
),
counts AS (
    SELECT district,
           inspect_result AS result,
           COUNT(*)::integer AS cnt
    FROM base
    GROUP BY district, inspect_result
)
SELECT d.district AS x_axis,
       r.result AS y_axis,
       COALESCE(c.cnt, 0) AS data
FROM districts d
CROSS JOIN (VALUES ('合格'), ('不合格')) AS r(result)
LEFT JOIN counts c ON c.district = d.district AND c.result = r.result
ORDER BY d.district, CASE WHEN r.result = '合格' THEN 1 ELSE 2 END
$SQLDISTRICT$
    ),
    'product_volume', jsonb_build_object(
        'query_type', 'two_d',
        'query_chart', $SQLPROD$
SELECT COALESCE(NULLIF(TRIM(raw_data->>'ProductName'),''), '(未填品名)') AS x_axis,
       COUNT(*)::integer AS data
FROM traceability_inspection
GROUP BY 1
ORDER BY data DESC
LIMIT 45
$SQLPROD$
    ),
    'inspect_note', jsonb_build_object(
        'query_type', 'two_d',
        'query_chart', $SQLNOTE$
SELECT COALESCE(NULLIF(TRIM(raw_data->>'Note'),''), '(未填)') AS x_axis,
       COUNT(*)::integer AS data
FROM traceability_inspection
WHERE raw_data IS NOT NULL
GROUP BY 1
ORDER BY data DESC
LIMIT 35
$SQLNOTE$
    ),
    'month_pass_rate', jsonb_build_object(
        'query_type', 'two_d',
        'query_chart', $SQLMONTH$
WITH cleaned AS (
    SELECT inspect_result,
           NULLIF(TRIM(raw_data->>'SamplingDate'),'') AS sd
    FROM traceability_inspection
    WHERE inspect_result IS NOT NULL AND raw_data IS NOT NULL
),
parsed AS (
    SELECT inspect_result,
           CASE
             WHEN LENGTH(sd) >= 5 AND sd ~ '^[0-9]+$'
               THEN SUBSTRING(sd FROM 1 FOR 3) || '/' || SUBSTRING(sd FROM 4 FOR 2)
             ELSE NULL
           END AS ym
    FROM cleaned
)
SELECT ym AS x_axis,
       ROUND(
           (100.0 * SUM(CASE WHEN inspect_result = '合格' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0))::numeric,
           1
       )::double precision AS data
FROM parsed
WHERE ym IS NOT NULL
GROUP BY ym
ORDER BY ym
$SQLMONTH$
    ),
    'product_fail_rate', jsonb_build_object(
        'query_type', 'two_d',
        'query_chart', $SQLFAIL$
WITH z AS (
    SELECT COALESCE(NULLIF(TRIM(raw_data->>'ProductName'),''), '(未填品名)') AS product,
           inspect_result
    FROM traceability_inspection
    WHERE inspect_result IS NOT NULL AND raw_data IS NOT NULL
),
agg AS (
    SELECT product,
           COUNT(*)::integer AS n_all,
           SUM(CASE WHEN inspect_result = '不合格' THEN 1 ELSE 0 END)::integer AS n_fail
    FROM z
    GROUP BY product
)
SELECT product AS x_axis,
       ROUND((100.0 * n_fail / NULLIF(n_all, 0))::numeric, 1)::double precision AS data
FROM agg
WHERE n_all >= 5 AND n_fail > 0
ORDER BY data DESC, n_all DESC
LIMIT 18
$SQLFAIL$
    )
)
WHERE "index" = 'traceability_inspection';

-- ===== 加入「食安健康」儀表板（tpe + newtpe） =====

UPDATE public.dashboards
SET components = array_append(components, (SELECT id FROM public.components WHERE "index" = 'traceability_inspection')),
    updated_at = NOW()
WHERE "index" IN ('food_safety_health_tpe', 'food_safety_health_newtpe')
  AND NOT ((SELECT id FROM public.components WHERE "index" = 'traceability_inspection') = ANY(components));

UPDATE public.dashboards
SET components = array_append(components, (SELECT id FROM public.components WHERE "index" = 'cas_product')),
    updated_at = NOW()
WHERE "index" IN ('food_safety_health_tpe', 'food_safety_health_newtpe')
  AND NOT ((SELECT id FROM public.components WHERE "index" = 'cas_product') = ANY(components));

SELECT setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);
