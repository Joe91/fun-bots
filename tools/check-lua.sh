#!/bin/sh
# Static checks for the Lua code. Run from anywhere: tools/check-lua.sh
#
# 1. luacheck (configured in .luacheckrc). CI runs the same check.
# 2. lua-language-server --check with the VU type stubs, if both are available. The stubs are generated
#    by the "VU Lua" VS Code extension (Imposter.vscode-lua-vu) into .vua_data/, so this step only runs
#    locally. Set LUALS to the lua-language-server binary if it isn't on PATH.

cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)
STATUS=0

if command -v luacheck >/dev/null 2>&1; then
	luacheck ext || STATUS=1
else
	echo "luacheck not found, skipping (install it with luarocks or your package manager)."
fi

LUALS=${LUALS:-$(command -v lua-language-server)}
if [ -z "$LUALS" ]; then
	LUALS=$(ls -d "$HOME"/.vscode*/extensions/sumneko.lua-*/server/bin/lua-language-server 2>/dev/null | tail -n 1)
fi
TYPES="$ROOT/.vua_data/data/types"

if [ -n "$LUALS" ] && [ -d "$TYPES" ]; then
	TMP=$(mktemp -d)
	trap 'rm -rf "$TMP"' EXIT

	for REALM in Server Client; do
		LIBS="\"$TYPES/shared\", \"$TYPES/fb\", \"$ROOT/.vua_data/data/lib\", \"$ROOT/ext/Shared\""
		if [ "$REALM" = Server ]; then
			LIBS="$LIBS, \"$TYPES/server\""
		else
			LIBS="$LIBS, \"$TYPES/client\""
		fi

		cat >"$TMP/luarc.json" <<JSON
{
	"runtime.version": "Lua 5.4",
	"workspace.library": [$LIBS],
	"workspace.checkThirdParty": false,
	"diagnostics.libraryFiles": "Disable"
}
JSON
		echo "lua-language-server: ext/$REALM"
		"$LUALS" --check "ext/$REALM" --configpath "$TMP/luarc.json" --checklevel Warning \
			--check_format pretty --logpath "$TMP/log" || STATUS=1
	done
else
	echo "lua-language-server or the VU type stubs (.vua_data/) not found, skipping type checks."
fi

exit $STATUS
