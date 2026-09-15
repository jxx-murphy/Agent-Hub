import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const lune = process.env.LUNE ?? "lune";
const suites = ["tests/model_cli.luau", "tests/receipt_cli.luau", "tests/gameplay_cli.luau"];

const probe = spawnSync(lune, ["--version"], { encoding: "utf8" });
if (probe.error) {
  console.error(
    `Could not run "${lune}". Install Lune (https://github.com/lune-org/lune/releases) and put it on PATH,\n` +
    `or point the LUNE environment variable at the executable.`,
  );
  process.exit(1);
}

let failed = 0;
for (const suite of suites) {
  const result = spawnSync(lune, ["run", suite], { cwd: projectDir, stdio: "inherit" });
  if (result.status !== 0) failed += 1;
}

const build = spawnSync(process.execPath, ["tools/build-place.mjs"], { cwd: projectDir, stdio: "inherit" });
if (build.status !== 0) failed += 1;

process.exit(failed === 0 ? 0 : 1);
