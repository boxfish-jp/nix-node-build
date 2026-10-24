const fs = require("node:fs");
const isNumber = require("is-number");

if (!isNumber(42)) {
  throw new Error("is-number dependency is not installed");
}

fs.mkdirSync("dist", { recursive: true });
fs.writeFileSync("dist/index.html", `built with npm\n`);
