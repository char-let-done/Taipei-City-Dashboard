<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->

<script setup>
import { ref } from "vue";
import bus from "../assets/map/bus.png";
import metro from "../assets/map/metro.png";
import triangle_green from "../assets/map/triangle_green.png";
import triangle_white from "../assets/map/triangle_white.png";
import bike_green from "../assets/map/bike_green.png";
import bike_orange from "../assets/map/bike_orange.png";
import bike_red from "../assets/map/bike_red.png";
import cross_bold from "../assets/map/cross_bold.png";
import cross_normal from "../assets/map/cross_normal.png";
import cctv from "../assets/map/cctv.png";
import live from "../assets/map/live.png";

function svgData(svg) {
	return `data:image/svg+xml,${encodeURIComponent(svg)}`;
}

function pinSvg(color, paths) {
	return svgData(`
		<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
			${paths.replaceAll('fill="#fff"', `fill="${color}"`)}
		</svg>
	`);
}

const customIcons = {
	restaurant_blue: pinSvg("#24B0DD", '<path fill="#fff" d="M10 8h2v7h1V8h2v7.5a3 3 0 0 1-2 2.83V24h-2v-5.67a3 3 0 0 1-2-2.83V8Zm10 0c2.2 1.9 3 4.15 3 7v2h-3v7h-2V8h2Z"/>'),
	basket_blue: pinSvg("#24B0DD", '<path fill="#fff" d="M10.1 13h11.8l-1.2 9H11.3l-1.2-9Zm3.3-4.4 1.6.9-2 3.5h-1.8l2.2-4.4Zm5.2 0 2.2 4.4H19l-2-3.5 1.6-.9ZM13 16v4h1.6v-4H13Zm4.4 0v4H19v-4h-1.6Z"/>'),
	company_green: pinSvg("#56B96D", '<path fill="#fff" d="M9 23V9h9v4h5v10H9Zm3-2h2v-2h-2v2Zm0-4h2v-2h-2v2Zm0-4h2v-2h-2v2Zm4 8h2v-2h-2v2Zm0-4h2v-2h-2v2Zm0-4h2v-2h-2v2Zm4 8h1v-6h-1v6Z"/>'),
	water_tap_blue: pinSvg("#24B0DD", '<path fill="#fff" d="M12 9h7v2h-2v2h4a3 3 0 0 1 3 3v2h-2v-2a1 1 0 0 0-1-1h-6v-4h-3V9Zm3 6v2H8v-2h7Zm-3 4c1.4 1.35 2 2.25 2 3.1a2 2 0 1 1-4 0c0-.85.6-1.75 2-3.1Z"/>'),
	water_drop_green: pinSvg("#56B96D", '<path fill="#fff" d="M16 7c4 4.55 6 7.45 6 10.3A6 6 0 0 1 10 17.3C10 14.45 12 11.55 16 7Zm-3.2 10.7a3.4 3.4 0 0 0 3.5 3.3v-2a1.45 1.45 0 0 1-1.5-1.3h-2Z"/>'),
	gym_green: pinSvg("#56B96D", '<path fill="#fff" d="M7 14h2v-2h2v8H9v-2H7v-4Zm4 1h10v2H11v-2Zm10-3h2v2h2v4h-2v2h-2v-8Z"/>'),
	gym_blue: pinSvg("#24B0DD", '<path fill="#fff" d="M7 14h2v-2h2v8H9v-2H7v-4Zm4 1h10v2H11v-2Zm10-3h2v2h2v4h-2v2h-2v-8Z"/>'),
	eco_cup: pinSvg("#24B0DD", '<path fill="#fff" d="M11 9h9l-1 14h-7L11 9Zm1.5-2h6l.4 2h-6.8l.4-2Zm2 6 .35 7h1.8L17 13h-2.5Z"/>'),
};

const props = defineProps([
	"chart_config",
	"series",
	"map_config",
	"map_filter",
	"map_filter_on",
]);
const emits = defineEmits([
	"filterByParam",
	"filterByLayer",
	"clearByParamFilter",
	"clearByLayerFilter",
	"toggleLayer",
	"fly"
]);

function returnIcon(name) {
	switch (name) {
	case "bus":
		return bus;
	case "metro":
		return metro;
	case "triangle_green":
		return triangle_green;
	case "triangle_white":
		return triangle_white;
	case "bike_green":
		return bike_green;
	case "bike_orange":
		return bike_orange;
	case "bike_red":
		return bike_red;
	case "cross_bold":
		return cross_bold;
	case "cross_normal":
		return cross_normal;
	case "cctv":
		return cctv;
	case "live":
		return live;
	default:
		return "";
	}
}

function returnCustomIcon(name) {
	return customIcons[name] || null;
}

function heatmapGradient(item, index) {
	if (item.icon === "dengue_heatmap") {
		return "linear-gradient(90deg, #ED6A45 0%, #F8CF58 100%)";
	}
	if (item.icon === "valve_heatmap") {
		return "linear-gradient(90deg, #24B0DD 0%, #A7D8FF 55%, #8F98A3 100%)";
	}
	if (item.type === "heatmap" || item.icon === "heatmap") {
		return props.chart_config?.color?.[index]
			? `linear-gradient(90deg, ${props.chart_config.color[index]}, #8F98A3)`
			: "linear-gradient(90deg, #24B0DD, #8F98A3)";
	}
	return null;
}

const selectedIndex = ref(null);
const selectedIndices = ref(new Set());

function handleDataSelection(index) {
	if (!props.map_filter || !props.map_filter_on) {
		return;
	}
	if (props.map_filter.mode === "byLayerToggle") {
		const {name} = props.series[index];
		if (selectedIndices.value.has(index)) {
			selectedIndices.value.delete(index);
			emits("toggleLayer", props.map_config, name, true);
		} else {
			selectedIndices.value.add(index);
			emits("toggleLayer", props.map_config, name, false);
		}
		return;
	}
	if (index !== selectedIndex.value) {
		if (props.map_filter.mode === "byParam") {
			emits(
				"filterByParam",
				props.map_filter,
				props.map_config,
				props.series[index].name,
				null
			);
		} else if (props.map_filter.mode === "byLayer") {
			emits("filterByLayer", props.map_config, props.series[index].name);
		}
		selectedIndex.value = index;
	} else {
		if (props.map_filter.mode === "byParam") {
			emits("clearByParamFilter", props.map_config);
		} else if (props.map_filter.mode === "byLayer") {
			emits("clearByLayerFilter", props.map_config);
		}
		selectedIndex.value = null;
	}
}
</script>

<template>
  <div class="maplegend">
    <div class="maplegend-legend">
      <button
        v-for="(item, index) in series"
        :key="item.name"
        :class="{
          'maplegend-legend-item': true,
          'maplegend-filter': map_filter_on && map_filter,
          'maplegend-selected':
            map_filter_on && (map_filter?.mode === 'byLayerToggle' ? !selectedIndices.has(index) : selectedIndex === index),
        }"
        @click="handleDataSelection(index)"
      >
        <!-- Show different icons for different map types -->
        <img
          v-if="returnCustomIcon(item.icon)"
          class="maplegend-custom-icon"
          :src="returnCustomIcon(item.icon)"
        >
        <div
          v-else-if="heatmapGradient(item, index)"
          class="maplegend-heatmap"
          :style="{ background: heatmapGradient(item, index) }"
        />
        <div
          v-else-if="item.type !== 'symbol'"
          :style="{
            backgroundColor: `${chart_config.color[index]}`,
            height: item.type === 'line' ? '0.4rem' : '1rem',
            borderRadius: item.type === 'circle' ? '50%' : '2px',
          }"
        />
        <img
          v-else
          :src="returnIcon(item.icon)"
        >
        <!-- If there is a value attached, show the value -->
        <div v-if="item.value">
          <h5>{{ item.name }}</h5>
          <h6>{{ item.value }} {{ chart_config.unit }}</h6>
        </div>
        <div v-else>
          <h6>{{ item.name }}</h6>
        </div>
      </button>
    </div>
  </div>
</template>

<style scoped lang="scss">
* {
	margin: 0;
	padding: 0;
	font-family: "微軟正黑體", "Microsoft JhengHei", "Droid Sans", "Open Sans",
		"Helvetica";
	overflow: hidden;
}

button {
	border: none;
	background-color: transparent;
}
.maplegend {
	width: 100%;
	height: 100%;
	display: flex;
	align-items: center;
	justify-content: center;
	margin-top: -var(--font-ms);
	overflow: visible;

	&-legend {
		width: 100%;
		display: grid;
		grid-template-columns: 1fr 1fr;
		column-gap: 0.5rem;
		row-gap: 0.5rem;
		overflow: visible;

		&-item {
			display: flex;
			align-items: center;
			padding: 5px 10px 5px 5px;
			border: 1px solid transparent;
			border-radius: 5px;
			transition: box-shadow 0.2s;
			cursor: auto;

			div:first-child,
			img,
			.maplegend-custom-icon,
			.maplegend-heatmap {
				width: 1.75rem;
				margin-right: 0.6rem;
			}

			.maplegend-custom-icon {
				height: 1.75rem;
				flex-shrink: 0;
			}

			.maplegend-heatmap {
				height: 0.55rem;
				border-radius: 999px;
				flex-shrink: 0;
			}

			h5 {
				color: var(--color-complement-text);
				font-size: 0.75rem;
				text-align: left;
			}

			h6 {
				color: var(--color-normal-text);
				font-size: var(--font-ms);
				font-weight: 400;
				text-align: left;
			}
		}
	}

	&-filter {
		border: 1px solid var(--color-border);
		cursor: pointer;

		&:hover {
			box-shadow: 0px 0px 5px black;
		}
	}

	&-selected {
		box-shadow: 0px 0px 5px black;
	}
}
</style>
