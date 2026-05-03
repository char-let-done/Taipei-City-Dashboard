<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->

<script setup>
import { computed, ref, watch } from "vue";
import VueApexCharts from "vue3-apexcharts";

const props = defineProps([
	"chart_config",
	"activeChart",
	"series",
	"map_config",
	"map_filter",
	"map_filter_on",
]);

const emits = defineEmits(["filterByParam", "clearByParamFilter"]);

const selectedYear = ref("");
const localSeries = ref([]);

const yearOptions = computed(() => {
	const currentYear = new Date().getFullYear();
	const years = [];
	for (let year = currentYear; year >= 2020; year--) {
		years.push(String(year));
	}
	return years;
});

const chartOptions = ref({
	chart: {
		stacked: true,
		toolbar: {
			show: false,
			tools: {
				zoom: false,
			},
		},
	},
	colors: [...props.chart_config.color],
	dataLabels: {
		enabled: false,
	},
	grid: {
		show: false,
	},
	legend: {
		show: (props.series || []).length > 1,
	},
	markers: {
		hover: {
			size: 5,
		},
		size: 3,
		strokeWidth: 0,
	},
	stroke: {
		colors: [...props.chart_config.color],
		curve: "smooth",
		show: true,
		width: 2,
	},
	tooltip: {
		custom: function ({ series, seriesIndex, dataPointIndex, w }) {
			return (
				'<div class="chart-tooltip">' +
				"<h6>" +
				`${parseTime(w.config.series[seriesIndex].data[dataPointIndex].x)}` +
				` - ${w.globals.seriesNames[seriesIndex]}` +
				"</h6>" +
				"<span>" +
				series[seriesIndex][dataPointIndex] +
				` ${props.chart_config.unit}` +
				"</span>" +
				"</div>"
			);
		},
	},
	xaxis: {
		axisBorder: {
			color: "#555",
			height: "0.8",
		},
		axisTicks: {
			show: false,
		},
		crosshairs: {
			show: false,
		},
		labels: {
			datetimeUTC: false,
		},
		tooltip: {
			enabled: false,
		},
		type: "datetime",
	},
	yaxis: {
		min: 0,
	},
});

function parseTime(time) {
	return time.replace("T", " ").replace("+08:00", " ");
}

function updateSeries(newVal) {
	localSeries.value = JSON.parse(JSON.stringify(newVal || []));
	localSeries.value.sort((a, b) => {
		const sumA = a.data.reduce((acc, point) => acc + (point.y || 0), 0);
		const sumB = b.data.reduce((acc, point) => acc + (point.y || 0), 0);
		return sumA - sumB;
	});
}

function handleYearChange() {
	if (!props.map_filter || !props.map_filter_on) return;
	if (selectedYear.value) {
		emits(
			"filterByParam",
			props.map_filter,
			props.map_config,
			selectedYear.value,
			null,
		);
	} else {
		emits("clearByParamFilter", props.map_config);
	}
}

watch(
	() => props.series,
	(newVal) => {
		updateSeries(newVal);
	},
	{ deep: true, immediate: true },
);

watch(
	() => props.map_filter_on,
	(isOn) => {
		if (!isOn && selectedYear.value) {
			selectedYear.value = "";
		}
	},
);
</script>

<template>
  <div
    v-if="activeChart === 'DengueTrendChart'"
    class="denguetrendchart"
  >
    <div
      v-if="map_filter_on"
      class="denguetrendchart-controls"
    >
      <select
        v-model="selectedYear"
        @change="handleYearChange"
      >
        <option value="">
          全部年份
        </option>
        <option
          v-for="year in yearOptions"
          :key="year"
          :value="year"
        >
          {{ year }}
        </option>
      </select>
    </div>
    <VueApexCharts
      width="100%"
      height="260px"
      type="area"
      :options="chartOptions"
      :series="localSeries"
    />
  </div>
</template>

<style scoped>
.denguetrendchart {
	display: flex;
	flex-direction: column;
	gap: 0.5rem;
}

.denguetrendchart-controls {
	display: flex;
	justify-content: flex-end;
}

.denguetrendchart-controls select {
	background: #1f2225;
	border: 1px solid #555;
	border-radius: 4px;
	color: #fff;
	font-size: 0.8rem;
	height: 1.8rem;
	padding: 0 0.5rem;
}
</style>
