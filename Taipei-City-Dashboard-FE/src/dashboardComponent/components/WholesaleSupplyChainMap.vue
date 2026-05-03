<!-- 市場供應鏈：弧線圖層獨立開關（依 map_config 的 arc 圖層） -->
<script setup>
import { computed, nextTick, ref, watch } from "vue";

const props = defineProps([
	"chart_config",
	"series",
	"map_config",
	"map_filter",
	"map_filter_on",
]);

const emits = defineEmits(["toggleLayer"]);

const arcLayers = computed(() =>
	(props.map_config || []).filter(
		(m) =>
			m.type === "arc" &&
			typeof m.index === "string" &&
			m.index.startsWith("supply_chain_arc_"),
	),
);

function layerKey(layer) {
	return `${layer.index}-${layer.city}`;
}

/** 圖層鍵（index-city）-> 是否顯示；切換臺北/新北時鍵變化會整組重設為關閉 */
const arcVisible = ref({});

watch(
	() => arcLayers.value.map((l) => layerKey(l)).join("|"),
	() => {
		const next = {};
		for (const l of arcLayers.value) {
			next[layerKey(l)] = false;
		}
		arcVisible.value = next;
		nextTick(() => {
			for (const l of arcLayers.value) {
				emits("toggleLayer", props.map_config, l.title, false);
			}
		});
	},
	{ immediate: true },
);

function onArcChange(layer, checked) {
	const k = layerKey(layer);
	arcVisible.value = { ...arcVisible.value, [k]: checked };
	emits("toggleLayer", props.map_config, layer.title, checked);
}
</script>

<template>
  <div class="wsc-map">
    <p class="wsc-map-hint">
      供應路線（弧線）
    </p>
    <ul class="wsc-map-list">
      <li
        v-for="layer in arcLayers"
        :key="`${layer.index}-${layer.city}`"
        class="wsc-map-row"
      >
        <span class="wsc-map-label">{{ layer.title }}</span>
        <label class="wsc-map-switch">
          <input
            type="checkbox"
            :checked="arcVisible[layerKey(layer)] === true"
            @change="onArcChange(layer, $event.target.checked)"
          >
          <span class="wsc-map-slider" />
        </label>
      </li>
    </ul>
  </div>
</template>

<style scoped lang="scss">
.wsc-map {
	width: 100%;
	padding: 0.35rem 0.25rem 0.5rem;
	font-family: "微軟正黑體", "Microsoft JhengHei", sans-serif;
}

.wsc-map-hint {
	margin: 0 0 0.5rem;
	font-size: var(--font-s);
	color: var(--color-complement-text);
}

.wsc-map-list {
	list-style: none;
	margin: 0;
	padding: 0;
	display: flex;
	flex-direction: column;
	gap: 0.45rem;
}

.wsc-map-row {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 0.75rem;
	padding: 0.35rem 0.4rem;
	border: 1px solid var(--color-border);
	border-radius: 6px;
	background: var(--color-component-background);
}

.wsc-map-label {
	flex: 1;
	font-size: var(--font-ms);
	color: var(--color-normal-text);
	text-align: left;
	line-height: 1.35;
}

.wsc-map-switch {
	position: relative;
	width: 2.5rem;
	height: 1.35rem;
	flex-shrink: 0;
	cursor: pointer;

	input {
		opacity: 0;
		width: 0;
		height: 0;
		position: absolute;
	}

	input:checked + .wsc-map-slider {
		background: var(--color-highlight, #2ecc71);
	}

	input:checked + .wsc-map-slider::before {
		transform: translateX(1.15rem);
	}
}

.wsc-map-slider {
	position: absolute;
	inset: 0;
	background: #555;
	border-radius: 999px;
	transition: background 0.2s;

	&::before {
		content: "";
		position: absolute;
		height: 1.05rem;
		width: 1.05rem;
		left: 0.15rem;
		bottom: 0.15rem;
		background: #fff;
		border-radius: 50%;
		transition: transform 0.2s;
	}
}
</style>
