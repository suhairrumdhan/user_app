"use strict";

const admin = require("firebase-admin");
const {randomUUID} = require("node:crypto");
const projectId = "demo-roshita-admin-nf";
const suffix = randomUUID().replaceAll("-", "");
const app = admin.initializeApp({projectId}, `adm-case-${suffix}`);
const db = admin.firestore(app);
const auth = admin.auth(app);

async function createAccount(label) {
  const response = await fetch("http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key", {
    method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({email: `${label}-${suffix}@example.invalid`, password: `Adm-${suffix.slice(0, 14)}!x`, returnSecureToken: true}),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`Auth Emulator fixture creation failed: ${body.error?.message || response.status}`);
  return {uid: body.localId, idToken: body.idToken};
}

async function callRegistration(data, token) {
  const response = await fetch(`http://127.0.0.1:15001/${projectId}/us-central1/registrationCommand`, {
    method: "POST", headers: {"content-type": "application/json", authorization: `Bearer ${token}`},
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

module.exports = {admin, app, auth, callRegistration, createAccount, db, projectId, suffix};
