import {test, expect} from "@playwright/test";

test.describe.configure({mode: "serial"});

test("first run creates vault and unsaved text is immediately searchable", async ({page}) => {
  const runtimeErrors = captureRuntimeErrors(page, new Set(["GET /api/vault 404"]));
  await page.goto("/");
  await page.getByLabel("访问口令").fill("e2e-access-token");
  await page.getByRole("button", {name: "进入"}).click();

  await page.getByLabel("新主密码", {exact: true}).fill("daily-vault-passphrase");
  await page.getByLabel("重复主密码", {exact: true}).fill("daily-vault-passphrase");
  await page.getByRole("button", {name: "创建保险库"}).click();

  await expect(page.getByRole("searchbox", {name: "搜索条目"})).toBeVisible();
  await page.getByRole("button", {name: "新建条目"}).click();
  await page.getByRole("textbox", {name: "条目内容"}).fill("客户B 1.2.3.4 宝塔");
  await page.getByRole("searchbox", {name: "搜索条目"}).fill("1.2.3.4");
  await expect(page.getByRole("option", {name: /客户B/})).toBeVisible();
  await expect(page.getByText("未保存", {exact: true})).toBeVisible();

  await page.getByRole("button", {name: "保存", exact: true}).click();
  await expect(page.getByText("已保存", {exact: true})).toBeVisible();
  await page.screenshot({path: "/tmp/text-vault-desktop.png", fullPage: true});
  expect(runtimeErrors).toEqual([]);
});

test("saved text survives a reload and mobile navigation stays usable", async ({page}) => {
  const runtimeErrors = captureRuntimeErrors(page);
  await page.setViewportSize({width: 390, height: 844});
  await page.goto("/");
  await page.getByLabel("访问口令").fill("e2e-access-token");
  await page.getByRole("button", {name: "进入"}).click();
  await page.getByLabel("主密码").fill("daily-vault-passphrase");
  await page.getByRole("button", {name: "解锁"}).click();

  await expect(page.getByRole("textbox", {name: "条目内容"})).toHaveValue("客户B 1.2.3.4 宝塔");
  await expect(page.getByRole("button", {name: "返回结果"})).toBeVisible();
  await page.getByRole("button", {name: "返回结果"}).click();
  await page.getByRole("searchbox", {name: "搜索条目"}).fill("1.2.3.4");
  await page.getByRole("option", {name: /客户B/}).click();
  await expect(page.getByRole("textbox", {name: "条目内容"})).toHaveValue("客户B 1.2.3.4 宝塔");
  await page.screenshot({path: "/tmp/text-vault-iphone.png", fullPage: true});
  expect(runtimeErrors).toEqual([]);
});

function captureRuntimeErrors(page, allowedResponses = new Set()) {
  const errors = [];
  page.on("console", message => {
    if (message.type() === "error" && !message.text().startsWith("Failed to load resource:")) errors.push(message.text());
  });
  page.on("pageerror", error => errors.push(error.message));
  page.on("response", response => {
    if (response.status() < 400) return;
    const request = response.request();
    const url = new URL(response.url());
    const summary = `${request.method()} ${url.pathname} ${response.status()}`;
    if (!allowedResponses.has(summary)) errors.push(summary);
  });
  return errors;
}
