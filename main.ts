// Brainrot Blast hands itself in. This program runs under Node 22 with
// nothing but the standard library, twice, in a fresh container with no
// network: it gathers the Rojo place (game.rbxl), the Luau sources
// (src/), the screenshots and PLAY.json from the folder this file sits
// in, drops them into the output directory, and writes dossier.json,
// the summary the judge reads, using the vendored make.fun library.
//
// The grader fails any output name that does not start with a letter,
// a digit or an underscore, or that holds anything but letters, digits,
// dots, underscores and hyphens. Files like .gitkeep or .DS_Store would
// fail the whole entry, so the copies below skip every name that
// begins with a dot, at any depth.
//
// When you run it by hand, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const repoRoot = fileURLToPath(new URL(".", import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// Skip dotfiles and dot-directories everywhere we copy.
const keepVisible = (path: string): boolean => !basename(path).startsWith(".");

mkdirSync(outputDir, { recursive: true });
copyFileSync(join(repoRoot, "game.rbxl"), join(outputDir, "game.rbxl"));
copyFileSync(join(repoRoot, "PLAY.json"), join(outputDir, "PLAY.json"));
cpSync(join(repoRoot, "src"), join(outputDir, "src"), { recursive: true, filter: keepVisible });
mkdirSync(join(outputDir, "screenshots"), { recursive: true });
if (existsSync(join(repoRoot, "screenshots"))) {
	cpSync(join(repoRoot, "screenshots"), join(outputDir, "screenshots"), { recursive: true, filter: keepVisible });
}

// The scorer's caps, from the bounty's gate: text_max_bytes is the only
// one that shapes the dossier's bytes. The rest make this program fail
// exactly where the scorer would refuse the entry — more than four
// screenshots, one over 256 KiB, a place past 500,000 instances, or
// scripts whose sources pass 8 MiB or whose paths pass 1,048,576 chars.
writeFileSync(
	join(outputDir, "dossier.json"),
	buildDossier(outputDir, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);
