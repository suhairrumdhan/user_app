"use strict";

// Read-only check. Uses the installed Firebase CLI's own file ordering and hash
// implementation, rather than comparing Git commits or deployment timestamps.
const fs = require("node:fs/promises");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const {readdirRecursive} = require("firebase-tools/lib/fsAsync");
const {getSourceHash, getEnvironmentVariablesHash, getEndpointHash} =
  require("firebase-tools/lib/deploy/functions/cache/hash");
const {loadUserEnvs} = require("firebase-tools/lib/functions/env");

const ORDER_RELEASE = ["executeOrderCommand", "processOrderDeadlines",
  "onOrderCreated", "onOrderUpdated", "adminOrderProjection", "adminInsights", "adminList"];

async function localSourceHash(sourceDir, config) {
  const ignore = [...(config.ignore || ["node_modules", ".git"]),
    "firebase-debug.log", "firebase-debug.*.log", ".runtimeconfig.json"];
  const files = await readdirRecursive({path: sourceDir, ignore});
  return (await Promise.all(files.map((file) => getSourceHash(file.name)))).join(".");
}

function compareEndpoint(endpoint, sourceHash, userEnvs, runtime) {
  if (!endpoint) return "MISSING";
  if (endpoint.platform !== "gcfv2" || !endpoint.hash ||
      !endpoint.environmentVariables?.FIREBASE_CONFIG ||
      endpoint.secretEnvironmentVariables?.length) return "UNKNOWN";
  // Automatic per-function EVENTARC_CLOUD_EVENT_SOURCE is not included in the
  // codebase environment hash. Build exactly the environment order used by CLI.
  const environmentVariables = {...userEnvs,
    FIREBASE_CONFIG: endpoint.environmentVariables.FIREBASE_CONFIG,
    GCLOUD_PROJECT: endpoint.project};
  const envHash = getEnvironmentVariablesHash({environmentVariables});
  const secretsHash = getSourceHashForEmptySecrets();
  const expected = getEndpointHash(sourceHash, envHash, secretsHash);
  return endpoint.hash === expected && endpoint.runtime === runtime ? "MATCH" : "SOURCE_DIFF";
}

function getSourceHashForEmptySecrets() {
  const {getSecretsHash} = require("firebase-tools/lib/deploy/functions/cache/hash");
  return getSecretsHash({secretEnvironmentVariables: []});
}

async function main() {
  const root = path.resolve(__dirname, "../..");
  const firebase = JSON.parse(await fs.readFile(path.join(root, "firebase.json"), "utf8"));
  const config = firebase.functions.find((entry) => entry.codebase === "default");
  if (!config || config.source !== "functions") throw new Error("Unsupported functions config");
  const projectArg = process.argv.findIndex((arg) => arg === "--project");
  const project = projectArg >= 0 ? process.argv[projectArg + 1] : "pharma-apps";
  if (!project || !/^[a-z0-9-]+$/.test(project)) throw new Error("Invalid project ID");
  const source = path.join(root, config.source);
  const sourceHash = await localSourceHash(source, config);
  const local = require(path.join(source, "index.js"));
  const names = process.argv.includes("--orders") ? ORDER_RELEASE : Object.keys(local).sort();
  if (names.some((name) => !local[name])) throw new Error("A release function is not exported locally");
  const cli = require.resolve("firebase-tools/lib/bin/firebase.js");
  const listed = spawnSync(process.execPath,
    ["--use-system-ca", cli, "functions:list", "--project", project, "--json", "--non-interactive"],
    {cwd: root, encoding: "utf8", timeout: 120000, maxBuffer: 16 * 1024 * 1024});
  if (listed.error || listed.status !== 0) {
    throw new Error("Unable to read deployed functions. Check network/login: node --use-system-ca functions/node_modules/firebase-tools/lib/bin/firebase.js login");
  }
  let endpoints;
  try {
    const json = JSON.parse(listed.stdout);
    if (json.status !== "success" || !Array.isArray(json.result)) throw new Error();
    endpoints = json.result;
  } catch {
    throw new Error("Firebase CLI returned an unsupported response; no deployment status assumed.");
  }
  const userEnvs = loadUserEnvs({functionsSource: source, projectId: project});
  const rows = [];
  const deploy = [];
  for (const name of names) {
    const existing = endpoints.filter((endpoint) => endpoint.id === name && endpoint.codebase === "default");
    const regions = local[name].__endpoint?.region || ["us-central1"];
    for (const region of regions) {
      const endpoint = existing.find((entry) => entry.region === region);
      const state = compareEndpoint(endpoint, sourceHash, userEnvs, config.runtime);
      rows.push({function: name, region, state});
      if (state === "SOURCE_DIFF" || state === "MISSING") deploy.push(name);
    }
  }
  console.log(`Project: ${project}`);
  console.table(rows);
  console.log("MATCH = published package matches local files and local environment.");
  console.log("SOURCE_DIFF = deployed package/runtime differs; this is not a per-function behavior diff.");
  console.log("MISSING = not deployed. UNKNOWN = cannot verify; not treated as a match.");
  console.log("Firebase hashes the entire source package, including non-ignored tests/scripts.");
  console.log("This checks Cloud Functions only; it does not check Firestore/Storage rules, indexes, Flask or app builds.");
  if (deploy.length) {
    console.log("\nReview and run this deployment command yourself:");
    console.log(`node --use-system-ca functions/node_modules/firebase-tools/lib/bin/firebase.js deploy --project ${project} --only "${[...new Set(deploy)].map((name) => `functions:${name}`).join(",")}"`);
  } else if (rows.every((row) => row.state === "MATCH")) {
    console.log("All checked functions match. No function deployment needed.");
  }
  if (rows.some((row) => row.state === "UNKNOWN")) process.exitCode = 3;
  else if (deploy.length) process.exitCode = 2;
}

module.exports = {localSourceHash, compareEndpoint};
if (require.main === module) main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
