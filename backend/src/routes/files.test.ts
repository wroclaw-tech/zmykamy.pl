import { describe, expect, setSystemTime, test } from "bun:test";
import app from "../index";
import { getDownloadUrl, getUploadUrl } from "../lib/storage";

const upload = async (key: string, body: string, contentType = "text/plain") =>
  app.request(getUploadUrl(key, contentType), {
    method: "PUT",
    body,
    headers: { "Content-Type": contentType },
  });

const randomKey = () => `tests/files/${crypto.randomUUID()}.txt`;

describe("file proxy", () => {
  test("stores an upload and serves it back", async () => {
    const key = randomKey();
    expect((await upload(key, "hello world")).status).toBe(200);
    const response = await app.request(getDownloadUrl(key));
    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toStartWith("text/plain");
    expect(response.headers.get("Content-Length")).toBe("11");
    expect(await response.text()).toBe("hello world");
  });

  test("serves byte ranges", async () => {
    const key = randomKey();
    await upload(key, "0123456789");
    const url = getDownloadUrl(key);
    const range = async (value: string) => app.request(url, { headers: { Range: value } });

    const middle = await range("bytes=2-5");
    expect(middle.status).toBe(206);
    expect(middle.headers.get("Content-Range")).toBe("bytes 2-5/10");
    expect(await middle.text()).toBe("2345");
    expect(await (await range("bytes=7-")).text()).toBe("789");
    expect(await (await range("bytes=-3")).text()).toBe("789");

    const outside = await range("bytes=20-");
    expect(outside.status).toBe(416);
    expect(outside.headers.get("Content-Range")).toBe("bytes */10");
  });

  test("rejects tampered, reused and expired urls", async () => {
    const key = randomKey();
    const uploadUrl = getUploadUrl(key, "text/plain");

    const otherKey = uploadUrl.replace(key, randomKey());
    const wrongType = { method: "PUT", body: "x", headers: { "Content-Type": "image/jpeg" } };
    const asDownload = await app.request(uploadUrl);
    expect((await app.request(otherKey, { ...wrongType, headers: {} })).status).toBe(403);
    expect((await app.request(uploadUrl, wrongType)).status).toBe(403);
    expect(asDownload.status).toBe(403);

    await upload(key, "x");
    const downloadUrl = getDownloadUrl(key);
    setSystemTime(new Date(Date.now() + 2 * 60 * 60 * 1000));
    try {
      const expired = await app.request(downloadUrl);
      expect(expired.status).toBe(403);
      expect(await expired.json()).toMatchObject({ error: { code: "url_expired" } });
    } finally {
      setSystemTime();
    }
  });

  test("returns 404 for a missing file", async () => {
    expect((await app.request(getDownloadUrl(randomKey()))).status).toBe(404);
  });
});
