const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const extensionRoot = path.resolve(__dirname, "..", "..");
const srcRoot = path.join(extensionRoot, "src");
const distRoot = path.join(extensionRoot, "dist");
const manifestPath = path.join(distRoot, ".build-manifest.json");

function walkFiles(rootDir, predicate) {
  if (!fs.existsSync(rootDir)) {
    return [];
  }

  const results = [];
  const stack = [rootDir];

  while (stack.length > 0) {
    const currentDir = stack.pop();
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });

    for (const entry of entries) {
      const absolutePath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        stack.push(absolutePath);
        continue;
      }

      if (predicate(absolutePath)) {
        results.push(absolutePath);
      }
    }
  }

  return results.sort();
}

function toPosixRelative(rootDir, absolutePath) {
  return path.relative(rootDir, absolutePath).split(path.sep).join("/");
}

function collectTrackedSources() {
  const sourceFiles = walkFiles(srcRoot, (absolutePath) => absolutePath.endsWith(".ts"));
  const configFiles = ["package.json", "tsconfig.json"].map((relativePath) =>
    path.join(extensionRoot, relativePath),
  );

  return [...sourceFiles, ...configFiles]
    .filter((absolutePath) => fs.existsSync(absolutePath))
    .sort();
}

function collectDistFiles() {
  return walkFiles(
    distRoot,
    (absolutePath) => path.basename(absolutePath) !== ".build-manifest.json",
  ).map((absolutePath) => toPosixRelative(distRoot, absolutePath));
}

function hashFiles(rootDir, files) {
  const hash = crypto.createHash("sha256");
  for (const absolutePath of files) {
    hash.update(toPosixRelative(rootDir, absolutePath));
    hash.update("\0");
    hash.update(fs.readFileSync(absolutePath));
    hash.update("\0");
  }
  return hash.digest("hex");
}

function buildManifest() {
  const trackedSources = collectTrackedSources();
  return {
    version: 1,
    sourceHash: hashFiles(extensionRoot, trackedSources),
    trackedSources: trackedSources.map((absolutePath) =>
      toPosixRelative(extensionRoot, absolutePath),
    ),
    distFiles: collectDistFiles(),
  };
}

function writeManifest() {
  if (!fs.existsSync(distRoot)) {
    throw new Error(
      "dist/ is missing. Run the TypeScript compile step before writing the build manifest.",
    );
  }

  const manifest = buildManifest();
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  console.log(`Wrote dist drift manifest to ${manifestPath}`);
}

function checkManifest() {
  if (!fs.existsSync(manifestPath)) {
    throw new Error("Missing dist build manifest. Run `npm run build` in extensions/vscode.");
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const currentManifest = buildManifest();

  if (manifest.version !== currentManifest.version) {
    throw new Error("Dist build manifest version mismatch. Rebuild the VS Code extension.");
  }

  if (manifest.sourceHash !== currentManifest.sourceHash) {
    throw new Error(
      "VS Code extension dist drift detected: source inputs changed since the last build. Run `npm run build` in extensions/vscode.",
    );
  }

  const missingDistFiles = manifest.distFiles.filter(
    (relativePath) => !fs.existsSync(path.join(distRoot, relativePath)),
  );
  if (missingDistFiles.length > 0) {
    throw new Error(
      `VS Code extension dist drift detected: missing generated files: ${missingDistFiles.join(", ")}`,
    );
  }

  console.log("VS Code extension dist is up to date.");
}

function main() {
  if (process.argv.includes("--write-manifest")) {
    writeManifest();
    return;
  }

  checkManifest();
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
