"use strict";

// Live map of the game. The data comes as server-sent events from /api/stream (see hub.py):
//   hello (whole state), frame, nodes, scan_started, scan_row, scans_cleared, command, analysis, status, reset,
//   labels (preview of the labeler, paths/labeler.py), paths (all waypoints after the labels were applied).
// A new map layer is one entry in LAYERS (drawn in list order). A new sidebar panel reads from `store`.
// World: x/z is the map, y is up. Positions are [x, y, z] in m.

const TEAM_COLORS = { 0: "#9aa0a6", 1: "#4c9aff", 2: "#ff6b4a", 3: "#b18cff", 4: "#4cd6a0" };
const AIR_TYPES = new Set([4, 5, 13, 14, 17, 18]); // VehicleTypes (BotEnums.lua) that fly
const TRACE_LIFETIME = 2500; // ms a raycast stays on the map
const KILL_LIFETIME = 8000; // ms a kill stays on the map
const TRAIL_SECONDS = 15; // game-seconds of the trails
const MAX_SCAN_CELLS = 4000000; // MAX_CELLS in MapScanner.lua
const MAX_SCAN_SIDE = 16384; // cells per side, bigger canvases fail in the browsers
const HEIGHT_RAMP = [[0, [44, 62, 140]], [0.25, [42, 157, 143]], [0.5, [138, 177, 125]], [0.75, [233, 196, 106]], [1, [244, 241, 222]]];

// =============================================
// Storage (per browser, optional)
// =============================================

function load(key, fallback) {
	try {
		const value = localStorage.getItem("funbots-debug." + key);
		return value === null ? fallback : JSON.parse(value);
	} catch {
		return fallback;
	}
}

function save(key, value) {
	try {
		localStorage.setItem("funbots-debug." + key, JSON.stringify(value));
	} catch {
		// Private mode or blocked storage: settings just don't survive a reload.
	}
}

// =============================================
// State
// =============================================

const store = {
	online: false, // connected to the debug-server
	status: {},
	meta: {},
	time: 0,
	bots: new Map(),
	players: new Map(),
	vehicles: new Map(),
	trails: new Map(), // bot-id -> [[x, z, time]]
	traces: [], // ray-events + arrival (ms)
	kills: [], // kill-events + arrival (ms)
	paths: {}, // path-index -> {points, objectives, inputs, data: {point: {Links, ...}}}
	labels: null, // preview of the labeler (hub.label_paths): {changes, counts, anchors, paths, level, patched}
	labelStatus: null, // {kind: "ok" | "error", text} of the last action of the path-labels panel
	objectives: { flags: [], mcoms: [], stage: 0 }, // see DebugSnapshots.CollectObjectives
	scans: new Map(), // scan-id -> ScanLayer
	navzones: null, // walking networks of the zones (census/navzones.py): {map, spacing, zones: [{points, edges, attach}]}
	findings: [],
	stats: {},
	commands: new Map(), // id -> command (see commands.py)
	extras: {},
	log: [],
	tracesChannel: true,
	botDetails: null, // answer of the "bot" command for the selection
	console: [], // {kind: "in" | "out" | "error", text} of the console-panel
};

const view = {
	cx: 0,
	cz: 0,
	scale: 1, // px per m
	flipZ: load("flipZ", false),
	follow: false,
	selected: null, // {kind: "bot" | "player" | "vehicle", id}
	fitted: false,
	width: 0,
	height: 0,
	dpr: 1,
};

// =============================================
// Height-map of a scan (MapScanner.lua)
// =============================================

function rampColor(t) {
	t = Math.min(1, Math.max(0, t));
	for (let i = 1; i < HEIGHT_RAMP.length; i++) {
		const [t1, c1] = HEIGHT_RAMP[i];
		if (t <= t1) {
			const [t0, c0] = HEIGHT_RAMP[i - 1];
			const f = (t - t0) / (t1 - t0);
			return c0.map((v, k) => v + (c1[k] - v) * f);
		}
	}
	return HEIGHT_RAMP[HEIGHT_RAMP.length - 1][1];
}

class ScanLayer {
	constructor(info) {
		Object.assign(this, { scan: info.scan, x0: info.x0, z0: info.z0, step: info.step, columns: info.columns, rows: info.rows, layers: info.layers || 1 });
		const cells = this.columns * this.rows;
		this.heights = new Float32Array(cells).fill(NaN);
		this.normals = new Float32Array(cells).fill(NaN);
		this.rowsDone = 0;
		this.min = Infinity;
		this.max = -Infinity;
		this.paintedMin = NaN;
		this.paintedMax = NaN;
		this.dirty = new Set();
		this.canvas = document.createElement("canvas");
		this.canvas.width = this.columns;
		this.canvas.height = this.rows;
		this.ctx = this.canvas.getContext("2d");
		this.image = this.ctx.createImageData(this.columns, this.rows);
	}

	static cell(value) {
		if (Array.isArray(value)) value = value.length ? value[0] : false; // top layer
		return value === false || value === null || value === undefined ? NaN : Number(value);
	}

	setRow(row, heights, normals) {
		if (row < 0 || row >= this.rows) return;
		for (let c = 0; c < this.columns; c++) {
			const h = ScanLayer.cell(heights[c]);
			const index = row * this.columns + c;
			this.heights[index] = h;
			this.normals[index] = ScanLayer.cell(normals[c]);
			if (!Number.isNaN(h)) {
				this.min = Math.min(this.min, h);
				this.max = Math.max(this.max, h);
			}
		}
		this.rowsDone++;
		this.dirty.add(row);
	}

	heightAt(x, z) {
		const c = Math.round((x - this.x0) / this.step);
		const r = Math.round((z - this.z0) / this.step);
		if (c < 0 || r < 0 || c >= this.columns || r >= this.rows) return NaN;
		return this.heights[r * this.columns + c];
	}

	refresh() {
		if (!this.dirty.size) return;
		const span = Math.max(1, this.max - this.min);
		// Repaint everything when the height-range grew noticeably, the colors depend on it.
		if (Number.isNaN(this.paintedMin) || Math.abs(this.min - this.paintedMin) > span * 0.05 || Math.abs(this.max - this.paintedMax) > span * 0.05) {
			this.paintedMin = this.min;
			this.paintedMax = this.max;
			for (let r = 0; r < this.rows; r++) this.paintRow(r);
		} else {
			for (const r of this.dirty) this.paintRow(r);
		}
		this.dirty.clear();
		this.ctx.putImageData(this.image, 0, 0);
	}

	paintRow(r) {
		const data = this.image.data;
		const span = Math.max(1, this.paintedMax - this.paintedMin);
		for (let c = 0; c < this.columns; c++) {
			const index = r * this.columns + c;
			const h = this.heights[index];
			const p = index * 4;
			if (Number.isNaN(h)) {
				data[p + 3] = 0;
				continue;
			}
			let rgb = rampColor((h - this.paintedMin) / span);
			const ny = Number.isNaN(this.normals[index]) ? 1 : this.normals[index];
			if (ny < 0.7) rgb = rgb.map((v, k) => v * 0.4 + [230, 60, 60][k] * 0.6); // steeper than ~45°: not walkable
			const shade = 0.55 + 0.45 * Math.max(0, ny);
			data[p] = rgb[0] * shade;
			data[p + 1] = rgb[1] * shade;
			data[p + 2] = rgb[2] * shade;
			data[p + 3] = 210;
		}
	}
}

// =============================================
// Coordinates
// =============================================

const canvas = document.getElementById("map");
const ctx = canvas.getContext("2d");

const sx = (x) => (x - view.cx) * view.scale + view.width / 2;
const sy = (z) => (view.flipZ ? -(z - view.cz) : z - view.cz) * view.scale + view.height / 2;
const wx = (px) => (px - view.width / 2) / view.scale + view.cx;
const wz = (py) => (view.flipZ ? -1 : 1) * (py - view.height / 2) / view.scale + view.cz;

// Direction on the map for a yaw of the bots: (x = -sin(yaw), z = cos(yaw)), see AimEvaluation.lua.
const yawDir = (yaw) => [-Math.sin(yaw), Math.cos(yaw)];

function resize() {
	const rect = canvas.getBoundingClientRect();
	view.dpr = window.devicePixelRatio || 1;
	view.width = rect.width;
	view.height = rect.height;
	canvas.width = Math.round(rect.width * view.dpr);
	canvas.height = Math.round(rect.height * view.dpr);
	requestDraw();
}

function teamColor(team) {
	return TEAM_COLORS[team] || TEAM_COLORS[0];
}

// Colors of the CSS-theme, read once per frame (getComputedStyle is slow).
const theme = {};

function readTheme() {
	const style = getComputedStyle(document.documentElement);
	for (const name of ["text", "muted", "grid", "grid-major", "map-bg", "accent", "ok", "error"]) theme[name] = style.getPropertyValue("--" + name).trim();
}

// =============================================
// Layers
// =============================================

function drawGrid() {
	const target = 90 / view.scale; // m between two lines
	const power = 10 ** Math.floor(Math.log10(target));
	const spacing = [1, 2, 5, 10].map((f) => f * power).find((s) => s >= target);
	const x0 = Math.floor(wx(0) / spacing) * spacing;
	const x1 = wx(view.width);
	const zA = wz(0);
	const zB = wz(view.height);
	const z0 = Math.floor(Math.min(zA, zB) / spacing) * spacing;
	const z1 = Math.max(zA, zB);
	ctx.lineWidth = 1;
	ctx.font = "10px system-ui, sans-serif";
	ctx.fillStyle = theme["muted"];
	for (let x = x0; x <= x1; x += spacing) {
		ctx.strokeStyle = Math.round(x / spacing) % 5 === 0 ? theme["grid-major"] : theme["grid"];
		ctx.beginPath();
		ctx.moveTo(Math.round(sx(x)) + 0.5, 0);
		ctx.lineTo(Math.round(sx(x)) + 0.5, view.height);
		ctx.stroke();
		ctx.fillText(String(Math.round(x)), sx(x) + 3, 11);
	}
	for (let z = z0; z <= z1; z += spacing) {
		ctx.strokeStyle = Math.round(z / spacing) % 5 === 0 ? theme["grid-major"] : theme["grid"];
		ctx.beginPath();
		ctx.moveTo(0, Math.round(sy(z)) + 0.5);
		ctx.lineTo(view.width, Math.round(sy(z)) + 0.5);
		ctx.stroke();
		ctx.fillText(String(Math.round(z)), 3, sy(z) - 3);
	}
}

function drawHeightmap() {
	for (const layer of store.scans.values()) {
		layer.refresh();
		const s = view.scale * view.dpr;
		const sign = view.flipZ ? -1 : 1;
		ctx.save();
		ctx.setTransform(s, 0, 0, sign * s, view.dpr * (view.width / 2 - view.cx * view.scale), view.dpr * (view.height / 2 - sign * view.cz * view.scale));
		ctx.imageSmoothingEnabled = false;
		ctx.drawImage(layer.canvas, layer.x0 - layer.step / 2, layer.z0 - layer.step / 2, layer.columns * layer.step, layer.rows * layer.step);
		ctx.restore();
	}
}

function drawPaths() {
	const dots = view.scale > 2.5;
	ctx.lineWidth = 1.5;
	ctx.strokeStyle = "rgba(160, 170, 190, 0.55)";
	ctx.fillStyle = "rgba(160, 170, 190, 0.8)";
	ctx.font = "10px system-ui, sans-serif";
	for (const [index, path] of Object.entries(store.paths)) {
		const points = path.points;
		if (!points.length) continue;
		ctx.beginPath();
		ctx.moveTo(sx(points[0][0]), sy(points[0][2]));
		for (let i = 1; i < points.length; i++) ctx.lineTo(sx(points[i][0]), sy(points[i][2]));
		ctx.stroke();
		if (dots) {
			for (const p of points) ctx.fillRect(sx(p[0]) - 1.5, sy(p[2]) - 1.5, 3, 3);
		}
		if (view.scale > 0.6) {
			const preview = store.labels && store.labels.paths[index];
			const objectives = preview ? preview.objectives : path.objectives || [];
			const changed = preview && objectives.join() !== (path.objectives || []).join();
			const label = objectives.length ? `${index} ${objectives.join(", ")}` : index;
			if (changed) ctx.fillStyle = theme["accent"];
			ctx.fillText(label, sx(points[0][0]) + 4, sy(points[0][2]) - 4);
			if (changed) ctx.fillStyle = "rgba(160, 170, 190, 0.8)";
		}
	}
}

// Point of a path, [x, y, z].
function pathPoint(path, point) {
	const entry = store.paths[path];
	return entry ? entry.points[point - 1] : undefined;
}

// Links (junctions) of the waypoints, or of the labels while there is a preview: grey the ones that stay, green the
// new ones, red the removed ones. With a preview also the areas of the objectives the labeler used.
// Walking networks of the zones. Point: [x, y, z, clearance, cover, flags], flags 1 = in the zone, 2 = indoors,
// 4 = crouch. Edge: [a, b, length, corners]. Junction with the waypoints: [path, point, network-point, distance, pos].
function drawNavzones() {
	const data = store.navzones;
	if (!data) return;
	const radius = view.scale > 3 ? 3 : 2;
	ctx.lineWidth = 1.2;
	for (const zone of data.zones || []) {
		const points = zone.points || [];
		for (const [a, b, , corners] of zone.edges || []) {
			const p = points[a];
			const q = points[b];
			if (!p || !q) continue;
			ctx.strokeStyle = p[5] & 1 && q[5] & 1 ? "rgba(80, 200, 120, 0.75)" : "rgba(120, 160, 200, 0.5)";
			ctx.beginPath();
			ctx.moveTo(sx(p[0]), sy(p[2]));
			for (const c of corners || []) ctx.lineTo(sx(c[0]), sy(c[2]));
			ctx.lineTo(sx(q[0]), sy(q[2]));
			ctx.stroke();
		}
		ctx.setLineDash([3, 3]);
		ctx.strokeStyle = "rgba(245, 184, 65, 0.8)";
		for (const [, , index, , pos] of zone.attach || []) {
			const p = points[index];
			if (p && pos) line(pos, p);
		}
		ctx.setLineDash([]);
		for (const p of points) {
			ctx.fillStyle = p[5] & 1 ? "#50c878" : "#7890a8";
			ctx.beginPath();
			ctx.arc(sx(p[0]), sy(p[2]), radius, 0, Math.PI * 2);
			ctx.fill();
			if (p[5] & 6) {
				ctx.strokeStyle = p[5] & 4 ? "#f5b841" : "#5aa2ff";
				ctx.beginPath();
				ctx.arc(sx(p[0]), sy(p[2]), radius + 2, 0, Math.PI * 2);
				ctx.stroke();
			}
		}
		if (view.scale > 0.4 && zone.center) {
			ctx.fillStyle = "#50c878";
			ctx.font = "12px system-ui, sans-serif";
			ctx.fillText(`${zone.name}: ${points.length} points`, sx(zone.center[0]) + 8, sy(zone.center[2]) + 16);
		}
	}
}

function drawLinks() {
	const labels = store.labels;
	const size = view.scale > 2 ? 3 : 2;
	const junction = (p) => ctx.fillRect(sx(p[0]) - size, sy(p[2]) - size, 2 * size, 2 * size);
	const link = (a, b, color, dash) => {
		const p = pathPoint(a[0], a[1]);
		const q = pathPoint(b[0], b[1]);
		if (!p || !q) return;
		ctx.strokeStyle = color;
		ctx.fillStyle = color;
		ctx.setLineDash(dash);
		line(p, q);
		junction(p);
		junction(q);
	};
	ctx.lineWidth = 1.5;
	if (labels) {
		ctx.font = "12px system-ui, sans-serif";
		ctx.setLineDash([6, 4]);
		for (const anchor of labels.anchors) {
			ctx.strokeStyle = anchor.source === "game" ? "rgba(90, 162, 255, 0.6)" : "rgba(245, 184, 65, 0.6)";
			ctx.beginPath();
			ctx.arc(sx(anchor.pos[0]), sy(anchor.pos[2]), Math.max(2, anchor.radius * view.scale), 0, Math.PI * 2);
			ctx.stroke();
			ctx.fillStyle = ctx.strokeStyle;
			ctx.fillText(anchor.name, sx(anchor.pos[0]) + 6, sy(anchor.pos[2]) + 14);
		}
	}
	const stays = "rgba(170, 180, 200, 0.75)";
	for (const [index, entry] of Object.entries(labels ? labels.paths : store.paths)) {
		const path = Number(index);
		if (labels) {
			for (const [point, targetPath, targetPoint] of entry.links) {
				if (path < targetPath || (path === targetPath && point < targetPoint)) link([path, point], [targetPath, targetPoint], stays, []);
			}
		} else {
			for (const [point, data] of Object.entries(entry.data || {})) {
				for (const [targetPath, targetPoint] of listOf(data.Links)) {
					if (path < targetPath || (path === targetPath && Number(point) < targetPoint)) link([path, Number(point)], [targetPath, targetPoint], stays, []);
				}
			}
		}
	}
	if (labels) {
		for (const change of labels.changes) {
			if (!change.target) continue;
			if (change.kind === "link-added") link([change.path, change.point], change.target, theme["ok"], []);
			else if (change.kind === "link-removed") link([change.path, change.point], change.target, theme["error"], [4, 3]);
		}
	}
	ctx.setLineDash([]);
}

// A Lua-array from the mod as JS-array (the VU json-encoder sends an empty table as {}).
function listOf(value) {
	return Array.isArray(value) ? value : value ? Object.values(value) : [];
}

function objectiveRadius() {
	return Math.min(40, Math.max(8, 4 * view.scale));
}

function drawFlags() {
	ctx.font = "11px system-ui, sans-serif";
	const radius = objectiveRadius();
	for (const flag of store.objectives.flags) {
		if (!flag.pos) continue;
		const x = sx(flag.pos[0]);
		const y = sy(flag.pos[2]);
		const color = teamColor(flag.team);
		const r = flag.hq ? radius * 0.7 : radius;

		ctx.beginPath();
		ctx.arc(x, y, r, 0, Math.PI * 2);
		ctx.fillStyle = color + (flag.hq ? "18" : "30");
		ctx.fill();
		ctx.lineWidth = 1.5;
		ctx.strokeStyle = color + "88";
		ctx.stroke();
		// How far the flag is raised for its team.
		if (!flag.hq && flag.flag > 0) {
			ctx.beginPath();
			ctx.arc(x, y, r, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * Math.min(100, flag.flag)) / 100);
			ctx.lineWidth = 3;
			ctx.strokeStyle = color;
			ctx.stroke();
		}
		if (flag.attacked) {
			ctx.setLineDash([4, 3]);
			ctx.lineWidth = 2;
			ctx.strokeStyle = "#f5b841";
			ctx.beginPath();
			ctx.arc(x, y, r + 4, 0, Math.PI * 2);
			ctx.stroke();
			ctx.setLineDash([]);
		}

		ctx.fillStyle = theme["text"];
		const label = flagLabel(flag);
		ctx.fillText(label, x - ctx.measureText(label).width / 2, y - r - 5);
	}
}

function drawMcoms() {
	ctx.font = "11px system-ui, sans-serif";
	const size = Math.max(5, Math.min(12, 1.2 * view.scale));
	for (const mcom of store.objectives.mcoms) {
		if (!mcom.pos) continue;
		const x = sx(mcom.pos[0]);
		const y = sy(mcom.pos[2]);
		const armed = mcom.armed !== undefined && mcom.armed !== null;
		const color = mcom.destroyed ? theme["muted"] : armed ? "#ff5d5d" : mcom.active ? "#f5b841" : "#8b94a3";

		if (mcom.active && !mcom.destroyed) {
			ctx.beginPath();
			ctx.arc(x, y, size + 6, 0, Math.PI * 2);
			ctx.fillStyle = color + "30";
			ctx.fill();
		}
		ctx.fillStyle = mcom.destroyed ? "transparent" : color;
		ctx.fillRect(x - size, y - size, size * 2, size * 2);
		ctx.lineWidth = 1.5;
		ctx.strokeStyle = color;
		ctx.strokeRect(x - size, y - size, size * 2, size * 2);
		if (mcom.destroyed) cross(mcom.pos, size, color);

		ctx.fillStyle = theme["text"];
		ctx.fillText(mcomLabel(mcom), x + size + 4, y + 4);
	}
}

function flagLabel(flag) {
	return flag.objective && flag.objective !== flag.name ? `${flag.name} (${flag.objective})` : flag.name;
}

function mcomLabel(mcom) {
	const armed = mcom.armed !== undefined && mcom.armed !== null;
	return `MCOM ${mcom.index}` + (mcom.destroyed ? " destroyed" : armed ? ` armed ${Math.round(mcom.armed)} s` : "");
}

function drawTrails() {
	ctx.lineWidth = 1.5;
	for (const [id, trail] of store.trails) {
		const bot = store.bots.get(id);
		if (!bot || trail.length < 2) continue;
		ctx.strokeStyle = teamColor(bot.team) + "55";
		ctx.beginPath();
		ctx.moveTo(sx(trail[0][0]), sy(trail[0][1]));
		for (let i = 1; i < trail.length; i++) ctx.lineTo(sx(trail[i][0]), sy(trail[i][1]));
		ctx.stroke();
	}
}

function drawTraces(now) {
	store.traces = store.traces.filter((trace) => now - trace.arrival < TRACE_LIFETIME);
	for (const trace of store.traces) {
		const alpha = 1 - (now - trace.arrival) / TRACE_LIFETIME;
		const from = trace.from;
		const to = trace.to;
		if (!from || !to) continue;
		ctx.lineWidth = 1.2;
		if (trace.visible) {
			ctx.strokeStyle = `rgba(62, 207, 142, ${alpha})`;
			line(from, to);
		} else {
			const hit = trace.hit || to;
			ctx.strokeStyle = `rgba(255, 93, 93, ${alpha})`;
			line(from, hit);
			ctx.setLineDash([3, 4]);
			ctx.strokeStyle = `rgba(255, 93, 93, ${alpha * 0.35})`;
			line(hit, to);
			ctx.setLineDash([]);
			cross(hit, 4, `rgba(255, 93, 93, ${alpha})`);
		}
	}
}

function drawKills(now) {
	store.kills = store.kills.filter((kill) => now - kill.arrival < KILL_LIFETIME);
	for (const kill of store.kills) {
		if (!kill.pos) continue;
		const alpha = 1 - (now - kill.arrival) / KILL_LIFETIME;
		ctx.globalAlpha = alpha;
		cross(kill.pos, 6, teamColor(kill.victimTeam));
		ctx.globalAlpha = 1;
	}
}

function drawVehicles() {
	ctx.font = "11px system-ui, sans-serif";
	for (const vehicle of store.vehicles.values()) {
		if (!vehicle.pos) continue;
		const x = sx(vehicle.pos[0]);
		const y = sy(vehicle.pos[2]);
		let fx = vehicle.forward ? vehicle.forward[0] : 0;
		let fz = vehicle.forward ? vehicle.forward[2] : 1;
		const length = Math.hypot(fx, fz) || 1;
		fx /= length;
		fz /= length;
		const air = AIR_TYPES.has(vehicle.type);
		const half = Math.max(6, (air ? 7 : 3.8) * view.scale);
		const width = Math.max(4, (air ? 5 : 1.9) * view.scale);
		// Forward and right in screen-space (z is mirrored with flipZ).
		const dx = fx;
		const dy = view.flipZ ? -fz : fz;
		const rx = -dy;
		const ry = dx;
		const color = teamColor(vehicle.team);
		const occupied = vehicle.occupants && vehicle.occupants.length > 0;

		ctx.beginPath();
		if (air) {
			ctx.moveTo(x + dx * half, y + dy * half);
			ctx.lineTo(x - dx * half + rx * width, y - dy * half + ry * width);
			ctx.lineTo(x - dx * half * 0.5, y - dy * half * 0.5);
			ctx.lineTo(x - dx * half - rx * width, y - dy * half - ry * width);
		} else {
			ctx.moveTo(x + dx * half + rx * width, y + dy * half + ry * width);
			ctx.lineTo(x + dx * half - rx * width, y + dy * half - ry * width);
			ctx.lineTo(x - dx * half - rx * width, y - dy * half - ry * width);
			ctx.lineTo(x - dx * half + rx * width, y - dy * half + ry * width);
		}
		ctx.closePath();
		ctx.fillStyle = occupied ? color + "99" : color + "22";
		ctx.fill();
		ctx.lineWidth = 1.5;
		ctx.strokeStyle = color;
		ctx.stroke();

		// Front-marker and velocity (1 s ahead).
		ctx.beginPath();
		ctx.moveTo(x, y);
		ctx.lineTo(x + dx * (half + 6), y + dy * (half + 6));
		ctx.stroke();
		if (vehicle.velocity) {
			ctx.strokeStyle = color + "88";
			ctx.setLineDash([4, 3]);
			ctx.beginPath();
			ctx.moveTo(x, y);
			ctx.lineTo(sx(vehicle.pos[0] + vehicle.velocity[0]), sy(vehicle.pos[2] + vehicle.velocity[2]));
			ctx.stroke();
			ctx.setLineDash([]);
		}

		if (isSelected("vehicle", vehicle.id)) selectionRing(x, y, half + 5);
		if (view.scale > 0.8 || isSelected("vehicle", vehicle.id)) {
			ctx.fillStyle = theme["text"];
			ctx.fillText(air ? `${vehicle.name} (${Math.round(vehicle.pos[1])} m)` : vehicle.name, x + half + 4, y - half);
		}
	}
}

function drawSoldiers(entries, kind) {
	for (const entry of entries) {
		if (!entry.alive || !entry.pos) continue;
		const x = sx(entry.pos[0]);
		const y = sy(entry.pos[2]);
		const color = teamColor(entry.team);
		const radius = entry.vehicle ? 2.5 : Math.max(3.5, 0.5 * view.scale);

		if (entry.yaw !== undefined && !entry.vehicle) {
			const [dx, dz] = yawDir(entry.yaw);
			const length = Math.max(11, 2.5 * view.scale);
			ctx.strokeStyle = color;
			ctx.lineWidth = 1.5;
			ctx.beginPath();
			ctx.moveTo(x, y);
			ctx.lineTo(x + dx * length, y + (view.flipZ ? -dz : dz) * length);
			ctx.stroke();
		}

		ctx.beginPath();
		if (kind === "player") {
			ctx.moveTo(x, y - radius * 1.5);
			ctx.lineTo(x + radius * 1.5, y);
			ctx.lineTo(x, y + radius * 1.5);
			ctx.lineTo(x - radius * 1.5, y);
			ctx.closePath();
		} else {
			ctx.arc(x, y, radius, 0, Math.PI * 2);
		}
		ctx.fillStyle = color;
		ctx.fill();
		if (kind === "player") {
			ctx.strokeStyle = theme["text"];
			ctx.lineWidth = 1.5;
			ctx.stroke();
		}
		if (entry.stuck) {
			ctx.strokeStyle = "#f5b841";
			ctx.lineWidth = 2;
			ctx.beginPath();
			ctx.arc(x, y, radius + 3, 0, Math.PI * 2);
			ctx.stroke();
		}
		if (isSelected(kind, entry.id)) selectionRing(x, y, radius + 5);
	}
}

function drawNames() {
	ctx.font = "11px system-ui, sans-serif";
	ctx.fillStyle = theme["text"];
	const all = view.scale > 1.5;
	for (const [kind, map] of [["bot", store.bots], ["player", store.players]]) {
		for (const entry of map.values()) {
			if (!entry.alive || !entry.pos || !(all || kind === "player" || isSelected(kind, entry.id))) continue;
			ctx.fillText(entry.name, sx(entry.pos[0]) + 7, sy(entry.pos[2]) - 6);
		}
	}
}

function drawTargets() {
	ctx.lineWidth = 1;
	for (const bot of store.bots.values()) {
		if (!bot.alive || !bot.pos || bot.target === undefined || bot.target < 0) continue;
		const target = store.bots.get(bot.target) || store.players.get(bot.target);
		if (!target || !target.pos) continue;
		const selected = isSelected("bot", bot.id);
		ctx.strokeStyle = selected ? "rgba(255, 93, 93, 0.9)" : "rgba(255, 93, 93, 0.3)";
		line(bot.pos, target.pos);
	}
}

function drawGoal() {
	const bot = view.selected && view.selected.kind === "bot" ? store.bots.get(view.selected.id) : null;
	if (!bot || !bot.pos || !bot.waypoint) return;
	ctx.strokeStyle = "rgba(90, 200, 255, 0.9)";
	ctx.lineWidth = 1.5;
	ctx.setLineDash([5, 4]);
	line(bot.pos, bot.waypoint);
	ctx.setLineDash([]);
	cross(bot.waypoint, 4, "rgba(90, 200, 255, 0.9)");
}

// id, label, default visibility, draw(now)
const LAYERS = [
	{ id: "grid", label: "Grid", on: true, draw: drawGrid },
	{ id: "heightmap", label: "Height-map", on: true, draw: drawHeightmap },
	{ id: "paths", label: "Waypoints", on: true, draw: drawPaths },
	{ id: "links", label: "Links", on: true, draw: drawLinks },
	{ id: "navzones", label: "Zone networks", on: true, draw: drawNavzones },
	{ id: "objectives", label: "Objectives", on: true, draw: () => { drawFlags(); drawMcoms(); } },
	{ id: "trails", label: "Trails", on: true, draw: drawTrails },
	{ id: "traces", label: "Raycasts", on: true, draw: drawTraces },
	{ id: "targets", label: "Targets", on: true, draw: drawTargets },
	{ id: "goal", label: "Bot goal", on: true, draw: drawGoal },
	{ id: "kills", label: "Kills", on: true, draw: drawKills },
	{ id: "vehicles", label: "Vehicles", on: true, draw: drawVehicles },
	{ id: "bots", label: "Bots", on: true, draw: () => drawSoldiers(store.bots.values(), "bot") },
	{ id: "players", label: "Players", on: true, draw: () => drawSoldiers(store.players.values(), "player") },
	{ id: "names", label: "Names", on: true, draw: drawNames },
];
const layerState = load("layers", {});
for (const layer of LAYERS) {
	if (layerState[layer.id] !== undefined) layer.on = layerState[layer.id];
}

// =============================================
// Drawing helpers
// =============================================

function line(a, b) {
	ctx.beginPath();
	ctx.moveTo(sx(a[0]), sy(a[2]));
	ctx.lineTo(sx(b[0]), sy(b[2]));
	ctx.stroke();
}

function cross(p, size, color) {
	const x = sx(p[0]);
	const y = sy(p[2]);
	ctx.strokeStyle = color;
	ctx.lineWidth = 1.5;
	ctx.beginPath();
	ctx.moveTo(x - size, y - size);
	ctx.lineTo(x + size, y + size);
	ctx.moveTo(x + size, y - size);
	ctx.lineTo(x - size, y + size);
	ctx.stroke();
}

function selectionRing(x, y, radius) {
	ctx.strokeStyle = theme["text"];
	ctx.lineWidth = 2;
	ctx.beginPath();
	ctx.arc(x, y, radius, 0, Math.PI * 2);
	ctx.stroke();
}

function isSelected(kind, id) {
	return view.selected !== null && view.selected.kind === kind && view.selected.id === id;
}

// =============================================
// Render loop
// =============================================

let drawRequested = false;

function requestDraw() {
	if (!drawRequested) {
		drawRequested = true;
		requestAnimationFrame(draw);
	}
}

function draw() {
	drawRequested = false;
	const now = performance.now();
	if (view.follow && view.selected) {
		const entity = selectedEntity();
		if (entity && entity.pos) {
			view.cx = entity.pos[0];
			view.cz = entity.pos[2];
		}
	}
	readTheme();
	ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
	ctx.fillStyle = theme["map-bg"];
	ctx.fillRect(0, 0, view.width, view.height);
	for (const layer of LAYERS) {
		if (!layer.on) continue;
		try {
			layer.draw(now);
		} catch (error) {
			console.error(`layer ${layer.id}`, error);
		}
	}
	// Keep animating while something fades out.
	if (store.traces.length || store.kills.length) requestDraw();
}

// =============================================
// Messages of the debug-server
// =============================================

function setEntities(map, list) {
	map.clear();
	for (const entry of list || []) map.set(entry.id, entry);
}

function updateTrails() {
	for (const bot of store.bots.values()) {
		let trail = store.trails.get(bot.id);
		if (!trail) {
			trail = [];
			store.trails.set(bot.id, trail);
		}
		if (!bot.alive || !bot.pos) {
			trail.length = 0;
			continue;
		}
		const last = trail[trail.length - 1];
		if (!last || Math.abs(last[0] - bot.pos[0]) + Math.abs(last[1] - bot.pos[2]) > 0.3) trail.push([bot.pos[0], bot.pos[2], store.time]);
		while (trail.length && store.time - trail[0][2] > TRAIL_SECONDS) trail.shift();
	}
	for (const id of store.trails.keys()) {
		if (!store.bots.has(id)) store.trails.delete(id);
	}
}

function addEvents(events) {
	const now = performance.now();
	for (const event of events || []) {
		if (event.type === "ray") {
			event.arrival = now;
			store.traces.push(event);
		} else if (event.type === "kill") {
			event.arrival = now;
			store.kills.push(event);
			store.log.push(event);
		} else {
			store.log.push(event);
		}
	}
	if (store.traces.length > 3000) store.traces.splice(0, store.traces.length - 3000);
	if (store.log.length > 100) store.log.splice(0, store.log.length - 100);
}

function applyNodes(event) {
	const path = store.paths[event.path] || (store.paths[event.path] = { points: [] });
	if (event.first === 1) {
		path.points = [];
		path.inputs = [];
		path.data = {};
	}
	path.points.push(...(event.points || []));
	path.inputs.push(...listOf(event.inputs));
	for (const [point, data] of listOf(event.data)) path.data[point] = data;
	if (event.objectives) path.objectives = event.objectives;
}

function setObjectives(objectives) {
	const list = (value) => (Array.isArray(value) ? value : value ? Object.values(value) : []);
	store.objectives = objectives ? { flags: list(objectives.flags), mcoms: list(objectives.mcoms), stage: objectives.stage || 0 } : store.objectives;
}

function resetStore() {
	store.objectives = { flags: [], mcoms: [], stage: 0 };
	store.bots.clear();
	store.players.clear();
	store.vehicles.clear();
	store.trails.clear();
	store.traces = [];
	store.kills = [];
	store.paths = {};
	store.labels = null;
	store.navzones = null;
	store.scans.clear();
	store.extras = {};
	store.botDetails = null;
	view.fitted = false;
}

// t is Utilities:GetTime() (Unix-time in s, 1 ms resolution). roundStart is missing after a reload of the mod mid-round,
// both are missing while the mod is older than the debug-server: then the clock-time is shown instead.
function formatDuration(seconds) {
	seconds = Math.max(0, Math.floor(seconds));
	const [h, m, s] = [Math.floor(seconds / 3600), Math.floor(seconds / 60) % 60, seconds % 60];
	const pad = (value) => String(value).padStart(2, "0");
	return h ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

function timesHtml() {
	const { roundStart, modStart } = store.meta;
	const parts = [];
	if (typeof roundStart === "number") parts.push(`<span>round-time <b>${formatDuration(store.time - roundStart)}</b></span>`);
	if (typeof modStart === "number") parts.push(`<span title="since the mod was loaded: the start of the game-server, or the last reload of the mod">mod up <b>${formatDuration(store.time - modStart)}</b></span>`);
	return parts.length ? parts.join("") : `<span>time <b>${new Date(store.time * 1000).toLocaleTimeString()}</b></span>`;
}

const handlers = {
	hello(data) {
		resetStore();
		store.status = data.status || {};
		store.meta = data.meta || {};
		store.time = data.time || 0;
		setEntities(store.bots, data.bots);
		setEntities(store.players, data.players);
		setEntities(store.vehicles, data.vehicles);
		setObjectives(data.objectives);
		for (const [id, points] of Object.entries(data.trails || {})) store.trails.set(Number(id), points.map(([x, z]) => [x, z, store.time]));
		// Old traces fade out quickly.
		const old = performance.now() - TRACE_LIFETIME * 0.7;
		store.traces = (data.traces || []).map((trace) => Object.assign(trace, { arrival: old }));
		store.paths = data.paths || {};
		store.labels = data.labels || null;
		store.navzones = data.navzones || null;
		for (const scan of data.scans || []) {
			const layer = new ScanLayer(scan);
			for (const [row, heights, normals] of scan.rowData) layer.setRow(row, heights, normals);
			store.scans.set(scan.scan, layer);
		}
		store.commands = new Map((data.commands || []).map((command) => [command.id, command]));
		store.findings = data.analysis ? data.analysis.findings : [];
		store.stats = data.analysis ? data.analysis.stats : {};
		store.extras = data.extras || {};
		store.log = data.log || [];
		if (!view.fitted) fit();
	},
	frame(data) {
		store.meta = data.meta || store.meta;
		store.time = data.time;
		setEntities(store.bots, data.bots);
		setEntities(store.players, data.players);
		setEntities(store.vehicles, data.vehicles);
		setObjectives(data.objectives);
		store.extras = data.extras || {};
		updateTrails();
		addEvents(data.events);
		if (!view.fitted && (store.bots.size || store.players.size)) fit();
	},
	nodes_started() {
		store.paths = {};
		store.labels = null;
	},
	nodes: applyNodes,
	labels(data) {
		store.labels = data;
	},
	paths(data) {
		store.paths = data || {};
	},
	navzones(data) {
		store.navzones = data || null;
		if (!view.fitted) fit();
	},
	scan_started(event) {
		store.scans.set(event.scan, new ScanLayer(event));
	},
	scan_row(event) {
		const layer = store.scans.get(event.scan);
		if (layer) layer.setRow(event.row, event.heights || [], event.normals || []);
	},
	scans_cleared(data) {
		for (const scan of data.scans || []) store.scans.delete(scan);
	},
	command(command) {
		store.commands.set(command.id, command);
		const callback = commandCallbacks.get(command.id);
		if (callback && (command.status !== "queued" && command.status !== "sent")) {
			commandCallbacks.delete(command.id);
			callback(command);
		}
	},
	analysis(data) {
		store.findings = data.findings || [];
		store.stats = data.stats || {};
	},
	status(data) {
		store.status = data;
	},
	reset() {
		resetStore();
	},
};

function connect() {
	const source = new EventSource("/api/stream");
	for (const [kind, handler] of Object.entries(handlers)) {
		source.addEventListener(kind, (message) => {
			handler(JSON.parse(message.data));
			store.online = true;
			requestDraw();
			scheduleSidebar();
		});
	}
	source.onerror = () => {
		store.online = false;
		scheduleSidebar();
	};
}

// =============================================
// Commands to the mod
// =============================================

const commandCallbacks = new Map();

async function command(type, args = {}, callback = null) {
	try {
		const response = await fetch("/api/command", {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({ type, args }),
		});
		const data = await response.json();
		if (!response.ok) {
			store.log.push({ type: "error", source: "command " + type, message: data.error });
			scheduleSidebar();
			return;
		}
		store.commands.set(data.id, data);
		if (callback) commandCallbacks.set(data.id, callback);
		scheduleSidebar();
	} catch (error) {
		store.log.push({ type: "error", source: "command " + type, message: String(error) });
		scheduleSidebar();
	}
}

async function clearScans(scan = null) {
	try {
		const response = await fetch("/api/scans/clear", {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(scan === null ? {} : { scan }),
		});
		if (!response.ok) store.log.push({ type: "error", source: "clear scans", message: (await response.json()).error });
	} catch (error) {
		store.log.push({ type: "error", source: "clear scans", message: String(error) });
	}
	scheduleSidebar();
}

// =============================================
// Console: RCON- and chat-commands
// =============================================

const CONSOLE_LINES = 1000;
const CONSOLE_TIMEOUT = 15000; // ms until a missing answer is reported
const CONSOLE_COMMANDS = ["chat", "rcon"]; // bridge-commands the mod needs for the console
const consoleHistory = load("consoleHistory", []);
let historyIndex = consoleHistory.length;

// Returns the (last) entry. An entry with pending = true shows "waiting…" until the answer is there.
function consolePrint(kind, text, pending = false) {
	let entry = null;
	for (const line of String(text).split("\n")) store.console.push((entry = { kind, text: line, pending }));
	if (store.console.length > CONSOLE_LINES) store.console.splice(0, store.console.length - CONSOLE_LINES);
	renderConsole();
	return entry;
}

function consoleDone(entry) {
	entry.pending = false;
	renderConsole();
}

// Splits an RCON-line into command and args, "quoted args" may contain spaces.
function parseRcon(line) {
	const parts = [...line.matchAll(/"([^"]*)"|(\S+)/g)].map((match) => (match[1] !== undefined ? match[1] : match[2]));
	return { command: parts[0], args: parts.slice(1) };
}

// The commands the console knows (GET /api/console): {chat: [...], rcon: [...]}, entries {group, name, args, help}.
let consoleCatalog = { chat: [], rcon: [] };

async function loadConsoleCatalog() {
	try {
		consoleCatalog = await (await fetch("/api/console")).json();
	} catch (error) {
		consolePrint("error", "Could not load the command list: " + error);
	}
}

// =============================================
// Console: completion
// =============================================

const MAX_COMPLETIONS = 15;
// Shown entries: {command, hint}. active = index chosen with the arrow keys, -1 = none.
const completion = { entries: [], active: -1 };

// Chat-commands match with or without "!".
const bareName = (name) => name.toLowerCase().replace(/^!/, "");

function findCommand(name) {
	const needle = bareName(name);
	return (consoleCatalog[$("console-mode").value] || []).find((c) => bareName(c.name) === needle) || null;
}

// While the command is typed: all commands that contain it (the ones that start with it first). Once the command
// is complete or its arguments are typed: the command with its arguments as hint.
function updateCompletion() {
	const value = $("console-input").value;
	const space = value.search(/\s/);
	const word = bareName(space < 0 ? value : value.slice(0, space));
	let entries = [];
	if (word) {
		const exact = findCommand(word);
		if (space >= 0) {
			if (exact) entries = [{ command: exact, hint: true }];
		} else {
			const matches = (consoleCatalog[$("console-mode").value] || [])
				.filter((c) => bareName(c.name).includes(word))
				.sort((a, b) => (bareName(b.name) === word) - (bareName(a.name) === word) || bareName(b.name).startsWith(word) - bareName(a.name).startsWith(word));
			entries = matches.length === 1 && exact ? [{ command: exact, hint: true }] : matches.slice(0, MAX_COMPLETIONS).map((command) => ({ command }));
		}
	}
	completion.entries = entries;
	completion.active = -1;
	renderCompletion();
}

function renderCompletion() {
	const list = $("console-complete");
	list.hidden = !completion.entries.length;
	list.innerHTML = completion.entries.map(({ command: c, hint }, index) =>
		`<li data-index="${index}" class="${hint ? "hint" : ""}${index === completion.active ? " active" : ""}" title="${escapeHtml(c.help)}">` +
		`${escapeHtml(c.name)} <span class="args">${escapeHtml(c.args)}</span>${hint && c.help ? `<br><span class="about">${escapeHtml(c.help)}</span>` : ""}</li>`).join("");
	const active = list.querySelector("li.active");
	if (active) active.scrollIntoView({ block: "nearest" });
}

function hideCompletion() {
	completion.entries = [];
	renderCompletion();
}

// Puts the command into the input, keeps typed arguments.
function applyCompletion(index) {
	const entry = completion.entries[index];
	if (!entry || entry.hint) return false;
	const input = $("console-input");
	const space = input.value.search(/\s/);
	const rest = space < 0 ? "" : input.value.slice(space).trimStart();
	input.value = entry.command.name + (entry.command.args || rest ? " " + rest : "");
	input.focus();
	updateCompletion();
	return true;
}

// Known command in the wrong case (RCON is case-sensitive): use the right one.
function fixCommandCase(line) {
	const space = line.search(/\s/);
	const word = space < 0 ? line : line.slice(0, space);
	const command = findCommand(word);
	return !command || command.name === word ? line : command.name + (space < 0 ? "" : line.slice(space));
}

// Prints the commands of the current mode. Settings are only listed with a filter, there are too many.
function printHelp(filter = "") {
	const mode = $("console-mode").value;
	const needle = filter.toLowerCase().replace(/^!/, "");
	const matches = (consoleCatalog[mode] || []).filter((c) => !needle || `${c.name} ${c.help}`.toLowerCase().includes(needle));
	if (!matches.length) {
		consolePrint("help", `No ${mode}-command matches "${filter}".`);
		return;
	}
	const groups = new Map();
	for (const c of matches) groups.set(c.group, [...(groups.get(c.group) || []), c]);
	const lines = [];
	for (const [group, commands] of groups) {
		if (!needle && group === "fun-bots settings") {
			lines.push({ group, text: `funbots.config.<Setting> [value]  - ${commands.length} settings, list them with: help config` });
			continue;
		}
		lines.push({ group });
		for (const c of commands) lines.push({ command: c });
	}
	for (const line of lines) {
		if (line.command) store.console.push({ kind: "help", html: `  <b>${escapeHtml(line.command.name)}</b> ${escapeHtml(line.command.args)}${line.command.help ? "  - " + escapeHtml(line.command.help) : ""}` });
		else store.console.push({ kind: "help", html: `<b>${escapeHtml(line.group)}</b>${line.text ? ": " + escapeHtml(line.text) : ""}` });
	}
	if (store.console.length > CONSOLE_LINES) store.console.splice(0, store.console.length - CONSOLE_LINES);
	renderConsole();
}

function runConsole() {
	const input = $("console-input");
	let line = input.value.trim();
	if (!line) return;
	const mode = $("console-mode").value;
	hideCompletion();
	if (mode === "rcon") line = fixCommandCase(line);
	const help = line.match(/^(?:help|\?)(?:\s+(.*))?$/i);
	if (help) {
		input.value = "";
		consolePrint("in", "> " + line);
		printHelp(help[1] || "");
		return;
	}
	if (consoleHistory[consoleHistory.length - 1] !== line) consoleHistory.push(line);
	if (consoleHistory.length > 50) consoleHistory.splice(0, consoleHistory.length - 50);
	save("consoleHistory", consoleHistory);
	historyIndex = consoleHistory.length;
	input.value = "";

	// Answers of the mod. Without one after CONSOLE_TIMEOUT, say so instead of staying silent.
	let answered = false;
	let sent = null;
	const answer = (c) => {
		answered = true;
		consoleDone(sent);
		if (c.status !== "ok") {
			consolePrint("error", c.error);
			if (String(c.error).startsWith("unknown command:")) consolePrint("error", modOutdatedHint());
			return;
		}
		const lines = c.result && c.result.lines ? (Array.isArray(c.result.lines) ? c.result.lines : Object.values(c.result.lines)) : [];
		consolePrint("out", lines.length ? lines.join("\n") : "(no answer)");
	};
	if (mode === "rcon") {
		const { command: name, args } = parseRcon(line);
		if (store.status.rcon) {
			rcon([name, ...args], consolePrint("in", `> ${line}   (RCON ${store.status.rcon.address})`, true));
		} else {
			// No RCON-password on the debug-server: the mod runs it, but only knows the commands of the mods.
			sent = consolePrint("in", `> ${line}   (RCON through the mod)`, true);
			command("rcon", { command: name, args }, answer);
			setTimeout(() => answered || consolePrint("error", noModAnswerHint()), CONSOLE_TIMEOUT);
		}
	} else {
		if (!line.startsWith("!")) line = "!" + line;
		const player = $("console-player").value;
		const as = player === "" ? "" : ` (as ${(store.players.get(Number(player)) || {}).name || player})`;
		sent = consolePrint("in", "> " + line + as, true);
		command("chat", player === "" ? { message: line } : { message: line, player: Number(player) }, answer);
		setTimeout(() => answered || consolePrint("error", noModAnswerHint()), CONSOLE_TIMEOUT);
	}
}

function modOutdatedHint() {
	return "The mod running in the game is older than the debug-server and doesn't know this command yet. Reload it: RCON modList.reloadExtensions, or restart the game-server.";
}

function noModAnswerHint() {
	return `No answer from the mod after ${CONSOLE_TIMEOUT / 1000} s.` + (store.status.modConnected ? " It is connected, but busy or stuck?" : " It is not connected to the debug-server.");
}

async function rcon(words, sent) {
	const abort = new AbortController();
	const timer = setTimeout(() => abort.abort(), CONSOLE_TIMEOUT + 10000);
	try {
		const response = await fetch("/api/rcon", {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({ words }),
			signal: abort.signal,
		});
		const data = await response.json();
		if (response.ok) consolePrint("out", data.words.join(" ") || "(empty answer)");
		else consolePrint("error", data.error);
	} catch (error) {
		consolePrint("error", error.name === "AbortError" ? "No answer from the debug-server (RCON), see its terminal." : String(error));
	} finally {
		clearTimeout(timer);
		consoleDone(sent);
	}
}

// What the console can reach right now: the RCON-port and the mod.
function renderConsoleStatus() {
	const rconState = store.status.rcon;
	let rconLine;
	if (!rconState) rconLine = ["warn", "RCON: no password found, commands go through the mod (only the commands of the mods). Start the debug-server with --rcon-password."];
	else if (rconState.ok === true) rconLine = ["ok", `RCON: logged in to ${rconState.address}`];
	else if (rconState.ok === false) rconLine = ["bad", `RCON: ${rconState.state}`];
	else rconLine = ["warn", `RCON: ${rconState.address}, not connected yet`];

	const commands = store.meta.commands ? (Array.isArray(store.meta.commands) ? store.meta.commands : Object.values(store.meta.commands)) : null;
	let modLine;
	if (!store.status.modConnected) modLine = ["bad", "Mod: not connected, chat-commands need it"];
	else if (!commands || !CONSOLE_COMMANDS.every((name) => commands.includes(name))) modLine = ["warn", "Mod: older than the debug-server, chat-commands don't work yet. Reload it (RCON modList.reloadExtensions) or restart the game-server."];
	else modLine = ["ok", "Mod: connected"];

	setHtml($("console-status"), [rconLine, modLine].map(([kind, text]) => `<div class="${kind}">${escapeHtml(text)}</div>`).join(""));
}

function renderConsole() {
	const output = $("console-output");
	output.hidden = !store.console.length;
	const atBottom = output.scrollTop + output.clientHeight >= output.scrollHeight - 4;
	setHtml(output, store.console.map((l) => `<span class="${l.kind}">${l.html !== undefined ? l.html : escapeHtml(l.text)}</span>` + (l.pending ? `<span class="muted">  waiting…</span>` : "")).join("\n"));
	if (atBottom) output.scrollTop = output.scrollHeight;
}

function renderConsoleControls() {
	const mode = $("console-mode").value;
	const select = $("console-player");
	select.hidden = mode !== "chat";
	$("console-input").placeholder = mode === "chat" ? "!spawnbots 5" : store.status.rcon ? "serverInfo" : "funbots.kickAll (via the mod)";
	$("console-mode").title = store.status.rcon ? `RCON goes straight to ${store.status.rcon.address}` : "RCON goes through the mod (only the commands of the mods). Give the debug-server --rcon-password for all commands";
	const players = [...store.players.values()].sort((a, b) => a.name.localeCompare(b.name));
	const options = [`<option value="" title="All permissions, but no soldier">as debug-server</option>`,
		...players.map((p) => `<option value="${p.id}">as ${escapeHtml(p.name)}</option>`)].join("");
	if (select._html !== options) {
		const value = select.value;
		setHtml(select, options);
		select.value = players.some((p) => String(p.id) === value) ? value : "";
	}
	const disabled = store.status.acceptCommands === false;
	$("console-player").disabled = disabled;
	// Direct RCON also works without a mod (e.g. during modList.reloadExtensions) and in replay-mode.
	for (const id of ["console-input", "console-run"]) $(id).disabled = disabled && !(mode === "rcon" && store.status.rcon);
}

// =============================================
// Sidebar
// =============================================

const $ = (id) => document.getElementById(id);
const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

function setHtml(element, html) {
	// Only touch the DOM on changes: keeps scroll-positions and doesn't swallow clicks.
	if (element._html !== html) {
		element._html = html;
		element.innerHTML = html;
	}
}

function formatValue(value) {
	if (Array.isArray(value) && value.length === 3 && value.every((v) => typeof v === "number")) return value.map((v) => v.toFixed(1)).join(", ");
	if (typeof value === "number") return Number.isInteger(value) ? String(value) : value.toFixed(3);
	if (value !== null && typeof value === "object") return JSON.stringify(value);
	return String(value);
}

function kvTable(object) {
	const rows = Object.entries(object)
		.sort(([a], [b]) => a.localeCompare(b))
		.map(([key, value]) => `<tr><td>${escapeHtml(key)}</td><td>${escapeHtml(formatValue(value))}</td></tr>`);
	return `<table class="kv">${rows.join("")}</table>`;
}

function selectedEntity() {
	if (!view.selected) return null;
	const map = { bot: store.bots, player: store.players, vehicle: store.vehicles }[view.selected.kind];
	return map.get(view.selected.id) || null;
}

let sidebarTimer = null;

function scheduleSidebar() {
	if (sidebarTimer === null) sidebarTimer = setTimeout(renderSidebar, 250);
}

function renderSidebar() {
	sidebarTimer = null;
	const status = $("status");
	if (!store.online) {
		status.className = "pill off";
		status.textContent = "debug-server offline";
	} else if (store.status.acceptCommands === false) {
		status.className = "pill replay";
		status.textContent = "replay";
	} else if (store.status.modConnected) {
		status.className = "pill on";
		status.textContent = "mod connected";
	} else {
		status.className = "pill off";
		status.textContent = "waiting for mod";
	}

	const meta = store.meta;
	$("level").textContent = meta.level ? `${meta.level.split("/").pop()} · ${meta.mode} · round ${meta.round} · ${meta.tickrate} Hz · ${meta.version}` : "no level";

	const bots = [...store.bots.values()];
	const teams = {};
	for (const bot of bots) {
		const team = (teams[bot.team] = teams[bot.team] || { alive: 0, total: 0 });
		team.total++;
		if (bot.alive) team.alive++;
	}
	const teamHtml = Object.entries(teams)
		.map(([team, t]) => `<span><span class="dot" style="display:inline-block;background:${teamColor(Number(team))}"></span> team ${team}: <b>${t.alive}</b>/${t.total}</span>`)
		.join("");
	setHtml($("summary"), `${teamHtml}<span>players <b>${store.players.size}</b></span><span>vehicles <b>${store.vehicles.size}</b></span>${timesHtml()}` +
		(store.status.recording ? `<span class="muted small">recording</span>` : ""));

	$("server-raycasts").classList.toggle("on", !!meta.serverRaycasts);
	$("traces-channel").classList.toggle("on", store.tracesChannel);
	for (const id of ["server-raycasts", "traces-channel", "load-nodes", "ping", "scan", "scan-stop", "interval"]) $(id).disabled = store.status.acceptCommands === false;

	const scans = [...store.scans.values()];
	$("scan-clear").disabled = !scans.length;
	setHtml($("scan-info"), scans.map((s) => `<li><span class="grow">scan ${s.scan}: ${s.columns}×${s.rows} @ ${s.step} m, ${Math.round((100 * s.rowsDone) / s.rows)} %</span>` +
		`<button class="icon" data-scan="${s.scan}" title="Remove this scan (stops it if it still runs)">×</button></li>`).join(""));

	renderObjectives();
	renderLabels();
	renderConsoleControls();
	renderConsoleStatus();

	renderSelection();
	renderFindings();
	renderBots(bots);
	renderStats();
	renderCommands();
	setHtml($("raw"), escapeHtml(JSON.stringify({ extras: store.extras, events: store.log.slice(-15) }, null, 1)));
}

function renderSelection() {
	const entity = selectedEntity();
	if (!entity) {
		setHtml($("selection"), view.selected ? "The selection is gone (left the game or was destroyed)." : "Click on a bot, player or vehicle.");
		return;
	}
	let html = "";
	if (view.selected.kind === "bot") {
		html += `<div class="row"><button data-action="details">Full details</button><button data-action="follow" class="toggle ${view.follow ? "on" : ""}">Follow</button></div>`;
	}
	html += kvTable(entity);
	if (store.botDetails && view.selected.kind === "bot" && store.botDetails.id === view.selected.id) {
		html += `<div class="muted small" style="margin-top:6px">All fields of the bot (Bot.lua):</div>` + kvTable(store.botDetails.fields);
	}
	setHtml($("selection"), html);
}

function renderObjectives() {
	const { flags, mcoms, stage } = store.objectives;
	$("objectives-count").textContent = flags.length + mcoms.length ? `(${flags.length + mcoms.length})` : "";
	const flagItems = [...flags]
		.sort((a, b) => a.hq - b.hq || a.name.localeCompare(b.name))
		.map((f) => `<li data-pos="${f.pos}"><span class="dot" style="background:${teamColor(f.team)}"></span>` +
			`<span class="grow">${escapeHtml(flagLabel(f))}</span>` +
			`<span class="muted small">${f.hq ? "HQ" : `${escapeHtml(f.flag)} %`}${f.attacked ? " · attacked" : ""}</span></li>`);
	const mcomItems = mcoms.map((m) => `<li data-pos="${m.pos}"><span class="dot" style="background:${m.destroyed ? "transparent" : m.armed !== undefined && m.armed !== null ? "#ff5d5d" : m.active ? "#f5b841" : "#8b94a3"}"></span>` +
		`<span class="grow">${escapeHtml(mcomLabel(m))}</span><span class="muted small">${m.active ? "active" : ""}</span></li>`);
	const stageItem = mcoms.length ? [`<li class="muted small">rush stage ${escapeHtml(stage)}</li>`] : [];
	setHtml($("objectives"), [...flagItems, ...stageItem, ...mcomItems].join("") || `<li class="muted">none (conquest flags and rush MCOMs show up here)</li>`);
}

const LABEL_KINDS = { warning: "warning", objectives: "objectives", loop: "loop", "link-added": "links added", "link-removed": "links removed" };

function renderLabels() {
	const labels = store.labels;
	const hasPaths = Object.keys(store.paths).length > 0;
	const canApply = !!labels && labels.patched > 0;
	$("label-run").disabled = !hasPaths;
	$("label-apply").disabled = !canApply || store.status.acceptCommands === false;
	$("label-write").disabled = !canApply;
	$("labels-count").textContent = labels ? `(${labels.patched} paths)` : "";

	const status = store.labelStatus;
	let html = status ? `<div class="${status.kind === "error" ? "sev-error" : "status-ok"}">${escapeHtml(status.text)}</div>` : "";
	if (labels) {
		const counts = Object.entries(LABEL_KINDS).filter(([kind]) => labels.counts[kind]).map(([kind, name]) => `${labels.counts[kind]} ${name}`);
		html += `<div class="muted">${escapeHtml(labels.level)}: ${escapeHtml(counts.join(" · ") || "nothing to change")}</div>`;
	}
	setHtml($("label-status"), html);

	const order = Object.keys(LABEL_KINDS);
	const changes = labels ? labels.changes.map((change, index) => [change, index]).sort(([a], [b]) => order.indexOf(a.kind) - order.indexOf(b.kind)) : [];
	setHtml($("label-changes"), changes.slice(0, 500).map(([c, index]) => {
		const where = c.path ? `${c.path}${c.point ? ":" + c.point : ""}${c.target ? " → " + c.target.join(":") : ""}` : "";
		const color = { warning: "sev-warn", "link-added": "status-ok", "link-removed": "sev-error" }[c.kind] || "sev-info";
		return `<li data-index="${index}"><span class="${color}">●</span><span class="muted small">${escapeHtml(where)}</span>` +
			`<span class="grow" title="${escapeHtml(c.message)}">${escapeHtml(c.message)}</span></li>`;
	}).join("") + (changes.length > 500 ? `<li class="muted small">… ${changes.length - 500} more</li>` : ""));
}

async function pathsRequest(action, body = {}) {
	store.labelStatus = { kind: "ok", text: { label: "labeling…", apply: "sending to the game…", write: "writing…" }[action] };
	renderSidebar();
	try {
		const response = await fetch(`/api/paths/${action}`, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(body),
		});
		const data = await response.json();
		if (!response.ok) throw new Error(data.error || response.statusText);
		return data;
	} catch (error) {
		store.labelStatus = { kind: "error", text: String(error.message || error) };
		renderSidebar();
		return null;
	}
}

async function runLabeler() {
	const options = {};
	for (const name of ["relabel", "relink", "crossings", "vehicles", "loops"]) options[name] = $("label-" + name).checked;
	const labels = await pathsRequest("label", options);
	if (!labels) return;
	store.labels = labels;
	store.labelStatus = { kind: "ok", text: "Preview on the map: green links are new, red ones removed. Nothing changed in the game yet." };
	renderSidebar();
	requestDraw();
}

async function applyLabels() {
	const save = $("label-save").checked;
	const result = await pathsRequest("apply", { save });
	if (!result) return;
	store.labelStatus = result.status === "ok"
		? { kind: "ok", text: `Applied to ${result.result.paths} paths${result.result.saved ? ", saving in mod.db" : " (not saved)"}.` }
		: { kind: "error", text: `The mod refused: ${result.error || result.status}` };
	renderSidebar();
	requestDraw();
}

async function writeLabels() {
	const result = await pathsRequest("write");
	if (!result) return;
	store.labelStatus = { kind: "ok", text: `Wrote ${result.paths} paths into ${result.file}` };
	renderSidebar();
}

function renderFindings() {
	const findings = store.findings;
	$("findings-count").textContent = findings.length ? `(${findings.length})` : "";
	setHtml($("findings"), findings.length
		? findings.map((f, index) => `<li data-index="${index}"><span class="sev-${escapeHtml(f.severity)}">●</span><span class="grow" title="${escapeHtml(f.message)}">${escapeHtml(f.message)}</span><span class="muted small">${escapeHtml(f.analyzer)}</span></li>`).join("")
		: `<li class="muted">nothing found</li>`);
}

function renderBots(bots) {
	const filter = $("bot-filter").value.trim().toLowerCase();
	const shown = bots
		.filter((b) => !filter || `${b.name} ${b.state} ${b.action} team${b.team} ${b.vehicle || ""}`.toLowerCase().includes(filter))
		.sort((a, b) => a.team - b.team || a.name.localeCompare(b.name));
	$("bots-count").textContent = `(${bots.length})`;
	setHtml($("bots"), shown.map((b) => `<li data-id="${b.id}" class="${isSelected("bot", b.id) ? "selected" : ""}">` +
		`<span class="dot" style="background:${teamColor(b.team)};opacity:${b.alive ? 1 : 0.3}"></span>` +
		`<span class="grow">${escapeHtml(b.name)}</span>` +
		`<span class="muted small">${escapeHtml(b.alive ? b.vehicle || b.state || "" : "dead")}</span></li>`).join(""));
}

function renderStats() {
	setHtml($("stats"), Object.entries(store.stats)
		.map(([name, values]) => `<div class="stats-group"><h3>${escapeHtml(name)}</h3>${kvTable(values)}</div>`)
		.join("") || `<span class="muted">no data yet</span>`);
}

function renderCommands() {
	const commands = [...store.commands.values()].sort((a, b) => b.id - a.id).slice(0, 25);
	setHtml($("commands"), commands.map((c) => {
		const result = c.error ? c.error : c.result !== null && c.result !== undefined ? JSON.stringify(c.result) : "";
		return `<li title="${escapeHtml(result)}"><span class="status-${c.status}">${c.status}</span><span>${escapeHtml(c.type)}</span><span class="grow muted small">${escapeHtml(result)}</span></li>`;
	}).join("") || `<li class="muted">none yet</li>`);
}

// =============================================
// Interaction
// =============================================

function fit() {
	const points = [];
	for (const map of [store.bots, store.players, store.vehicles]) {
		for (const entry of map.values()) if (entry.pos) points.push(entry.pos);
	}
	if (!points.length) {
		for (const objective of [...store.objectives.flags, ...store.objectives.mcoms]) if (objective.pos) points.push(objective.pos);
	}
	if (!points.length) {
		for (const path of Object.values(store.paths)) points.push(...path.points);
	}
	if (!points.length && store.navzones) {
		for (const zone of store.navzones.zones || []) points.push(...(zone.points || []));
	}
	if (!points.length || !view.width) return;
	const xs = points.map((p) => p[0]);
	const zs = points.map((p) => p[2]);
	const minX = Math.min(...xs);
	const maxX = Math.max(...xs);
	const minZ = Math.min(...zs);
	const maxZ = Math.max(...zs);
	view.cx = (minX + maxX) / 2;
	view.cz = (minZ + maxZ) / 2;
	view.scale = Math.min(20, Math.max(0.02, Math.min(view.width / (maxX - minX + 60), view.height / (maxZ - minZ + 60))));
	view.fitted = true;
	requestDraw();
}

function select(selection) {
	view.selected = selection;
	store.botDetails = null;
	if (!selection) view.follow = false;
	requestDraw();
	renderSidebar();
}

function focusOn(pos) {
	view.cx = pos[0];
	view.cz = pos[2];
	view.scale = Math.max(view.scale, 3);
	requestDraw();
}

function entityAt(px, py, radius) {
	let best = null;
	let bestDistance = radius;
	for (const [kind, map] of [["bot", store.bots], ["player", store.players], ["vehicle", store.vehicles]]) {
		for (const entry of map.values()) {
			if (!entry.pos || (kind !== "vehicle" && !entry.alive)) continue;
			const distance = Math.hypot(sx(entry.pos[0]) - px, sy(entry.pos[2]) - py);
			if (distance < bestDistance) {
				bestDistance = distance;
				best = { kind, id: entry.id, entry };
			}
		}
	}
	return best;
}

function objectiveAt(px, py) {
	if (!LAYERS.find((layer) => layer.id === "objectives").on) return null;
	const radius = objectiveRadius();
	for (const mcom of store.objectives.mcoms) {
		if (mcom.pos && Math.hypot(sx(mcom.pos[0]) - px, sy(mcom.pos[2]) - py) < 12) {
			return { label: mcomLabel(mcom), detail: `${mcom.name} · ${mcom.active ? "active" : "inactive"} · y ${Math.round(mcom.pos[1])}` };
		}
	}
	for (const flag of store.objectives.flags) {
		if (flag.pos && Math.hypot(sx(flag.pos[0]) - px, sy(flag.pos[2]) - py) < radius) {
			const state = flag.hq ? "HQ" : `flag ${flag.flag} %${flag.controlled ? " · controlled" : ""}${flag.attacked ? " · attacked" : ""}`;
			return { label: flagLabel(flag), detail: `team ${flag.team} · ${state} · y ${Math.round(flag.pos[1])}` };
		}
	}
	return null;
}

function setupInteraction() {
	let drag = null;
	canvas.addEventListener("mousedown", (event) => {
		drag = { x: event.clientX, y: event.clientY, cx: view.cx, cz: view.cz, moved: false };
		canvas.classList.add("dragging");
	});
	window.addEventListener("mousemove", (event) => {
		const rect = canvas.getBoundingClientRect();
		const px = event.clientX - rect.left;
		const py = event.clientY - rect.top;
		if (drag) {
			const dx = event.clientX - drag.x;
			const dy = event.clientY - drag.y;
			if (Math.abs(dx) + Math.abs(dy) > 3) drag.moved = true;
			if (drag.moved) {
				view.follow = false;
				view.cx = drag.cx - dx / view.scale;
				view.cz = drag.cz - (view.flipZ ? -dy : dy) / view.scale;
				requestDraw();
			}
		}
		if (px < 0 || py < 0 || px > rect.width || py > rect.height) {
			$("tooltip").hidden = true;
			return;
		}
		let coords = `x ${wx(px).toFixed(1)}  z ${wz(py).toFixed(1)}`;
		for (const layer of store.scans.values()) {
			const h = layer.heightAt(wx(px), wz(py));
			if (!Number.isNaN(h)) coords += `  y ${h.toFixed(1)}`;
		}
		$("coords").textContent = coords + `  ·  ${view.scale.toFixed(2)} px/m`;
		const hover = drag ? null : entityAt(px, py, 12);
		const objective = drag || hover ? null : objectiveAt(px, py);
		const tooltip = $("tooltip");
		if (objective) {
			tooltip.innerHTML = `<b>${escapeHtml(objective.label)}</b><br><span class="muted">${escapeHtml(objective.detail)}</span>`;
			tooltip.style.left = px + 14 + "px";
			tooltip.style.top = py + 10 + "px";
			tooltip.hidden = false;
		} else if (hover) {
			const e = hover.entry;
			const detail = hover.kind === "vehicle"
				? `${e.occupants.length} occupants · health ${e.health}`
				: `${e.vehicle ? e.vehicle + " · " : ""}${e.state || ""} ${e.action && e.action !== "NoActionActive" ? "· " + e.action : ""} · hp ${e.health}`;
			tooltip.innerHTML = `<b>${escapeHtml(e.name)}</b><br><span class="muted">${escapeHtml(detail)}</span>`;
			tooltip.style.left = px + 14 + "px";
			tooltip.style.top = py + 10 + "px";
			tooltip.hidden = false;
		} else {
			tooltip.hidden = true;
		}
	});
	window.addEventListener("mouseup", (event) => {
		if (!drag) return;
		canvas.classList.remove("dragging");
		if (!drag.moved) {
			const rect = canvas.getBoundingClientRect();
			const hit = entityAt(event.clientX - rect.left, event.clientY - rect.top, 14);
			select(hit ? { kind: hit.kind, id: hit.id } : null);
		}
		drag = null;
	});
	canvas.addEventListener("wheel", (event) => {
		event.preventDefault();
		const rect = canvas.getBoundingClientRect();
		const px = event.clientX - rect.left;
		const py = event.clientY - rect.top;
		const beforeX = wx(px);
		const beforeZ = wz(py);
		view.scale = Math.min(60, Math.max(0.02, view.scale * Math.exp(-event.deltaY * 0.0015)));
		if (!view.follow) {
			view.cx += beforeX - wx(px);
			view.cz += beforeZ - wz(py);
		}
		requestDraw();
	}, { passive: false });
	window.addEventListener("keydown", (event) => {
		if (event.target.tagName === "INPUT" || event.target.tagName === "SELECT") return;
		if (event.key === "f") fit();
		if (event.key === "c" && view.selected) {
			view.follow = !view.follow;
			renderSidebar();
			requestDraw();
		}
		if (event.key === "Escape") select(null);
	});
	window.addEventListener("resize", resize);
}

function setupControls() {
	const layers = $("layers");
	for (const layer of LAYERS) {
		const button = document.createElement("button");
		button.className = "chip" + (layer.on ? " on" : "");
		button.textContent = layer.label;
		button.addEventListener("click", () => {
			layer.on = !layer.on;
			button.classList.toggle("on", layer.on);
			layerState[layer.id] = layer.on;
			save("layers", layerState);
			requestDraw();
		});
		layers.appendChild(button);
	}

	$("fit").addEventListener("click", fit);
	$("flip").addEventListener("click", () => {
		view.flipZ = !view.flipZ;
		save("flipZ", view.flipZ);
		requestDraw();
	});
	$("follow").addEventListener("click", () => {
		view.follow = !!view.selected && !view.follow;
		renderSidebar();
		requestDraw();
	});
	$("clear-traces").addEventListener("click", () => {
		store.traces = [];
		requestDraw();
	});

	$("server-raycasts").addEventListener("click", () => command("server_raycasts", { enabled: !store.meta.serverRaycasts }));
	$("traces-channel").addEventListener("click", () =>
		command("channels", { traces: !store.tracesChannel }, (c) => {
			if (c.status === "ok") store.tracesChannel = !!c.result.traces;
			renderSidebar();
		}));
	$("interval").addEventListener("change", (event) => command("interval", { seconds: Number(event.target.value) }));
	$("load-nodes").addEventListener("click", () => command("nodes"));
	const labelOptions = load("labelOptions", {});
	for (const name of ["relabel", "relink", "crossings", "vehicles", "loops", "save"]) {
		const box = $("label-" + name);
		if (labelOptions[name] !== undefined) box.checked = labelOptions[name];
		box.addEventListener("change", () => {
			labelOptions[name] = box.checked;
			save("labelOptions", labelOptions);
		});
	}
	$("label-run").addEventListener("click", runLabeler);
	$("label-apply").addEventListener("click", applyLabels);
	$("label-write").addEventListener("click", writeLabels);
	$("label-changes").addEventListener("click", (event) => {
		const item = event.target.closest("li[data-index]");
		const change = item && store.labels && store.labels.changes[Number(item.dataset.index)];
		if (!change) return;
		const pos = pathPoint(change.path, change.point || 1);
		if (pos) focusOn(pos);
	});
	$("ping").addEventListener("click", () => command("ping"));
	$("scan-stop").addEventListener("click", () => command("scan_stop"));
	$("scan-clear").addEventListener("click", () => clearScans());
	$("console-mode").value = load("consoleMode", "chat");
	$("console-mode").addEventListener("change", (event) => {
		save("consoleMode", event.target.value);
		renderConsoleControls();
		updateCompletion();
	});
	$("console-help").addEventListener("click", () => printHelp($("console-input").value.trim()));
	loadConsoleCatalog();
	$("console-form").addEventListener("submit", (event) => {
		event.preventDefault();
		runConsole();
	});
	const consoleInput = $("console-input");
	consoleInput.addEventListener("input", updateCompletion);
	consoleInput.addEventListener("focus", updateCompletion);
	consoleInput.addEventListener("blur", hideCompletion);
	consoleInput.addEventListener("keydown", (event) => {
		const choices = completion.entries.filter((entry) => !entry.hint).length;
		if (event.key === "Tab" && choices) {
			// The chosen command, or the first one.
			event.preventDefault();
			applyCompletion(Math.max(0, completion.active));
		} else if (event.key === "Enter" && completion.active >= 0 && applyCompletion(completion.active)) {
			event.preventDefault(); // takes the chosen command, the next Enter runs it
		} else if (event.key === "Escape" && completion.entries.length) {
			event.preventDefault();
			event.stopPropagation();
			hideCompletion();
		} else if ((event.key === "ArrowUp" || event.key === "ArrowDown") && choices) {
			event.preventDefault();
			// -1 (nothing chosen) -> 0 -> ... -> last -> -1
			if (event.key === "ArrowDown") completion.active = completion.active < choices - 1 ? completion.active + 1 : -1;
			else completion.active = completion.active > -1 ? completion.active - 1 : choices - 1;
			renderCompletion();
		} else if (event.key === "ArrowUp" || event.key === "ArrowDown") {
			// History, while no command is suggested.
			event.preventDefault();
			historyIndex = Math.max(0, Math.min(consoleHistory.length, historyIndex + (event.key === "ArrowUp" ? -1 : 1)));
			consoleInput.value = consoleHistory[historyIndex] || "";
		}
	});
	// mousedown: the input would lose the focus (and hide the list) before a click.
	$("console-complete").addEventListener("mousedown", (event) => {
		event.preventDefault();
		const item = event.target.closest("li[data-index]");
		if (item) applyCompletion(Number(item.dataset.index));
	});
	$("scan-info").addEventListener("click", (event) => {
		const button = event.target.closest("button[data-scan]");
		if (button) clearScans(Number(button.dataset.scan));
	});
	$("scan").addEventListener("click", () => {
		const step = Math.max(0.25, Number($("scan-step").value) || 2);
		const layerCount = Math.max(1, Math.round(Number($("scan-layers").value) || 1));
		const perUpdate = Math.max(1, Math.round(Number($("scan-speed").value) || 100));
		const xA = wx(0);
		const xB = wx(view.width);
		const zA = wz(0);
		const zB = wz(view.height);
		const columns = Math.floor(Math.abs(xB - xA) / step) + 1;
		const rows = Math.floor(Math.abs(zB - zA) / step) + 1;
		const cells = columns * rows;
		if (cells > MAX_SCAN_CELLS || columns > MAX_SCAN_SIDE || rows > MAX_SCAN_SIDE) {
			alert(`${columns.toLocaleString()} × ${rows.toLocaleString()} cells are too many (max ${MAX_SCAN_CELLS.toLocaleString()}, ${MAX_SCAN_SIDE.toLocaleString()} per side). Zoom in or use a bigger step.`);
			return;
		}
		if (cells > 1000000 && !confirm(`Scan ${cells.toLocaleString()} cells (${layerCount} layer(s), ${perUpdate} rays per update)? This takes a while.`)) return;
		command("scan", { x0: xA, z0: zA, x1: xB, z1: zB, step, layers: layerCount, perUpdate });
	});

	$("bot-filter").addEventListener("input", () => renderSidebar());
	$("bots").addEventListener("click", (event) => {
		const item = event.target.closest("li[data-id]");
		if (!item) return;
		const id = Number(item.dataset.id);
		select({ kind: "bot", id });
		const bot = store.bots.get(id);
		if (bot && bot.pos) focusOn(bot.pos);
	});
	$("objectives").addEventListener("click", (event) => {
		const item = event.target.closest("li[data-pos]");
		if (item && item.dataset.pos) focusOn(item.dataset.pos.split(",").map(Number));
	});
	$("findings").addEventListener("click", (event) => {
		const item = event.target.closest("li[data-index]");
		if (!item) return;
		const finding = store.findings[Number(item.dataset.index)];
		if (!finding) return;
		if (finding.bot !== null && finding.bot !== undefined) {
			select({ kind: store.players.has(finding.bot) ? "player" : "bot", id: finding.bot });
		}
		if (finding.pos) focusOn(finding.pos);
	});
	$("selection").addEventListener("click", (event) => {
		const action = event.target.dataset.action;
		if (action === "follow") {
			view.follow = !view.follow;
			renderSidebar();
			requestDraw();
		} else if (action === "details" && view.selected) {
			const id = view.selected.id;
			command("bot", { id }, (c) => {
				if (c.status === "ok") store.botDetails = { id, fields: c.result };
				renderSidebar();
			});
		}
	});
}

// =============================================
// Start
// =============================================

setupControls();
setupInteraction();
resize();
renderSidebar();
connect();
