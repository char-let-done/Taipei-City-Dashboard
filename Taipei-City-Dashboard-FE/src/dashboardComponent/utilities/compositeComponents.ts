export type CompositeFilter = {
	key: string;
	label: string;
	chartTypeOrder?: string[];
};

export type CompositeConfig = {
	filters: CompositeFilter[];
};

export const compositeComponents: Record<string, CompositeConfig> = {
	restaurant_overview: {
		filters: [
			{ key: "traceable_restaurant", label: "溯源餐廳", chartTypeOrder: ["BarChart", "TreemapChart"] },
			{ key: "hygiene_restaurant", label: "衛生餐廳" },
			{ key: "green_restaurant", label: "環保餐廳", chartTypeOrder: ["BarChart", "DistrictChart"] },
			{ key: "muslim_restaurant", label: "穆斯林餐廳" },
		],
	},
};
