import assert from "node:assert/strict";
import {test} from "node:test";

import {
  isValidSecretChatPhotoPath,
  normalizeSecretChatAlias,
} from "./index";

test("normalizes a Secret Chat alias for one canonical reservation", () => {
  assert.equal(normalizeSecretChatAlias("  Calm   Owl 7 "), "Calm Owl 7");
  assert.throws(() => normalizeSecretChatAlias("Calm_Owl"));
  assert.throws(() => normalizeSecretChatAlias(""));
  assert.throws(() => normalizeSecretChatAlias("x".repeat(31)));
});

test("accepts only timestamped owned JPEG and PNG profile paths", () => {
  assert.equal(
    isValidSecretChatPhotoPath("owner", "secret_chat_profiles/owner/avatar_123.jpg"),
    true,
  );
  assert.equal(
    isValidSecretChatPhotoPath("owner", "secret_chat_profiles/other/avatar_123.jpg"),
    false,
  );
  assert.equal(
    isValidSecretChatPhotoPath("owner", "secret_chat_profiles/owner/avatar_now.gif"),
    false,
  );
});
