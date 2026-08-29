# Text Vault

一个搜索优先、只在浏览器内解密的纯文本工作台。编辑、新建、切换和搜索都发生在统一内存仓库中；界面只有一个全局“保存”，它把所有未保存对象作为一次事务提交到服务器。

## 当前功能

- 无标题纯文本条目，输入即全文搜索
- 桌面左侧结果、右侧编辑，分隔线可拖动
- 底部查询标签；“固定 ＋”保留当前搜索并打开一个空标签
- 手机列表/内容单页切换
- 工作区、标签、查询、选择和分栏宽度随全局保存一起恢复
- 未保存离开页面时使用浏览器原生提醒
- PBKDF2-SHA-256 + AES-256-GCM 客户端加密；服务器只保存密文
- SQLite WAL、对象历史版本、乐观并发和事务化全局保存
- 单二进制部署和一致性 SQLite 备份

这是在线优先的单用户 MVP。当前不支持离线、附件、多人协作、服务端搜索或忘记主密码后的恢复。

## 本地运行

环境：Void Linux `go1.26.5 linux/amd64`，Node.js 只用于测试，生产不需要 npm。

```sh
cd apps/text-vault
export TEXT_VAULT_ACCESS_TOKEN='换成一段足够长的随机访问口令'
go run ./cmd/text-vault serve -listen 127.0.0.1:8080 -database ./data/text-vault.db -secure-cookie=false
```

打开 `http://127.0.0.1:8080`。首次进入时创建主密码；访问口令负责挡住互联网访客，主密码负责解密数据，两者用途不同。部署到公网时不要使用 `-secure-cookie=false`。

## 构建与测试

```sh
CGO_ENABLED=0 go build -trimpath -o text-vault ./cmd/text-vault
go test ./...
npm install
npm run test:unit
npm run test:e2e
```

VanJS 已固定并放进 `web/vendor`，因此生产二进制不访问 CDN，也没有 Node 运行时。

## 备份与恢复

运行中的服务可以安全地生成一致性快照：

```sh
./text-vault backup -database ./data/text-vault.db -output ./backups/text-vault-2026-08-29.db
```

输出文件必须不存在，避免误覆盖。备份仍是密文数据库，但访问口令不在数据库里；恢复时同时准备原主密码，并重新设置 `TEXT_VAULT_ACCESS_TOKEN`。恢复只需停服务，把选定备份作为 `-database` 指向的文件，再启动服务。建议把多个日期的数据库复制到至少两个独立位置，并定期实际演练解锁。

## 生产部署

推荐让程序只监听回环地址，由 Caddy 提供 HTTPS。示例见 [deploy/Caddyfile.example](deploy/Caddyfile.example) 和 [deploy/runit/run](deploy/runit/run)。

部署要点：

- 使用专用低权限用户和权限为 `0700` 的数据目录。
- 用 runit `envdir` 文件提供访问口令，文件权限设为 `0600`，不要把口令写进仓库或命令行历史。
- 公网必须使用 HTTPS，并保持 `-secure-cookie=true`。
- Caddy、SQLite 数据库、备份目录和二进制都放在你明确管理的位置，不依赖宝塔面板状态。
- 浏览器内明文不能抵御已经解锁的设备被当场检查；离开前先全局保存，再关闭页面并使用 DuckDuckGo 的清数据功能。

## 数据边界

SQLite 中只有加密对象、版本号、对象类型、更新时间及加密参数。条目正文、搜索词、标签查询、工作区布局和密钥明文不会写入 URL、localStorage、IndexedDB 或服务器日志。对象类型目前预留 `entry`、`workspace`、`query`、`view`；以后可在保持相同“对象 → 查询 → 视图”边界的前提下加入 TSV、附件引用和专用查看器。

