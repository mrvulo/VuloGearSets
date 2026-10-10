// VuloGearSets / tools / lua_check.cjs
// Echter Lua-5.1-Parser ueber alle Addon-Dateien: Syntaxfehler und
// versehentlich globale Variablen oder Funktionen.
//
// Aufruf (von tools/check.py, luaparse kommt aus VuloClassicUI):
//   NODE_PATH=<...>/node_modules node tools/lua_check.cjs <datei.lua>...
// Ausgabe: eine Zeile je Befund "<datei>:<zeile>: <text>", Exitcode 1 bei Befunden.
"use strict";
const fs = require("fs");
const luaparse = require("luaparse");

// Erlaubte Globals: Tastenbelegung aus Bindings.xml und Blizzards
// Slash-/Binding-Konventionen.
const ALLOWED = [/^VuloGearSets_/, /^SLASH_/, /^BINDING_/];
const allowed = (name) => ALLOWED.some((re) => re.test(name));

let findings = 0;
function report(file, line, text) {
  findings++;
  console.log(`${file}:${line}: ${text}`);
}

function walk(node, visit) {
  if (!node || typeof node !== "object") return;
  if (Array.isArray(node)) { node.forEach((n) => walk(n, visit)); return; }
  if (typeof node.type === "string") visit(node);
  for (const key of Object.keys(node)) {
    if (key === "loc" || key === "range") continue;
    walk(node[key], visit);
  }
}

for (const file of process.argv.slice(2)) {
  let ast;
  try {
    ast = luaparse.parse(fs.readFileSync(file, "utf8"),
      { luaVersion: "5.1", scope: true, locations: true, comments: false });
  } catch (e) {
    report(file, e.line || 0, `Syntaxfehler: ${e.message}`);
    continue;
  }
  walk(ast, (n) => {
    if (n.type === "AssignmentStatement") {
      for (const v of n.variables) {
        if (v.type === "Identifier" && !v.isLocal && !allowed(v.name)) {
          report(file, v.loc.start.line, `globale Variable '${v.name}' - 'local' vergessen?`);
        }
      }
    } else if (n.type === "FunctionDeclaration" && n.identifier
               && n.identifier.type === "Identifier" && !n.isLocal
               && !n.identifier.isLocal && !allowed(n.identifier.name)) {
      report(file, n.loc.start.line, `globale Funktion '${n.identifier.name}' - 'local' vergessen?`);
    }
  });
}
process.exit(findings ? 1 : 0);
