"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {after, before, test} = require("node:test");
const {initializeTestEnvironment, assertFails, assertSucceeds} =
  require("@firebase/rules-unit-testing");
const {doc, setDoc} = require("firebase/firestore");

let environment;

before(async () => {
  const repositoryRoot = path.resolve(__dirname, "..", "..", "..");
  environment = await initializeTestEnvironment({
    projectId: "demo-roshita-insurance-rules",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync(path.join(repositoryRoot, "firestore.rules"), "utf8"),
    },
  });
});

after(async () => {
  await environment?.cleanup();
});

test("one deterministic insurance policy is allowed per beneficiary", async () => {
  const db = environment.authenticatedContext("user-one").firestore();
  const valid = {
    schemaVersion: 2,
    beneficiaryId: "child-one",
    beneficiaryType: "family",
    beneficiaryName: "Child One",
    companyCode: "C1",
    companyName: "Company One",
    policyNumber: "POLICY-ONE",
    cardNumber: "POLICY-ONE",
    coveredMemberIds: ["child-one"],
  };
  await assertSucceeds(setDoc(
    doc(db, "users/user-one/insurances/child-one"), valid,
  ));
  await assertFails(setDoc(
    doc(db, "users/user-one/insurances/not-the-beneficiary"), valid,
  ));
  await assertFails(setDoc(
    doc(db, "users/user-one/insurances/child-two"), {
      ...valid,
      beneficiaryId: "child-two",
      coveredMemberIds: ["child-one", "child-two"],
    },
  ));
});
