import { exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

type RegisteredUser = {
  user: {
    id: string;
    nickname: string;
    avatar: string;
    linkCode: string;
  };
  token: string;
};

const API_URL = "https://api.example.com";

describe("Salah Streak API", () => {
  it("reports service health without authentication", async () => {
    const response = await api("/health");
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ status: "ok" });
  });

  it("creates an anonymous user and authenticates with its private token", async () => {
    const registered = await register("Aisha", "avatar-aisha");

    expect(registered.user.linkCode).toMatch(/^[A-Z2-9]{5}-[A-Z2-9]{5}$/);
    expect(registered.token).toMatch(/^[0-9a-f]{64}$/);

    const response = await api("/v1/me", { token: registered.token });
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      user: {
        id: registered.user.id,
        nickname: "Aisha",
        avatar: "avatar-aisha",
      },
    });
  });

  it("links both users immediately without an acceptance step", async () => {
    const parent = await register("Parent");
    const child = await register("Child");

    const linkResponse = await api("/v1/links", {
      method: "POST",
      token: parent.token,
      body: { code: child.user.linkCode.toLowerCase().replace("-", " ") },
    });

    expect(linkResponse.status).toBe(201);
    await expect(linkResponse.json()).resolves.toMatchObject({
      user: { id: child.user.id, nickname: "Child" },
      linked: true,
      created: true,
    });

    const childLinks = await api("/v1/links", { token: child.token });
    await expect(childLinks.json()).resolves.toEqual({
      users: [
        {
          id: parent.user.id,
          nickname: "Parent",
          avatar: "person.crop.circle.fill",
        },
      ],
    });
  });

  it("shows only linked users who completed each prayer", async () => {
    const viewer = await register("Viewer");
    const linked = await register("Linked", "avatar-linked");
    const stranger = await register("Stranger", "avatar-stranger");

    await api("/v1/links", {
      method: "POST",
      token: viewer.token,
      body: { code: linked.user.linkCode },
    });
    await api("/v1/checkins/2026-08-25/fajr", {
      method: "PUT",
      token: linked.token,
    });
    await api("/v1/checkins/2026-08-25/fajr", {
      method: "PUT",
      token: stranger.token,
    });

    const response = await api("/v1/prayers/2026-08-25", {
      token: viewer.token,
    });
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      date: "2026-08-25",
      prayers: {
        fajr: [
          {
            id: linked.user.id,
            nickname: "Linked",
            avatar: "avatar-linked",
          },
        ],
        dhuhr: [],
        asr: [],
        maghrib: [],
        isha: [],
      },
    });
  });

  it("removes check-ins and links", async () => {
    const first = await register("First");
    const second = await register("Second");

    await api("/v1/links", {
      method: "POST",
      token: first.token,
      body: { code: second.user.linkCode },
    });
    await api("/v1/checkins/2026-08-25/isha", {
      method: "PUT",
      token: second.token,
    });

    const cleared = await api("/v1/checkins/2026-08-25/isha", {
      method: "DELETE",
      token: second.token,
    });
    expect(cleared.status).toBe(204);

    const unlinked = await api(`/v1/links/${second.user.id}`, {
      method: "DELETE",
      token: first.token,
    });
    expect(unlinked.status).toBe(204);

    const links = await api("/v1/links", { token: first.token });
    await expect(links.json()).resolves.toEqual({ users: [] });
  });

  it("updates the profile, rotates the linking code, and deletes the account", async () => {
    const registered = await register("Old nickname");

    const updated = await api("/v1/me", {
      method: "PATCH",
      token: registered.token,
      body: { nickname: "New nickname", avatar: "new-avatar" },
    });
    expect(updated.status).toBe(200);
    await expect(updated.json()).resolves.toMatchObject({
      user: { nickname: "New nickname", avatar: "new-avatar" },
    });

    const rotated = await api("/v1/me/link-code", {
      method: "POST",
      token: registered.token,
    });
    expect(rotated.status).toBe(200);
    const rotatedBody = await rotated.json<{ linkCode: string }>();
    expect(rotatedBody.linkCode).not.toBe(registered.user.linkCode);

    const deleted = await api("/v1/me", {
      method: "DELETE",
      token: registered.token,
    });
    expect(deleted.status).toBe(204);

    const afterDeletion = await api("/v1/me", { token: registered.token });
    expect(afterDeletion.status).toBe(401);
  });

  it("rejects invalid authentication and malformed input", async () => {
    const unauthorized = await api("/v1/me");
    expect(unauthorized.status).toBe(401);

    const invalidDate = await api("/v1/prayers/2026-02-30", {
      token: (await register("Date tester")).token,
    });
    expect(invalidDate.status).toBe(400);
    await expect(invalidDate.json()).resolves.toMatchObject({
      error: { code: "invalid_date" },
    });
  });
});

async function register(
  nickname: string,
  avatar?: string,
): Promise<RegisteredUser> {
  const body: { nickname: string; avatar?: string } = { nickname };
  if (avatar) body.avatar = avatar;

  const response = await api("/v1/users", { method: "POST", body });
  expect(response.status).toBe(201);
  return response.json<RegisteredUser>();
}

async function api(
  path: string,
  options: {
    method?: string;
    token?: string;
    body?: Record<string, unknown>;
  } = {},
): Promise<Response> {
  const headers = new Headers();
  if (options.token) headers.set("Authorization", `Bearer ${options.token}`);
  if (options.body) headers.set("Content-Type", "application/json");

  const requestInit: RequestInit = {
    method: options.method ?? "GET",
    headers,
  };
  if (options.body) requestInit.body = JSON.stringify(options.body);

  return exports.default.fetch(`${API_URL}${path}`, requestInit);
}
