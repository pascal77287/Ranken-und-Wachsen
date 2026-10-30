// Erzeugt Level-Kandidaten für Wachsen & Verflechten und bewertet sie.
//
// Die Ranken werden rückwärts von den Blüten aus gelegt (zufällige Wege mit
// Warnsdorff-Vorliebe); übrig bleibende Felder werden zu Steinen. Kreuzungen
// werden vorab gesetzt und von zwei Ranken geradeaus durchquert. Ein Löser mit
// denselben Regeln und demselben Pruning wie scripts/core/level_solver.gd zählt
// die Lösungen (bis 2); sein Knotenzähler dient als Mass für die Schwierigkeit
// und stimmt mit dem des Prüfwerkzeugs überein.
//
// Aufruf:
//   node tools/generate_levels.mjs BREITE HOEHE RANKEN [--goals N] [--crossings N]
//       [--stones N] [--min-stones N] [--min-nodes N] [--nodes N] [--tries N]
//       [--attempts N] [--seed N] [--min-len N] [--full] [--climb N]
//
// --full: an jeder freien Seite jeder Blüte endet eine Ranke (RANKEN muss passen).
// --climb N: jeden eindeutigen Kandidaten mit N kleinen Änderungen schwerer machen.
// --refine DATEI: statt neu zu erzeugen die Level aus DATEI (JSON-Zeilen) verschärfen.
//
// Ausgabe: jeder eindeutige Kandidat sofort als JSON-Zeile im Level-Format,
// ergänzt um "nodes".

const DIRS = { U: [0, -1], D: [0, 1], L: [-1, 0], R: [1, 0] };
const NEIGH = [[0, -1], [1, 0], [0, 1], [-1, 0]]; // gleiche Reihenfolge wie LevelData.NEIGHBORS
const EMPTY = 0, STONE = 1, START = 2, GOAL = 3, CROSSING = 4;

export function rngFrom(seed) {
	let a = seed >>> 0;
	const next = () => {
		a = (a + 0x6d2b79f5) >>> 0;
		let t = a;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
	return {
		random: next,
		int: (n) => Math.floor(next() * n),
		shuffle(arr) {
			for (let i = arr.length - 1; i > 0; i--) {
				const j = Math.floor(next() * (i + 1));
				[arr[i], arr[j]] = [arr[j], arr[i]];
			}
			return arr;
		},
	};
}

// --- Erzeugen ---------------------------------------------------------------

export function generate(o, rng) {
	const { w, h, k } = o;
	const alive = new Uint8Array(w * h).fill(1);
	const at = (x, y) => (x < 0 || y < 0 || x >= w || y >= h ? -1 : y * w + x);
	const xy = (c) => [c % w, Math.floor(c / w)];
	const step = (c, d) => { const [x, y] = xy(c); return at(x + NEIGH[d][0], y + NEIGH[d][1]); };
	const dist = (a, b) => { const [ax, ay] = xy(a), [bx, by] = xy(b); return Math.abs(ax - bx) + Math.abs(ay - by); };

	// Einige Steine vorab setzen; sie machen Lösungen oft eindeutig.
	const pre = rng.int(Math.floor(o.stones / 2) + 1);
	for (let n = 0; n < pre; n++) alive[rng.int(w * h)] = 0;

	const used = new Uint8Array(w * h);
	const goals = [];
	for (let n = 0; n < o.goals; n++) {
		const g = rng.int(w * h);
		if (!alive[g] || goals.some((q) => dist(g, q) < 3)) return null;
		goals.push(g);
		used[g] = 1;
	}
	// Kreuzungen: nicht am Rand, alle vier Nachbarn begehbar, Abstand zu Blüten und anderen Kreuzungen.
	const crossIndex = new Int8Array(w * h).fill(-1);
	const crossings = [];
	for (let n = 0; n < o.crossings; n++) {
		const c = rng.int(w * h);
		const [x, y] = xy(c);
		if (x === 0 || y === 0 || x === w - 1 || y === h - 1 || !alive[c] || used[c]) return null;
		if ([0, 1, 2, 3].some((d) => !alive[step(c, d)])) return null;
		if (goals.some((g) => dist(g, c) < 2) || crossings.some((q) => dist(q.cell, c) < 2)) return null;
		crossIndex[c] = crossings.length;
		crossings.push({ cell: c, use: [-1, -1] });
	}
	const isFree = (c) => c >= 0 && alive[c] && !used[c] && crossIndex[c] < 0;

	// Jede Blüte bekommt eine Ranke, die übrigen verteilen sich zufällig.
	const entries = goals.map((g) => rng.shuffle([0, 1, 2, 3].map((d) => step(g, d)).filter(isFree)));
	if (entries.some((e) => e.length === 0)) return null;
	// Mit --full endet an jeder freien Seite jeder Blüte eine Ranke; das engt die Lösungen stark ein.
	if (o.full && entries.flat().length !== k) return null;
	const chosen = entries.map((e) => e.pop());
	if (new Set(chosen).size < chosen.length) return null;
	const rest = rng.shuffle(entries.flat().filter((c) => !chosen.includes(c)));
	for (const c of rest) if (chosen.length < k && !chosen.includes(c)) chosen.push(c);
	if (chosen.length < k) return null;
	const paths = chosen.map((c) => { used[c] = 1; return [c]; });

	// Mögliche Schritte von der Spitze aus; eine Kreuzung wird in einem Zug durchquert.
	const moves = (i) => {
		const path = paths[i];
		const t = path[path.length - 1];
		const res = [];
		for (let d = 0; d < 4; d++) {
			const n = step(t, d);
			if (n < 0 || !alive[n]) continue;
			const ci = crossIndex[n];
			if (ci >= 0) {
				const axis = d % 2 === 1 ? 0 : 1;
				const cr = crossings[ci];
				const beyond = step(n, d);
				if (cr.use[axis] === -1 && cr.use[1 - axis] !== i && isFree(beyond)) res.push([n, beyond]);
			} else if (isFree(n)) res.push([n]);
		}
		return res;
	};
	const freeCount = (c) => [0, 1, 2, 3].filter((d) => isFree(step(c, d))).length;

	const active = paths.map((_, i) => i);
	while (active.length) {
		const i = active[rng.int(active.length)];
		const opts = moves(i);
		if (!opts.length) { active.splice(active.indexOf(i), 1); continue; }
		// Warnsdorff: Felder mit wenigen freien Nachbarn zuerst, mit etwas Zufall.
		const scored = opts.map((m) => [freeCount(m[m.length - 1]) + rng.random() * 1.6, m]);
		scored.sort((a, b) => a[0] - b[0]);
		const m = scored[0][1];
		if (m.length === 2) {
			const cr = crossings[crossIndex[m[0]]];
			const d = m[1] - m[0];
			cr.use[Math.abs(d) === 1 ? 0 : 1] = i;
		}
		for (const c of m) { paths[i].push(c); if (crossIndex[c] < 0) used[c] = 1; }
	}
	if (crossings.some((cr) => cr.use.includes(-1))) return null;

	fillDetours(paths, w, h, alive, used, crossIndex, rng);

	const state = { w, h, goals, crossings, paths };
	const stones = stoneCount(state);
	if (stones > o.stones || stones < o.minStones) return null;
	if (paths.some((p) => p.length < o.minLen)) return null;
	return state;
}

// Ein Zustand beschreibt ein Level samt Hauptlösung: pro Ranke die Felder von
// der Blüte weg bis zur Startknospe (ohne Blüte). Alle übrigen Felder sind Steine.
function stoneCount(state) {
	const { w, h } = state;
	const taken = new Uint8Array(w * h);
	for (const p of state.paths) for (const c of p) taken[c] = 1;
	for (const g of state.goals) taken[g] = 1;
	for (const cr of state.crossings) taken[cr.cell] = 1;
	return taken.reduce((n, t) => n + (t ? 0 : 1), 0);
}

function cloneState(st) {
	return { ...st, paths: st.paths.map((p) => p.slice()), crossings: st.crossings.map((cr) => ({ cell: cr.cell, use: cr.use.slice() })) };
}

export function render(state) {
	const { w, h, goals, crossings, paths } = state;
	const xy = (c) => [c % w, Math.floor(c / w)];
	const dist = (a, b) => { const [ax, ay] = xy(a), [bx, by] = xy(b); return Math.abs(ax - bx) + Math.abs(ay - by); };
	const grid = [];
	for (let y = 0; y < h; y++) grid.push(new Array(w).fill("X"));
	for (const p of paths) for (const c of p) { const [x, y] = xy(c); grid[y][x] = "."; }
	for (const g of goals) { const [x, y] = xy(g); grid[y][x] = "Z"; }
	// Startknospen und Kreuzungen in Lesereihenfolge benennen.
	const order = paths.map((_, i) => i).sort((a, b) => paths[a][paths[a].length - 1] - paths[b][paths[b].length - 1]);
	const number = new Map(order.map((i, n) => [i, n + 1]));
	const solution = {};
	for (const i of order) {
		const p = paths[i].slice().reverse();
		p.push(goals.find((g) => dist(g, paths[i][0]) === 1));
		const [sx, sy] = xy(p[0]);
		grid[sy][sx] = String(number.get(i));
		let mv = "";
		for (let n = 1; n < p.length; n++) {
			const [ax, ay] = xy(p[n - 1]), [bx, by] = xy(p[n]);
			mv += Object.keys(DIRS).find((key) => DIRS[key][0] === bx - ax && DIRS[key][1] === by - ay);
		}
		solution[number.get(i)] = mv;
	}
	const level = {};
	if (crossings.length) {
		level.crossings = {};
		crossings.slice().sort((a, b) => a.cell - b.cell).forEach((cr, n) => {
			const [x, y] = xy(cr.cell);
			const letter = "abcdef"[n];
			grid[y][x] = letter;
			level.crossings[letter] = cr.use.map((i) => number.get(i)).sort().join("");
		});
	}
	level.grid = grid.map((r) => r.join(""));
	level.solution = Object.fromEntries(Object.entries(solution).sort());
	return level;
}

// Kleine Änderung, bei der die Hauptlösung gültig bleibt: Startknospe auf einen
// benachbarten Stein verschieben, Startknospe einen Schritt zurücknehmen oder
// zwei benachbarte Steine als Umweg in eine Ranke einbauen.
function mutate(state, o, rng) {
	const st = cloneState(state);
	const { w, h } = st;
	const taken = new Uint8Array(w * h);
	for (const p of st.paths) for (const c of p) taken[c] = 1;
	for (const g of st.goals) taken[g] = 1;
	const cross = new Set(st.crossings.map((cr) => cr.cell));
	for (const c of cross) taken[c] = 1;
	const nbs = (c) => {
		const x = c % w, y = Math.floor(c / w), r = [];
		if (y > 0) r.push(c - w);
		if (x < w - 1) r.push(c + 1);
		if (y < h - 1) r.push(c + w);
		if (x > 0) r.push(c - 1);
		return r;
	};
	const p = st.paths[rng.int(st.paths.length)];
	const kind = rng.int(3);
	if (kind === 0) {
		const opts = nbs(p[p.length - 1]).filter((c) => !taken[c]);
		if (!opts.length) return null;
		p.push(opts[rng.int(opts.length)]);
	} else if (kind === 1) {
		if (p.length <= o.minLen || cross.has(p[p.length - 2])) return null;
		p.pop();
	} else {
		const j = rng.int(p.length - 1);
		const a = p[j], b = p[j + 1];
		if (cross.has(a) || cross.has(b)) return null;
		const opts = [];
		for (const c of nbs(a)) {
			if (taken[c]) continue;
			for (const d of nbs(c)) if (!taken[d] && nbs(b).includes(d)) opts.push([c, d]);
		}
		if (!opts.length) return null;
		p.splice(j + 1, 0, ...opts[rng.int(opts.length)]);
	}
	return stoneCount(st) < o.minStones ? null : st;
}

// Verbessert einen eindeutigen Zustand schrittweise: Änderungen werden
// übernommen, solange das Level eindeutig bleibt und nicht deutlich leichter wird.
export function climb(state, nodes, o, rng) {
	let cur = state, curNodes = nodes, best = state, bestNodes = nodes;
	for (let it = 0; it < o.climb; it++) {
		const cand = mutate(cur, o, rng);
		if (!cand) continue;
		const s = new Solver(render(cand), o.nodes);
		if (s.count(2) !== 1 || s.aborted || s.nodes < curNodes * 0.85) continue;
		cur = cand;
		curNodes = s.nodes;
		if (curNodes > bestNodes) { best = cand; bestNodes = curNodes; }
	}
	return [best, bestNodes];
}

// Baut freie Felder als Umwege ein: Liegen zwei benachbarte freie Felder c, d
// neben aufeinanderfolgenden Rankenfeldern a, b, wird a-b zu a-c-d-b. Freie
// Felder neben dem äusseren Ende verlängern die Ranke. Kreuzungen bleiben gerade.
function fillDetours(paths, w, h, alive, used, crossIndex, rng) {
	const adjacent = (a, b) => Math.abs((a % w) - (b % w)) + Math.abs(Math.floor(a / w) - Math.floor(b / w)) === 1;
	const ok = (c) => c >= 0 && c < w * h && alive[c] && !used[c] && crossIndex[c] < 0;
	let changed = true;
	while (changed) {
		changed = false;
		const free = [];
		for (let c = 0; c < w * h; c++) if (ok(c)) free.push(c);
		rng.shuffle(free);
		for (const path of paths) {
			for (const c of free) {
				if (!ok(c)) continue;
				if (adjacent(path[path.length - 1], c) && crossIndex[path[path.length - 1]] < 0) {
					path.push(c); used[c] = 1; changed = true; continue;
				}
				for (let j = 0; j < path.length - 1; j++) {
					const a = path[j], b = path[j + 1];
					if (crossIndex[a] >= 0 || crossIndex[b] >= 0 || !adjacent(a, c)) continue;
					const d = c + (b - a);
					if (Math.abs(b - a) === 1 && Math.floor(d / w) !== Math.floor(c / w)) continue;
					if (ok(d) && adjacent(d, b) && adjacent(c, d)) {
						path.splice(j + 1, 0, c, d);
						used[c] = used[d] = 1;
						changed = true;
						break;
					}
				}
			}
		}
	}
}

// --- Lösen ------------------------------------------------------------------

class Abort extends Error {}

export class Solver {
	constructor(level, nodeLimit) {
		const grid = level.grid;
		this.h = grid.length;
		this.w = grid[0].length;
		const n = this.w * this.h;
		this.type = new Uint8Array(n);
		this.crossAt = new Int8Array(n).fill(-1);
		this.goals = [];
		this.crossColors = [];
		const starts = {};
		for (let y = 0; y < this.h; y++) {
			for (let x = 0; x < this.w; x++) {
				const ch = grid[y][x], c = y * this.w + x;
				if (ch === "X") this.type[c] = STONE;
				else if (ch === "Z") { this.type[c] = GOAL; this.goals.push(c); }
				else if (ch >= "1" && ch <= "9") { this.type[c] = START; starts[ch] = c; }
				else if (ch >= "a" && ch <= "f") {
					this.type[c] = CROSSING;
					this.crossAt[c] = this.crossColors.length;
					this.crossColors.push([...level.crossings[ch]].map((d) => Number(d) - 1));
				}
			}
		}
		this.starts = Object.keys(starts).sort().map((key) => starts[key]);
		this.k = this.starts.length;
		this.nb = new Int32Array(n * 4);
		for (let c = 0; c < n; c++) {
			const x = c % this.w, y = Math.floor(c / this.w);
			for (let d = 0; d < 4; d++) {
				const nx = x + NEIGH[d][0], ny = y + NEIGH[d][1];
				this.nb[c * 4 + d] = nx < 0 || ny < 0 || nx >= this.w || ny >= this.h ? -1 : ny * this.w + nx;
			}
		}
		this.nodeLimit = nodeLimit;
	}

	count(limit = 2) {
		this.limit = limit;
		this.nodes = 0;
		this.solutions = 0;
		this.aborted = false;
		this.occ = new Int8Array(this.w * this.h).fill(-1);
		this.cross = this.crossColors.map(() => [-1, -1]);
		this.paths = this.starts.map((s, i) => { this.occ[s] = i; return [s]; });
		try { this.extend(0); } catch (e) { if (e instanceof Abort) this.aborted = true; else throw e; }
		return this.solutions;
	}

	isPlain(c) { return this.type[c] === EMPTY || this.type[c] === START; }

	extend(i) {
		if (this.solutions >= this.limit) return;
		if (++this.nodes > this.nodeLimit) throw new Abort();
		const path = this.paths[i];
		const t = path[path.length - 1];
		if (this.type[t] === GOAL) {
			if (this.closedGoals(i) > this.k - i - 1) return;
			if (i + 1 === this.k) { if (this.allCovered()) this.solutions++; return; }
			if (this.feasible(i + 1, this.paths[i + 1][0])) this.extend(i + 1);
			return;
		}
		const prev = path.length >= 2 ? path[path.length - 2] : -1;
		const atCross = this.crossAt[t] >= 0;
		for (let d = 0; d < 4; d++) {
			const n = this.nb[t * 4 + d];
			if (atCross && n - t !== t - prev) continue;
			if (n < 0 || this.type[n] === STONE) continue;
			if (this.type[n] === GOAL) { path.push(n); this.extend(i); path.pop(); continue; }
			const ci = this.crossAt[n];
			if (ci >= 0) {
				const use = this.cross[ci];
				const axis = d % 2 === 1 ? 0 : 1;
				if (this.crossColors[ci].includes(i) && use[axis] === -1 && use[1 - axis] !== i) {
					use[axis] = i; path.push(n); this.extend(i); path.pop(); use[axis] = -1;
				}
				continue;
			}
			if (this.occ[n] !== -1) continue;
			this.occ[n] = i;
			path.push(n);
			if (this.locallyOk(n, i)) this.extend(i);
			path.pop();
			this.occ[n] = -1;
		}
	}

	closedGoals(i) {
		let n = 0;
		for (const g of this.goals) {
			let reached = false;
			for (let k = 0; k <= i; k++) if (this.paths[k][this.paths[k].length - 1] === g) reached = true;
			if (!reached) n++;
		}
		return n;
	}

	allCovered() {
		for (let c = 0; c < this.occ.length; c++) if (this.occ[c] === -1 && this.type[c] === EMPTY) return false;
		return this.cross.every((u) => u[0] !== -1 && u[1] !== -1);
	}

	hasTwoLinks(cell, active, tip) {
		let entries = 0, goal = 0;
		for (let d = 0; d < 4; d++) {
			const m = this.nb[cell * 4 + d];
			if (m < 0 || this.type[m] === STONE) continue;
			if (this.type[m] === GOAL) { goal = 1; continue; }
			if (this.crossAt[m] >= 0) { entries++; continue; }
			const o = this.occ[m];
			if (o === -1 || (m === tip && o === active) || (o > active && this.paths[o].length === 1)) entries++;
		}
		return entries >= 1 && entries + goal >= 2;
	}

	locallyOk(n, i) {
		for (let d = 0; d < 4; d++) {
			const m = this.nb[n * 4 + d];
			if (m >= 0 && this.isPlain(m) && this.occ[m] === -1 && !this.hasTwoLinks(m, i, n)) return false;
		}
		return this.goalEntriesOk(i, n);
	}

	goalEntriesOk(active, tip) {
		let open = 0;
		for (const g of this.goals) {
			for (let d = 0; d < 4; d++) {
				const m = this.nb[g * 4 + d];
				if (m < 0 || this.type[m] === STONE || this.type[m] === GOAL) continue;
				if (this.crossAt[m] >= 0) { open++; continue; }
				const o = this.occ[m];
				if (o === -1 || (m === tip && o === active) || (o > active && this.paths[o].length === 1)) open++;
			}
		}
		return open >= this.k - active;
	}

	feasible(active, tip) {
		for (let c = 0; c < this.occ.length; c++) {
			if (this.isPlain(c) && this.occ[c] === -1 && !this.hasTwoLinks(c, active, tip)) return false;
		}
		return this.goalEntriesOk(active, tip);
	}
}

// Liest ein Level samt Hauptlösung zurück in einen Zustand (für --refine).
export function parseState(level) {
	const h = level.grid.length, w = level.grid[0].length;
	const goals = [], crossings = [], starts = {}, crossAt = new Map();
	level.grid.forEach((row, y) => [...row].forEach((ch, x) => {
		const c = y * w + x;
		if (ch === "Z") goals.push(c);
		else if (ch >= "1" && ch <= "9") starts[ch] = c;
		else if (ch >= "a" && ch <= "f") { crossAt.set(c, crossings.length); crossings.push({ cell: c, use: [-1, -1] }); }
	}));
	const paths = Object.keys(starts).sort().map((key, i) => {
		const p = [starts[key]];
		for (const m of level.solution[key]) p.push(p[p.length - 1] + DIRS[m][0] + DIRS[m][1] * w);
		p.pop(); // Blüte
		p.forEach((c, j) => { if (crossAt.has(c)) crossings[crossAt.get(c)].use[Math.abs(p[j + 1] - c) === 1 ? 0 : 1] = i; });
		return p.reverse();
	});
	return { w, h, goals, crossings, paths };
}

// --- Hauptprogramm ----------------------------------------------------------

function parseArgs(argv) {
	const pos = [], opt = {};
	for (let i = 0; i < argv.length; i++) {
		if (argv[i] === "--full") opt.full = 1;
		else if (argv[i] === "--refine") opt.refine = argv[++i];
		else if (argv[i].startsWith("--")) opt[argv[i].slice(2)] = Number(argv[++i]);
		else pos.push(Number(argv[i]));
	}
	return {
		w: pos[0], h: pos[1], k: pos[2],
		goals: opt.goals ?? 1, crossings: opt.crossings ?? 0,
		stones: opt.stones ?? 3, minStones: opt["min-stones"] ?? 0,
		minNodes: opt["min-nodes"] ?? 0, nodes: opt.nodes ?? 2_000_000,
		climb: opt.climb ?? 0, full: !!opt.full,
		tries: opt.tries ?? 400, attempts: opt.attempts ?? 100_000,
		seed: opt.seed ?? 1, minLen: opt["min-len"] ?? 4, refine: opt.refine,
	};
}

const isMain = (process.argv[1] ?? "").endsWith("generate_levels.mjs");
if (isMain) {
	const o = parseArgs(process.argv.slice(2));
	const rng = rngFrom(o.seed);
	const seen = new Set();
	let found = 0;
	// --refine DATEI: vorhandene Level (JSON-Zeilen) mit --climb weiter verschärfen.
	if (o.refine) {
		const fs = await import("fs");
		for (const line of fs.readFileSync(o.refine, "utf8").split("\n")) {
			if (!line.trim()) continue;
			const lv = JSON.parse(line);
			const state = parseState(lv);
			const s = new Solver(render(state), o.nodes);
			if (s.count(2) !== 1 || s.aborted) continue;
			const [best, nodes] = climb(state, s.nodes, o, rng);
			if (nodes >= o.minNodes) { found++; process.stdout.write(JSON.stringify({ nodes, ...render(best) }) + "\n"); }
		}
		o.attempts = 0;
	}
	for (let n = 0; n < o.attempts && found < o.tries; n++) {
		const state = generate(o, rng);
		if (!state) continue;
		const key = render(state).grid.join("/");
		if (seen.has(key)) continue;
		seen.add(key);
		const s = new Solver(render(state), o.nodes);
		if (s.count(2) !== 1 || s.aborted) continue;
		const [best, nodes] = o.climb ? climb(state, s.nodes, o, rng) : [state, s.nodes];
		if (nodes >= o.minNodes) {
			found++;
			process.stdout.write(JSON.stringify({ nodes, ...render(best) }) + "\n");
		}
	}
	process.stderr.write(`${found} eindeutige Kandidaten\n`);
}
