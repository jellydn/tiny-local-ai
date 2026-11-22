import { defineConfig } from "vitepress";
import { withMermaid } from "vitepress-plugin-mermaid";

const repo = "https://github.com/jellydn/tiny-local-ai";

// Match GitHub's heading IDs so one set of #anchor links works on GitHub and on this site.
function githubSlug(text: string): string {
	return text
		.trim()
		.toLowerCase()
		.replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, "")
		.replace(/ /g, "-");
}

export default withMermaid(
	defineConfig({
		title: "Tiny Local AI",
		description: "Learn to run AI models on your own computer, starting from zero.",
		base: "/tiny-local-ai/",
		cleanUrls: true,
		lastUpdated: true,
		// The pages are also read on GitHub, where docs/README.md is the folder's start page.
		rewrites: { "README.md": "index.md" },
		markdown: { anchor: { slugify: githubSlug } },
		themeConfig: {
			nav: [
				{ text: "Learning path", link: "/1-understand" },
				{ text: "Glossary", link: "/glossary" },
				{ text: "Worked example", link: "/worked-example-m1-max-32gb" },
				{ text: "FAQ", link: "/faq" },
			],
			sidebar: [
				{ text: "Start here", link: "/" },
				{
					text: "Learning path",
					items: [
						{ text: "1. Understand", link: "/1-understand" },
						{ text: "2. Plan", link: "/2-plan" },
						{ text: "3. Do", link: "/3-do" },
						{ text: "4. Measure", link: "/4-measure" },
						{ text: "5. Optimise", link: "/5-optimise" },
					],
				},
				{
					text: "Reference",
					items: [
						{ text: "Glossary", link: "/glossary" },
						{ text: "Worked example: M1 Max 32 GB", link: "/worked-example-m1-max-32gb" },
						{ text: "FAQ and troubleshooting", link: "/faq" },
					],
				},
				{ text: "Main handbook (GitHub)", link: `${repo}#readme` },
			],
			outline: { level: [2, 3] },
			search: { provider: "local" },
			socialLinks: [{ icon: "github", link: repo }],
			editLink: {
				pattern: `${repo}/edit/main/docs/:path`,
				text: "Edit this page on GitHub",
			},
		},
	}),
);
