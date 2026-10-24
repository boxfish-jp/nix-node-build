const fs = require("node:fs");

fs.mkdirSync("dist", { recursive: true });
fs.writeFileSync("dist/args.txt", `${process.argv.slice(2).join(" ")}\n`);
