const API_VERSION = "v1";
const MAX_JSON_BODY_BYTES = 4_096;
const DEFAULT_AVATAR = "person.crop.circle.fill";
const LINK_CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const LINK_CODE_LENGTH = 10;
const PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"] as const;

type Prayer = (typeof PRAYERS)[number];

type UserRow = {
  id: string;
  nickname: string;
  avatar: string;
  link_code: string;
  created_at: string;
  updated_at: string;
};

type PublicUserRow = {
  id: string;
  nickname: string;
  avatar: string;
};

type PrayerUserRow = PublicUserRow & {
  prayer: Prayer;
};

type PublicUser = {
  id: string;
  nickname: string;
  avatar: string;
};

type PrayerUsers = Record<Prayer, PublicUser[]>;

class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    try {
      return await route(request, url, env);
    } catch (error) {
      if (error instanceof ApiError) {
        return jsonResponse(
          { error: { code: error.code, message: error.message } },
          error.status,
        );
      }

      console.error(
        JSON.stringify({
          message: "Unhandled API error",
          method: request.method,
          path: url.pathname,
          error: error instanceof Error ? error.message : String(error),
        }),
      );

      return jsonResponse(
        {
          error: {
            code: "internal_error",
            message: "An unexpected error occurred.",
          },
        },
        500,
      );
    }
  },
} satisfies ExportedHandler<Env>;

async function route(request: Request, url: URL, env: Env): Promise<Response> {
  const pathname = normalizePathname(url.pathname);

  if (request.method === "GET" && pathname === "/health") {
    return jsonResponse({ status: "ok" });
  }

  if (request.method === "POST" && pathname === `/${API_VERSION}/users`) {
    return createUser(request, env.DB);
  }

  const user = await authenticate(request, env.DB);

  if (request.method === "GET" && pathname === `/${API_VERSION}/me`) {
    return jsonResponse({ user: serializeMe(user) });
  }

  if (request.method === "PATCH" && pathname === `/${API_VERSION}/me`) {
    return updateMe(request, env.DB, user);
  }

  if (request.method === "DELETE" && pathname === `/${API_VERSION}/me`) {
    return deleteMe(env.DB, user.id);
  }

  if (
    request.method === "POST" &&
    pathname === `/${API_VERSION}/me/link-code`
  ) {
    return regenerateLinkCode(env.DB, user);
  }

  if (request.method === "GET" && pathname === `/${API_VERSION}/links`) {
    return listLinks(env.DB, user.id);
  }

  if (request.method === "POST" && pathname === `/${API_VERSION}/links`) {
    return createLink(request, env.DB, user);
  }

  const linkMatch = pathname.match(
    /^\/v1\/links\/([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i,
  );
  if (request.method === "DELETE" && linkMatch) {
    return deleteLink(env.DB, user.id, requiredMatch(linkMatch, 1));
  }

  const checkinMatch = pathname.match(
    /^\/v1\/checkins\/(\d{4}-\d{2}-\d{2})\/(fajr|dhuhr|asr|maghrib|isha)$/,
  );
  if ((request.method === "PUT" || request.method === "DELETE") && checkinMatch) {
    const date = validateDate(requiredMatch(checkinMatch, 1));
    const prayer = validatePrayer(requiredMatch(checkinMatch, 2));

    if (request.method === "PUT") {
      return putCheckin(env.DB, user.id, date, prayer);
    }

    return deleteCheckin(env.DB, user.id, date, prayer);
  }

  const prayersMatch = pathname.match(/^\/v1\/prayers\/(\d{4}-\d{2}-\d{2})$/);
  if (request.method === "GET" && prayersMatch) {
    return getPrayerUsers(
      env.DB,
      user.id,
      validateDate(requiredMatch(prayersMatch, 1)),
    );
  }

  throw new ApiError(404, "not_found", "Endpoint not found.");
}

async function createUser(request: Request, db: D1Database): Promise<Response> {
  const body = await readJsonObject(request);
  assertOnlyKeys(body, ["nickname", "avatar"]);

  const nickname = validateNickname(requireString(body, "nickname"));
  const avatar = validateAvatar(optionalString(body, "avatar") ?? DEFAULT_AVATAR);

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const id = crypto.randomUUID();
    const token = randomHex(32);
    const tokenHash = await sha256Hex(token);
    const linkCode = generateLinkCode();
    const now = new Date().toISOString();

    const result = await db
      .prepare(
        `INSERT OR IGNORE INTO users
          (id, nickname, avatar, link_code, token_hash, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(id, nickname, avatar, linkCode, tokenHash, now, now)
      .run();

    if (result.meta.changes === 1) {
      return jsonResponse(
        {
          user: {
            id,
            nickname,
            avatar,
            linkCode,
            createdAt: now,
            updatedAt: now,
          },
          token,
        },
        201,
      );
    }
  }

  throw new ApiError(
    503,
    "registration_unavailable",
    "Could not create a unique account. Please try again.",
  );
}

async function updateMe(
  request: Request,
  db: D1Database,
  user: UserRow,
): Promise<Response> {
  const body = await readJsonObject(request);
  assertOnlyKeys(body, ["nickname", "avatar"]);

  if (!("nickname" in body) && !("avatar" in body)) {
    throw new ApiError(
      400,
      "empty_update",
      "Provide a nickname or avatar to update.",
    );
  }

  const nickname =
    "nickname" in body
      ? validateNickname(requireString(body, "nickname"))
      : user.nickname;
  const avatar =
    "avatar" in body
      ? validateAvatar(requireString(body, "avatar"))
      : user.avatar;
  const updatedAt = new Date().toISOString();

  await db
    .prepare(
      "UPDATE users SET nickname = ?, avatar = ?, updated_at = ? WHERE id = ?",
    )
    .bind(nickname, avatar, updatedAt, user.id)
    .run();

  return jsonResponse({
    user: serializeMe({ ...user, nickname, avatar, updated_at: updatedAt }),
  });
}

async function regenerateLinkCode(
  db: D1Database,
  user: UserRow,
): Promise<Response> {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const linkCode = generateLinkCode();
    const updatedAt = new Date().toISOString();
    const result = await db
      .prepare(
        `UPDATE OR IGNORE users
         SET link_code = ?, updated_at = ?
         WHERE id = ?`,
      )
      .bind(linkCode, updatedAt, user.id)
      .run();

    if (result.meta.changes === 1) {
      return jsonResponse({ linkCode });
    }
  }

  throw new ApiError(
    503,
    "code_unavailable",
    "Could not generate a unique linking code. Please try again.",
  );
}

async function deleteMe(db: D1Database, userId: string): Promise<Response> {
  await db.prepare("DELETE FROM users WHERE id = ?").bind(userId).run();
  return emptyResponse(204);
}

async function listLinks(db: D1Database, userId: string): Promise<Response> {
  const result = await db
    .prepare(
      `SELECT u.id, u.nickname, u.avatar
       FROM links l
       JOIN users u
         ON u.id = CASE
           WHEN l.user_a_id = ? THEN l.user_b_id
           ELSE l.user_a_id
         END
       WHERE l.user_a_id = ? OR l.user_b_id = ?
       ORDER BY u.nickname COLLATE NOCASE, u.id`,
    )
    .bind(userId, userId, userId)
    .all<PublicUserRow>();

  return jsonResponse({ users: result.results.map(serializePublicUser) });
}

async function createLink(
  request: Request,
  db: D1Database,
  user: UserRow,
): Promise<Response> {
  const body = await readJsonObject(request);
  assertOnlyKeys(body, ["code"]);
  const code = normalizeLinkCode(requireString(body, "code"));

  const linkedUser = await db
    .prepare(
      "SELECT id, nickname, avatar FROM users WHERE link_code = ? LIMIT 1",
    )
    .bind(code)
    .first<PublicUserRow>();

  if (!linkedUser) {
    throw new ApiError(404, "code_not_found", "Linking code not found.");
  }

  if (linkedUser.id === user.id) {
    throw new ApiError(409, "cannot_link_self", "You cannot link yourself.");
  }

  const [userAId, userBId] = canonicalLink(user.id, linkedUser.id);
  const result = await db
    .prepare(
      `INSERT OR IGNORE INTO links (user_a_id, user_b_id, created_at)
       VALUES (?, ?, ?)`,
    )
    .bind(userAId, userBId, new Date().toISOString())
    .run();

  return jsonResponse(
    {
      user: serializePublicUser(linkedUser),
      linked: true,
      created: result.meta.changes === 1,
    },
    result.meta.changes === 1 ? 201 : 200,
  );
}

async function deleteLink(
  db: D1Database,
  userId: string,
  linkedUserId: string,
): Promise<Response> {
  if (linkedUserId === userId) {
    throw new ApiError(404, "link_not_found", "Linked user not found.");
  }

  const [userAId, userBId] = canonicalLink(userId, linkedUserId);
  const result = await db
    .prepare("DELETE FROM links WHERE user_a_id = ? AND user_b_id = ?")
    .bind(userAId, userBId)
    .run();

  if (result.meta.changes === 0) {
    throw new ApiError(404, "link_not_found", "Linked user not found.");
  }

  return emptyResponse(204);
}

async function putCheckin(
  db: D1Database,
  userId: string,
  date: string,
  prayer: Prayer,
): Promise<Response> {
  const completedAt = new Date().toISOString();
  const result = await db
    .prepare(
      `INSERT INTO checkins (user_id, prayer_date, prayer, completed_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT (user_id, prayer_date, prayer) DO NOTHING`,
    )
    .bind(userId, date, prayer, completedAt)
    .run();

  return jsonResponse(
    { date, prayer, completed: true },
    result.meta.changes === 1 ? 201 : 200,
  );
}

async function deleteCheckin(
  db: D1Database,
  userId: string,
  date: string,
  prayer: Prayer,
): Promise<Response> {
  await db
    .prepare(
      "DELETE FROM checkins WHERE user_id = ? AND prayer_date = ? AND prayer = ?",
    )
    .bind(userId, date, prayer)
    .run();

  return emptyResponse(204);
}

async function getPrayerUsers(
  db: D1Database,
  userId: string,
  date: string,
): Promise<Response> {
  const result = await db
    .prepare(
      `SELECT c.prayer, u.id, u.nickname, u.avatar
       FROM checkins c
       JOIN users u ON u.id = c.user_id
       JOIN links l ON
         (l.user_a_id = ? AND l.user_b_id = c.user_id)
         OR (l.user_b_id = ? AND l.user_a_id = c.user_id)
       WHERE c.prayer_date = ?
       ORDER BY c.completed_at, u.id`,
    )
    .bind(userId, userId, date)
    .all<PrayerUserRow>();

  const prayers = emptyPrayerUsers();
  for (const row of result.results) {
    prayers[row.prayer].push(serializePublicUser(row));
  }

  return jsonResponse({ date, prayers });
}

async function authenticate(
  request: Request,
  db: D1Database,
): Promise<UserRow> {
  const authorization = request.headers.get("Authorization");
  const token = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : null;

  if (!token || !/^[0-9a-f]{64}$/i.test(token)) {
    throw new ApiError(401, "unauthorized", "A valid bearer token is required.");
  }

  const tokenHash = await sha256Hex(token.toLowerCase());
  const user = await db
    .prepare(
      `SELECT id, nickname, avatar, link_code, created_at, updated_at
       FROM users
       WHERE token_hash = ?
       LIMIT 1`,
    )
    .bind(tokenHash)
    .first<UserRow>();

  if (!user) {
    throw new ApiError(401, "unauthorized", "A valid bearer token is required.");
  }

  return user;
}

async function readJsonObject(
  request: Request,
): Promise<Record<string, unknown>> {
  const contentType = request.headers.get("Content-Type") ?? "";
  if (!contentType.toLowerCase().startsWith("application/json")) {
    throw new ApiError(415, "unsupported_media_type", "Expected JSON content.");
  }

  const contentLength = request.headers.get("Content-Length");
  if (
    contentLength !== null &&
    Number.isFinite(Number(contentLength)) &&
    Number(contentLength) > MAX_JSON_BODY_BYTES
  ) {
    throw new ApiError(413, "body_too_large", "JSON body is too large.");
  }

  if (!request.body) {
    throw new ApiError(400, "invalid_json", "A JSON object is required.");
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;

      if (totalBytes > MAX_JSON_BODY_BYTES) {
        await reader.cancel();
        throw new ApiError(413, "body_too_large", "JSON body is too large.");
      }

      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(
      new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes),
    );
  } catch {
    throw new ApiError(400, "invalid_json", "A valid JSON object is required.");
  }

  if (!isRecord(parsed)) {
    throw new ApiError(400, "invalid_json", "A JSON object is required.");
  }

  return parsed;
}

function validateNickname(value: string): string {
  const nickname = value.trim();
  if (
    nickname.length < 1 ||
    nickname.length > 30 ||
    containsControlCharacters(nickname)
  ) {
    throw new ApiError(
      400,
      "invalid_nickname",
      "Nickname must contain 1 to 30 visible characters.",
    );
  }
  return nickname;
}

function validateAvatar(value: string): string {
  const avatar = value.trim();
  if (
    avatar.length < 1 ||
    avatar.length > 100 ||
    containsControlCharacters(avatar)
  ) {
    throw new ApiError(
      400,
      "invalid_avatar",
      "Avatar must contain 1 to 100 visible characters.",
    );
  }
  return avatar;
}

function normalizeLinkCode(value: string): string {
  const compact = value.trim().toUpperCase().replace(/[\s-]/g, "");
  const allowedCharacters = new RegExp(
    `^[${LINK_CODE_ALPHABET}]{${LINK_CODE_LENGTH}}$`,
  );

  if (!allowedCharacters.test(compact)) {
    throw new ApiError(400, "invalid_code", "Enter a valid linking code.");
  }

  return formatLinkCode(compact);
}

function validateDate(value: string): string {
  const [yearText, monthText, dayText] = value.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const date = new Date(Date.UTC(year, month - 1, day));

  if (
    !Number.isInteger(year) ||
    year < 2000 ||
    year > 2100 ||
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw new ApiError(400, "invalid_date", "Date must use YYYY-MM-DD.");
  }

  return value;
}

function validatePrayer(value: string): Prayer {
  if (!isPrayer(value)) {
    throw new ApiError(400, "invalid_prayer", "Prayer is not supported.");
  }
  return value;
}

function isPrayer(value: string): value is Prayer {
  return PRAYERS.some((prayer) => prayer === value);
}

function emptyPrayerUsers(): PrayerUsers {
  return {
    fajr: [],
    dhuhr: [],
    asr: [],
    maghrib: [],
    isha: [],
  };
}

function generateLinkCode(): string {
  const characters: string[] = [];
  const unbiasedLimit =
    Math.floor(256 / LINK_CODE_ALPHABET.length) * LINK_CODE_ALPHABET.length;

  while (characters.length < LINK_CODE_LENGTH) {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    for (const byte of bytes) {
      if (byte >= unbiasedLimit) continue;
      const character = LINK_CODE_ALPHABET[byte % LINK_CODE_ALPHABET.length];
      if (character) characters.push(character);
      if (characters.length === LINK_CODE_LENGTH) break;
    }
  }

  return formatLinkCode(characters.join(""));
}

function formatLinkCode(value: string): string {
  return `${value.slice(0, 5)}-${value.slice(5)}`;
}

function randomHex(byteLength: number): string {
  const bytes = crypto.getRandomValues(new Uint8Array(byteLength));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

function serializeMe(user: UserRow): {
  id: string;
  nickname: string;
  avatar: string;
  linkCode: string;
  createdAt: string;
  updatedAt: string;
} {
  return {
    id: user.id,
    nickname: user.nickname,
    avatar: user.avatar,
    linkCode: user.link_code,
    createdAt: user.created_at,
    updatedAt: user.updated_at,
  };
}

function serializePublicUser(user: PublicUserRow): PublicUser {
  return { id: user.id, nickname: user.nickname, avatar: user.avatar };
}

function canonicalLink(firstUserId: string, secondUserId: string): [string, string] {
  return firstUserId < secondUserId
    ? [firstUserId, secondUserId]
    : [secondUserId, firstUserId];
}

function jsonResponse(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: responseHeaders(),
  });
}

function emptyResponse(status: number): Response {
  return new Response(null, { status, headers: responseHeaders() });
}

function responseHeaders(): Headers {
  return new Headers({
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  });
}

function normalizePathname(pathname: string): string {
  return pathname.length > 1 ? pathname.replace(/\/+$/, "") : pathname;
}

function requiredMatch(match: RegExpMatchArray, index: number): string {
  const value = match[index];
  if (!value) {
    throw new ApiError(404, "not_found", "Endpoint not found.");
  }
  return value;
}

function requireString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string") {
    throw new ApiError(400, "invalid_request", `${key} must be a string.`);
  }
  return value;
}

function optionalString(
  body: Record<string, unknown>,
  key: string,
): string | undefined {
  if (!(key in body)) return undefined;
  return requireString(body, key);
}

function assertOnlyKeys(
  body: Record<string, unknown>,
  allowedKeys: readonly string[],
): void {
  const unknownKey = Object.keys(body).find((key) => !allowedKeys.includes(key));
  if (unknownKey) {
    throw new ApiError(
      400,
      "invalid_request",
      `Unexpected field: ${unknownKey}.`,
    );
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function containsControlCharacters(value: string): boolean {
  return /[\u0000-\u001F\u007F]/.test(value);
}
