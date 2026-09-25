-- luacheck configuration. Run it from the repository root: `luacheck ext`
-- CI runs this on every push and pull request (.github/workflows/lua-checks.yml).

std = "lua54"

-- Lowercase globals provided by VU (class, json) or defined by the mod.
read_globals = { "class", "json" }
globals = {
	"requireExists",
	string = { fields = { "split", "starts", "isLower", "isDigit" } },
	table = { fields = { "has" } },
}

-- The generated config is not hand-edited.
exclude_files = { "ext/Shared/Config.lua" }

ignore = {
	-- VU API types and libraries (Vec3, NetEvents, ...), and the mod's own classes, are capitalized
	-- globals shared across files. Locals use the p_/s_/l_/m_ prefixes, so typos in them are still caught.
	"11[123]/[A-Z].*",
	"11[123]/g_.*",

	-- Unused arguments: event callbacks and class methods keep their full signature.
	"212",
	-- Not enforced: values overwritten before use (mostly `local x = nil` before an assignment),
	-- empty branches (542) and formatting (6xx).
	"311",
	"542",
	"6",
}
