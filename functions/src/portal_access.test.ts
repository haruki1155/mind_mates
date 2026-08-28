import assert from "node:assert/strict";
import test from "node:test";
import {isApprovedPortalIdentity} from "./portal_access";

test("portal authorization admits only approved operational identities", () => {
  assert.equal(isApprovedPortalIdentity(
    "staff", {accessRole: "portalStaff", staffAccountStatus: "approved"}, "admin",
  ), true);
  assert.equal(isApprovedPortalIdentity(
    "counselor", {accessRole: "counselor", staffAccountStatus: "approved"}, "admin",
  ), true);
  for (const staffAccountStatus of ["pending", "rejected", "disabled", undefined]) {
    assert.equal(isApprovedPortalIdentity(
      "staff", {accessRole: "portalStaff", staffAccountStatus}, "admin",
    ), false);
  }
  assert.equal(isApprovedPortalIdentity(
    "user", {accessRole: "appUser"}, "admin",
  ), false);
  assert.equal(isApprovedPortalIdentity(
    "admin", {accessRole: "admin"}, "admin",
  ), true);
  assert.equal(isApprovedPortalIdentity(
    "other-admin", {accessRole: "admin"}, "admin",
  ), false);
});

test("portal staff cannot enter counselor and administrator analytics", () => {
  assert.equal(isApprovedPortalIdentity(
    "staff", {accessRole: "portalStaff", staffAccountStatus: "approved"},
    "admin", ["counselor", "admin"],
  ), false);
  assert.equal(isApprovedPortalIdentity(
    "counselor", {accessRole: "counselor", staffAccountStatus: "approved"},
    "admin", ["counselor", "admin"],
  ), true);
});
