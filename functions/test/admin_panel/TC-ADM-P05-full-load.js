import http from 'k6/http';
import {Rate} from 'k6/metrics';
import {sleep} from 'k6';

const unexpectedErrors = new Rate('unexpected_errors');
const functionalFailures = new Rate('functional_failures');
const tokens = JSON.parse(__ENV.ADMIN_ID_TOKENS_JSON || '[]');
const command = __ENV.ADMIN_P05_COMMAND;
const suffix = __ENV.ADMIN_P05_SUFFIX;
if (!__ENV.ADMIN_CALLABLE_URL || tokens.length !== 25 || !command || !suffix) {
  throw new Error('The isolated TC-ADM-P05 runner did not provide the expected test fixtures.');
}

export const options = {
  stages: [
    {duration: '30s', target: 10},
    {duration: '60s', target: 10},
    {duration: '30s', target: 25},
    {duration: '180s', target: 25},
  ],
  thresholds: {
    http_req_duration: ['p(95)<=3000'],
    unexpected_errors: ['rate<=0.01'],
    functional_failures: ['rate==0'],
  },
  discardResponseBodies: false,
};

function payloadForVu() {
  const vu = __VU;
  const iteration = __ITER;
  const operationId = `admperf_${suffix}_${command}_${vu}_${iteration}`;
  if (command === 'search') return {kind: 'orders', q: 'tcadmload', state: 'all', group: '', cursor: null};
  if (command === 'registration') return {
    action: 'decision', requestId: `admperf_p05reg_${suffix}_${vu}_${iteration}`,
    operationId, expectedRevision: 0, decision: 'reject', reason: 'TC-ADM-P05 synthetic load decision',
  };
  if (command === 'visibility') {
    const expectedHidden = iteration % 2 === 1;
    return {pharmacyId: `admperf_p05ph_${suffix}_${vu}`, operationId, hidden: !expectedHidden,
      expectedHidden, expectedRevision: iteration, reason: 'TC-ADM-P05 synthetic load visibility'};
  }
  if (command === 'broadcast') return {
    action: 'create', operationId, title: 'TC-ADM-P05 synthetic load notice',
    body: 'Synthetic emulator load-test message; no production recipients.', targetType: 'users',
  };
  throw new Error(`Unsupported TC-ADM-P05 operation: ${command}`);
}

function resultMatches(result, vu, iteration) {
  if (command === 'search') return result?.total === 1000 && Array.isArray(result.rows) && result.rows.length > 0;
  if (command === 'registration') return result?.status === 'rejected';
  if (command === 'visibility') return result?.isBlocked === (iteration % 2 === 0) &&
    result?.visibilityRevision === iteration + 1;
  if (command === 'broadcast') return result?.status === 'queued' && typeof result.broadcastId === 'string';
  return false;
}

export default function () {
  const vu = __VU;
  const iteration = __ITER;
  const response = http.post(__ENV.ADMIN_CALLABLE_URL,
    JSON.stringify({data: payloadForVu()}),
    {headers: {'Content-Type': 'application/json', Authorization: `Bearer ${tokens[vu - 1]}`},
      tags: {testCase: 'TC-ADM-P05', operation: command}});
  let body = {};
  try { body = response.json(); } catch (_) { /* Count malformed responses below. */ }
  const result = body?.result ?? body?.data;
  const transportOrCallableError = response.status !== 200 || Boolean(body?.error);
  const functionallyCorrect = !transportOrCallableError && resultMatches(result, vu, iteration);
  unexpectedErrors.add(transportOrCallableError);
  functionalFailures.add(!functionallyCorrect);
  sleep(1);
}
