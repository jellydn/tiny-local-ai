import type { Theme } from "vitepress";
import { getScrollOffset, inBrowser, useRoute } from "vitepress";
import DefaultTheme from "vitepress/theme";
import { nextTick, onMounted, watch } from "vue";
import "./style.css";

const SETTLE_MS = 5000;
const USER_INPUT = ["wheel", "touchstart", "keydown", "mousedown"] as const;

// Mermaid diagrams render after the browser has scrolled to a #heading link.
// Each diagram that renders above the heading pushes it down, so keep the heading
// in place while the page layout changes, until the user scrolls or the time ends.
function keepHashTargetInView(): void {
	const id = decodeURIComponent(location.hash.slice(1));
	const content = document.querySelector(".vp-doc");
	if (!id || !content) return;

	const scrollToTarget = () => {
		const target = document.getElementById(id);
		if (!target) return;
		const top = target.getBoundingClientRect().top + window.scrollY - getScrollOffset();
		window.scrollTo({ top: Math.max(top, 0) });
	};

	const observer = new ResizeObserver(scrollToTarget);
	const stop = () => {
		observer.disconnect();
		for (const type of USER_INPUT) window.removeEventListener(type, stop);
	};
	observer.observe(content);
	for (const type of USER_INPUT) window.addEventListener(type, stop, { passive: true, once: true });
	setTimeout(stop, SETTLE_MS);
}

export default {
	extends: DefaultTheme,
	setup() {
		if (!inBrowser) return;
		const route = useRoute();
		onMounted(keepHashTargetInView);
		watch(
			() => route.path,
			() => nextTick(keepHashTargetInView),
		);
	},
} satisfies Theme;
