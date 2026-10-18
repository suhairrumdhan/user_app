"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const {localSourceHash, compareEndpoint} = require("../scripts/check-deployed-backend.cjs");
const {prepareFunctionsUpload} = require("firebase-tools/lib/deploy/functions/prepareFunctionsUpload");
const {getEndpointHash, getEnvironmentVariablesHash, getSecretsHash} =
  require("firebase-tools/lib/deploy/functions/cache/hash");

test("deployment checker uses exactly the Firebase CLI package hash and ignores excluded files", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "roshita-deploy-check-"));
  let archive;
  try {
    await fs.mkdir(path.join(root, "src"));
    await fs.mkdir(path.join(root, "node_modules"));
    await fs.writeFile(path.join(root, "src", "index.js"), "module.exports = {};\n");
    await fs.writeFile(path.join(root, "package.json"), "{}\n");
    await fs.writeFile(path.join(root, "node_modules", "ignored.js"), "ignored");
    const config = {ignore: ["node_modules"]};
    const packaged = await prepareFunctionsUpload(root, root, {...config, ignore: [...config.ignore]}, []);
    archive = packaged.pathToSource;
    const hash = await localSourceHash(root, config);
    assert.equal(hash, packaged.hash);
    await fs.writeFile(path.join(root, "node_modules", "ignored.js"), "changed ignored content");
    assert.equal(await localSourceHash(root, config), hash);
    await fs.writeFile(path.join(root, "src", "index.js"), "module.exports = {changed: true};\n");
    assert.notEqual(await localSourceHash(root, config), hash);
  } finally {
    // Both paths were created by this test inside the OS temporary directory.
    await fs.rm(root, {recursive: true, force: true});
    if (archive) await fs.rm(archive, {force: true});
  }
});

test("deployment checker distinguishes verified, different and unverifiable packages", () => {
  const endpoint = {platform: "gcfv2", runtime: "nodejs24", project: "demo-check",
    environmentVariables: {FIREBASE_CONFIG: "{}", EVENTARC_CLOUD_EVENT_SOURCE: "automatic"}};
  endpoint.hash = getEndpointHash("source",
    getEnvironmentVariablesHash({environmentVariables: {FLAG: "local", FIREBASE_CONFIG: "{}", GCLOUD_PROJECT: "demo-check"}}),
    getSecretsHash({}));
  assert.equal(compareEndpoint(endpoint, "source", {FLAG: "local"}, "nodejs24"), "MATCH");
  assert.equal(compareEndpoint(endpoint, "changed", {FLAG: "local"}, "nodejs24"), "SOURCE_DIFF");
  assert.equal(compareEndpoint(endpoint, "source", {FLAG: "changed"}, "nodejs24"), "SOURCE_DIFF");
  assert.equal(compareEndpoint(endpoint, "source", {FLAG: "local"}, "nodejs22"), "SOURCE_DIFF");
  assert.equal(compareEndpoint(undefined, "source", {}, "nodejs24"), "MISSING");
  assert.equal(compareEndpoint({...endpoint, hash: undefined}, "source", {}, "nodejs24"), "UNKNOWN");
  assert.equal(compareEndpoint({...endpoint, platform: "gcfv1"}, "source", {}, "nodejs24"), "UNKNOWN");
});
