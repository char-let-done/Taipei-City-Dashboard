<!-- 產銷履歷抽驗：多視角整合（後端 slice 查詢） -->
<script setup>
import { computed, ref, watch } from "vue";
import http from "../../router/axios";
import DonutChart from "./DonutChart.vue";
import ColumnChart from "./ColumnChart.vue";
import TreemapChart from "./TreemapChart.vue";
import BarChart from "./BarChart.vue";

const props = defineProps([
	"chart_config",
	"activeChart",
	"series",
	"map_config",
	"map_filter",
	"map_filter_on",
	"componentId",
	"activeCity",
]);

const MULTI_PALETTE = [
	"#2ECC71",
	"#E74C3C",
	"#3498DB",
	"#9B59B6",
	"#F39C12",
	"#1ABC9C",
	"#E67E22",
	"#34495E",
	"#16A085",
	"#D35400",
	"#8E44AD",
	"#27AE60",
];

const loading = ref(false);
const loadError = ref(null);

const overviewSeries = ref([{ data: [] }]);
const districtPayload = ref({ series: [], categories: [] });
const productTreemapSeries = ref([{ data: [] }]);
const noteDonutSeries = ref([{ data: [] }]);
const monthRateSeries = ref([{ data: [] }]);
const productFailSeries = ref([{ data: [] }]);

const activeCityNorm = computed(
	() => props.activeCity || "taipei",
);

function colorsForCount(n) {
	const len = Math.max(0, Number(n) || 0);
	const out = [];
	for (let i = 0; i < len; i++) {
		out.push(MULTI_PALETTE[i % MULTI_PALETTE.length]);
	}
	return out.length ? out : MULTI_PALETTE;
}

const overviewChartConfig = computed(() => ({
	...props.chart_config,
	color:
		props.chart_config?.color?.length >= 2
			? props.chart_config.color
			: ["#2ECC71", "#E74C3C"],
	unit: props.chart_config?.unit || "件",
}));

const districtChartConfig = computed(() => ({
	...props.chart_config,
	categories: districtPayload.value.categories || [],
	color: ["#2ECC71", "#E74C3C"],
	unit: "件",
}));

const productTreemapConfig = computed(() => ({
	...props.chart_config,
	color: colorsForCount(
		productTreemapSeries.value?.[0]?.data?.length || 12,
	),
	unit: props.chart_config?.unit || "件",
}));

const noteDonutConfig = computed(() => ({
	...props.chart_config,
	color: colorsForCount(noteDonutSeries.value?.[0]?.data?.length || 8),
	unit: props.chart_config?.unit || "件",
}));

const monthRateConfig = computed(() => ({
	...props.chart_config,
	color: ["#3498DB"],
	unit: "%",
}));

const productFailConfig = computed(() => ({
	...props.chart_config,
	color: ["#E74C3C"],
	unit: "%",
}));

const summary = computed(() => {
	const rows = overviewSeries.value?.[0]?.data || [];
	let pass = 0;
	let fail = 0;
	for (const row of rows) {
		const label = row.x;
		const v = Number(row.y);
		if (label === "合格") pass += v;
		else if (label === "不合格") fail += v;
	}
	const total = pass + fail;
	const rate =
		total > 0 ? Math.round((1000 * pass) / total) / 10 : null;
	return { pass, fail, total, rate };
});

async function fetchSlice(slice) {
	const params = {
		city: activeCityNorm.value,
	};
	if (slice) params.slice = slice;
	const res = await http.get(`/component/${props.componentId}/chart`, {
		params,
	});
	return res.data;
}

async function loadAll() {
	if (!props.componentId) return;
	loadError.value = null;
	loading.value = true;
	try {
		const [
			ov,
			ds,
			pv,
			note,
			month,
			failRate,
		] = await Promise.all([
			fetchSlice(null),
			fetchSlice("district_stack"),
			fetchSlice("product_volume"),
			fetchSlice("inspect_note"),
			fetchSlice("month_pass_rate"),
			fetchSlice("product_fail_rate"),
		]);

		overviewSeries.value = ov?.data?.length ? ov.data : [{ data: [] }];
		districtPayload.value = {
			series: ds?.data || [],
			categories: ds?.categories || [],
		};
		productTreemapSeries.value = pv?.data?.length
			? pv.data
			: [{ data: [] }];
		noteDonutSeries.value = note?.data?.length
			? note.data
			: [{ data: [] }];
		monthRateSeries.value = month?.data?.length
			? month.data
			: [{ data: [] }];
		productFailSeries.value = failRate?.data?.length
			? failRate.data
			: [{ data: [] }];
	} catch (e) {
		loadError.value =
			e?.response?.data?.message || e?.message || "載入失敗";
		overviewSeries.value = [{ data: [] }];
		districtPayload.value = { series: [], categories: [] };
		productTreemapSeries.value = [{ data: [] }];
		noteDonutSeries.value = [{ data: [] }];
		monthRateSeries.value = [{ data: [] }];
		productFailSeries.value = [{ data: [] }];
	} finally {
		loading.value = false;
	}
}

watch(
	() => [props.componentId, activeCityNorm.value],
	() => loadAll(),
	{ immediate: true },
);
</script>

<template>
  <div
    v-if="activeChart === 'TraceabilityInspectionRich'"
    class="tir"
  >
    <div
      v-if="loading"
      class="tir-loading"
    >
      載入分析視圖…
    </div>
    <div
      v-else-if="loadError"
      class="tir-error"
    >
      {{ loadError }}
    </div>
    <template v-else>
      <section class="tir-summary">
        <div class="tir-kpi">
          <span class="tir-kpi-label">抽驗件數</span>
          <strong>{{ summary.total }}</strong>
          <span class="tir-kpi-unit">件</span>
        </div>
        <div class="tir-kpi tir-kpi-pass">
          <span class="tir-kpi-label">合格</span>
          <strong>{{ summary.pass }}</strong>
        </div>
        <div class="tir-kpi tir-kpi-fail">
          <span class="tir-kpi-label">不合格</span>
          <strong>{{ summary.fail }}</strong>
        </div>
        <div
          v-if="summary.rate != null"
          class="tir-kpi tir-kpi-rate"
        >
          <span class="tir-kpi-label">合格率</span>
          <strong>{{ summary.rate }}</strong>
          <span class="tir-kpi-unit">%</span>
        </div>
      </section>

      <section class="tir-block">
        <h5 class="tir-title">
          合格／不合格構成
        </h5>
        <DonutChart
          active-chart="DonutChart"
          :chart_config="overviewChartConfig"
          :series="overviewSeries"
          :map_config="map_config"
          :map_filter="map_filter"
          :map_filter_on="map_filter_on"
        />
      </section>

      <section class="tir-block">
        <h5 class="tir-title">
          行政區抽驗件數（堆疊：合格／不合格）
        </h5>
        <p class="tir-hint">
          依抽驗地址萃取縣市後「區」名；無法辨識者列入「其他」。
        </p>
        <ColumnChart
          v-if="districtPayload.categories.length"
          :key="`dist-${districtPayload.categories.join('|')}`"
          active-chart="ColumnChart"
          :chart_config="districtChartConfig"
          :series="districtPayload.series"
          :map_config="map_config"
          :map_filter="map_filter"
          :map_filter_on="map_filter_on"
        />
        <p
          v-else
          class="tir-empty"
        >
          尚無行政區資料
        </p>
      </section>

      <section class="tir-block">
        <h5 class="tir-title">
          熱門抽驗品項（依 ProductName）
        </h5>
        <TreemapChart
          v-if="productTreemapSeries[0]?.data?.length"
          active-chart="TreemapChart"
          :chart_config="productTreemapConfig"
          :series="productTreemapSeries"
          :map_config="map_config"
          :map_filter="map_filter"
          :map_filter_on="map_filter_on"
        />
        <p
          v-else
          class="tir-empty"
        >
          尚無品項資料（raw_data.ProductName）
        </p>
      </section>

      <section class="tir-block">
        <h5 class="tir-title">
          檢驗項目／備註（Note）分布
        </h5>
        <DonutChart
          v-if="noteDonutSeries[0]?.data?.length"
          active-chart="DonutChart"
          :chart_config="noteDonutConfig"
          :series="noteDonutSeries"
          :map_config="map_config"
          :map_filter="map_filter"
          :map_filter_on="map_filter_on"
        />
        <p
          v-else
          class="tir-empty"
        >
          尚無 Note 資料
        </p>
      </section>

      <section class="tir-block">
        <h5 class="tir-title">
          依抽驗年月（民國 yyy/MM）之合格率
        </h5>
        <p class="tir-hint">
          SamplingDate 為民國日期碼（如 1141211）時換算為「年/月」再統計。
        </p>
        <BarChart
          v-if="monthRateSeries[0]?.data?.length"
          active-chart="BarChart"
          :chart_config="monthRateConfig"
          :series="monthRateSeries"
          :map_config="map_config"
          :map_filter="map_filter"
          :map_filter_on="map_filter_on"
        />
        <p
          v-else
          class="tir-empty"
        >
          尚無可追溯月份之資料
        </p>
      </section>

      <section class="tir-block">
        <h5 class="tir-title">
          不合格率偏高品項（至少 5 件）
        </h5>
        <BarChart
          v-if="productFailSeries[0]?.data?.length"
          active-chart="BarChart"
          :chart_config="productFailConfig"
          :series="productFailSeries"
          :map_config="map_config"
          :map_filter="map_filter"
          :map_filter_on="map_filter_on"
        />
        <p
          v-else
          class="tir-empty"
        >
          尚無達門檻之不合格品項統計
        </p>
      </section>
    </template>
  </div>
</template>

<style scoped lang="scss">
.tir {
	width: 100%;
	display: flex;
	flex-direction: column;
	gap: 0.75rem;
	font-family: "微軟正黑體", "Microsoft JhengHei", sans-serif;
	padding-bottom: 0.35rem;
}

.tir-loading,
.tir-error {
	text-align: center;
	padding: 1rem;
	font-size: var(--font-ms);
	color: var(--color-complement-text);
}

.tir-error {
	color: var(--color-highlight-invalid, #e74c3c);
}

.tir-summary {
	display: flex;
	flex-wrap: wrap;
	gap: 0.5rem;
	justify-content: space-between;
}

.tir-kpi {
	flex: 1 1 42%;
	min-width: 7rem;
	padding: 0.45rem 0.55rem;
	border-radius: 6px;
	border: 1px solid var(--color-border);
	background: var(--color-component-background);
	display: flex;
	flex-wrap: wrap;
	align-items: baseline;
	gap: 0.25rem 0.5rem;
}

.tir-kpi-label {
	font-size: var(--font-s);
	color: var(--color-complement-text);
	width: 100%;
}

.tir-kpi strong {
	font-size: var(--font-l);
	color: var(--color-normal-text);
}

.tir-kpi-unit {
	font-size: var(--font-s);
	color: var(--color-complement-text);
}

.tir-kpi-pass strong {
	color: #2ecc71;
}

.tir-kpi-fail strong {
	color: #e74c3c;
}

.tir-kpi-rate strong {
	color: #3498db;
}

.tir-block {
	border: 1px solid var(--color-border);
	border-radius: 8px;
	padding: 0.45rem 0.35rem 0.55rem;
	background: var(--color-component-background);
}

.tir-title {
	margin: 0 0 0.35rem;
	font-size: var(--font-m);
	font-weight: 600;
	color: var(--color-normal-text);
}

.tir-hint {
	margin: 0 0 0.35rem;
	font-size: var(--font-s);
	color: var(--color-complement-text);
	line-height: 1.35;
}

.tir-empty {
	margin: 0.35rem 0 0;
	font-size: var(--font-ms);
	color: var(--color-complement-text);
	text-align: center;
}
</style>
