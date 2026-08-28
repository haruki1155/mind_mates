import assert from "node:assert/strict";
import test from "node:test";
import {isSuperAdminIdentity, superAdminUidFromSecurity} from "./admin_security";

test("security document is the sole super-admin identity authority", () => {
  assert.equal(superAdminUidFromSecurity({superAdminUid: " admin-uid "}), "admin-uid");
  assert.equal(superAdminUidFromSecurity({}), null);
  assert.equal(
    isSuperAdminIdentity("admin-uid", {superAdminUid: "admin-uid"}, {accessRole: "admin"}),
    true,
  );
  assert.equal(
    isSuperAdminIdentity("other-uid", {superAdminUid: "admin-uid"}, {accessRole: "admin"}),
    false,
  );
  assert.equal(
    isSuperAdminIdentity("admin-uid", {superAdminUid: "admin-uid"}, {accessRole: "portalStaff"}),
    false,
  );
});
