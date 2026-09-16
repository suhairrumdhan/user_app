"use strict";

// Compatibility import path retained for staged F03/F04 deployments.
const employeeSession = require("../auth/employee-session");

module.exports = {
  ...employeeSession,
  buildEmployeeAuthHandlers: employeeSession.buildEmployeeSessionHandlers,
};
