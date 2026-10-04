"use strict";
// Tabs (Live / Maps) and the Maps tab: the levels of mapfiles/, what is done for them, and the jobs that do the rest
// (funbots_debug/maps.py, GET /api/maps, POST /api/maps/run).

(() => {
	const $ = (id) => document.getElementById(id);
	const selected = new Set();
	let data = { maps: [], jobs: [] };
	let shownJob = null;
	let timer = null;
	let gameEdited = false;

	// --- tabs ----------------------------------------------------------------------------------------------------

	function showTab(tab) {
		for (const button of document.querySelectorAll("#tabs .tab")) {
			button.classList.toggle("on", button.dataset.tab === tab);
		}
		$("live").hidden = tab !== "live";
		$("maps-view").hidden = tab !== "maps";
		try {
			localStorage.setItem("funbots-tab", tab);
		} catch (error) {
			// Storage not available: the tab isn't remembered.
		}
		if (tab === "live") {
			window.dispatchEvent(new Event("resize"));
			clearInterval(timer);
			timer = null;
		} else {
			load(false);
			if (timer === null) {
				timer = setInterval(() => load(false), 2000);
			}
		}
	}

	for (const button of document.querySelectorAll("#tabs .tab")) {
		button.addEventListener("click", () => showTab(button.dataset.tab));
	}

	// --- data ----------------------------------------------------------------------------------------------------

	async function load(refresh) {
		try {
			const response = await fetch("/api/maps" + (refresh ? "?refresh=1" : ""));
			const answer = await response.json();
			if (answer.error) {
				$("maps-count").textContent = answer.error;
				return;
			}
			data = answer;
			if (!gameEdited) {
				$("maps-game").value = data.restartCommand || "";
			}
			render();
		} catch (error) {
			$("maps-count").textContent = "debug-server not reachable";
		}
	}

	async function post(path, body) {
		const response = await fetch(path, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(body),
		});
		return response.json();
	}

	async function run(steps) {
		const maps = [...selected];
		if (maps.length === 0) {
			$("maps-count").textContent = "select levels first";
			return;
		}
		const answer = await post("/api/maps/run", { maps, steps, restartCommand: $("maps-game").value });
		if (answer.jobs && answer.jobs.length > 0) {
			shownJob = answer.jobs[0].id;
		}
		load(false);
	}

	// --- table ---------------------------------------------------------------------------------------------------

	function age(seconds) {
		if (seconds === null || seconds === undefined) {
			return "";
		}
		const days = (Date.now() / 1000 - seconds) / 86400;
		return days < 1 ? "today" : `${Math.round(days)} d`;
	}

	function cell(text, cls, title) {
		const td = document.createElement("td");
		td.textContent = text;
		if (cls) {
			td.className = cls;
		}
		if (title) {
			td.title = title;
		}
		return td;
	}

	function visible(map) {
		const kind = $("maps-kind").value;
		if (kind === "mesh" || kind === "paths") {
			if (map.kind !== kind) {
				return false;
			}
		} else if (kind === "todo" && map.missing.length === 0) {
			return false;
		} else if (kind === "git" && !map.git) {
			return false;
		}
		const filter = $("maps-filter").value.trim().toLowerCase();
		if (!filter) {
			return true;
		}
		const text = [map.name, map.kind, map.db, map.git, map.cut ? "cut" : "uncut", ...map.missing].join(" ");
		return filter.split(/\s+/).every((word) => text.toLowerCase().includes(word));
	}

	function render() {
		const body = document.querySelector("#maps-table tbody");
		body.textContent = "";
		const shown = data.maps.filter(visible);
		for (const map of shown) {
			const row = document.createElement("tr");
			row.classList.toggle("selected", selected.has(map.name));
			const check = document.createElement("input");
			check.type = "checkbox";
			check.checked = selected.has(map.name);
			check.addEventListener("change", () => {
				if (check.checked) {
					selected.add(map.name);
				} else {
					selected.delete(map.name);
				}
				row.classList.toggle("selected", check.checked);
			});
			const first = document.createElement("td");
			first.appendChild(check);
			row.appendChild(first);
			row.appendChild(cell(map.level));
			row.appendChild(cell(map.mode, "", map.kind === "mesh" ? "bots go for objectives: census, mesh and cut"
				: map.kind === "paths" ? "bots walk the paths" : map.kind));
			row.appendChild(cell(`${map.paths}`, "", `${map.waypoints} waypoints, ${map.links} links`));
			const needsMesh = map.kind === "mesh";
			row.appendChild(cell(map.census ? age(map.census) : needsMesh ? "missing" : "",
				map.census ? "ok" : needsMesh ? "bad" : ""));
			const mesh = map.mesh;
			row.appendChild(cell(mesh ? (mesh.error || `${mesh.zones} zones, ${mesh.junctions} junctions`) : needsMesh ? "missing" : "",
				mesh && !mesh.error ? "ok" : needsMesh ? "bad" : "", mesh && mesh.points ? `${mesh.points} points` : ""));
			row.appendChild(cell(map.cut ? `${map.navigation} paths` : needsMesh ? "no" : "",
				map.cut ? "ok" : needsMesh ? "bad" : ""));
			row.appendChild(cell(map.checked ? age(map.checked) : needsMesh ? "no" : "",
				map.checked ? "ok" : needsMesh ? "warn" : "", "rays of the game over the mesh (step check)"));
			const db = map.db === "same" && (map.dbMesh === null || map.dbMesh === "same");
			row.appendChild(cell(db ? "same" : `waypoints ${map.db}` + (map.dbMesh && map.dbMesh !== "same" ? `, mesh ${map.dbMesh}` : ""),
				db ? "ok" : "warn", "mod.db against mapfiles/ and navzones/"));
			row.appendChild(cell(map.git, map.git ? "warn" : ""));
			row.appendChild(cell(map.missing.join(", ") || "-", map.missing.length ? "warn" : "ok"));
			row.addEventListener("click", (event) => {
				if (event.target !== check) {
					check.checked = !check.checked;
					check.dispatchEvent(new Event("change"));
				}
			});
			body.appendChild(row);
		}
		const todo = data.maps.filter((map) => map.missing.length > 0).length;
		$("maps-count").textContent = `${shown.length} of ${data.maps.length} levels, ${selected.size} selected, `
			+ `${todo} with something to do` + (data.refreshing ? " (reading...)" : "");
		renderJobs();
	}

	function renderJobs() {
		const list = $("maps-jobs");
		list.textContent = "";
		const jobs = [...data.jobs].reverse();
		for (const job of jobs) {
			const item = document.createElement("li");
			item.className = job.state + (job.id === shownJob ? " selected" : "");
			const seconds = job.started ? Math.round((job.ended || Date.now() / 1000) - job.started) : null;
			item.textContent = `${job.step} ${job.map}: ${job.state}` + (seconds !== null ? ` (${seconds} s)` : "");
			item.addEventListener("click", () => {
				shownJob = job.id;
				renderJobs();
			});
			list.appendChild(item);
		}
		if (shownJob === null && jobs.length > 0) {
			shownJob = (jobs.find((job) => job.state === "running") || jobs[0]).id;
		}
		const job = data.jobs.find((entry) => entry.id === shownJob);
		const log = $("maps-log");
		const atEnd = log.scrollTop + log.clientHeight >= log.scrollHeight - 4;
		log.textContent = job ? job.log.join("\n") : "";
		if (atEnd) {
			log.scrollTop = log.scrollHeight;
		}
	}

	// --- controls ------------------------------------------------------------------------------------------------

	$("maps-filter").addEventListener("input", render);
	$("maps-kind").addEventListener("change", render);
	$("maps-refresh").addEventListener("click", () => load(true));
	$("maps-all").addEventListener("change", (event) => {
		for (const map of data.maps.filter(visible)) {
			if (event.target.checked) {
				selected.add(map.name);
			} else {
				selected.delete(map.name);
			}
		}
		render();
	});
	$("maps-missing").addEventListener("click", () => run("missing"));
	for (const button of document.querySelectorAll(".maps-actions button[data-step]")) {
		button.addEventListener("click", () => run([button.dataset.step]));
	}
	$("maps-cancel").addEventListener("click", async () => {
		await post("/api/maps/cancel", { job: null });
		load(false);
	});
	$("maps-game").addEventListener("input", () => {
		gameEdited = true;
	});
	$("maps-start-game").addEventListener("click", async () => {
		const command = $("maps-game").value;
		await post("/api/maps/run", { maps: [], steps: [], restartCommand: command });
		const answer = await post("/api/maps/game", {});
		$("maps-game-status").textContent = answer.error || "started, the mod connects in a few minutes";
	});

	let tab = "live";
	try {
		tab = localStorage.getItem("funbots-tab") || "live";
	} catch (error) {
		// Storage not available.
	}
	showTab(tab === "maps" ? "maps" : "live");
})();
