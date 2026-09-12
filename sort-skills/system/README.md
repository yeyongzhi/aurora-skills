# system · 系统与本机

这台机器本身的维护与诊断。

**收纳**：磁盘与存储、进程与服务、网络连通性排查、性能与资源诊断、系统配置、权限与账户、本机软件管理。

**不收纳**：CI/CD 与服务器部署 → [`devops/`](../devops)；代码层面的性能问题 → [`development/engineering`](../development/engineering)。

**规则**：涉及删除、格式化、改注册表、改系统配置的 skill，必须在 `SKILL.md` 里写「安全红线」，默认只读、默认二次确认。

**已有**：[`disk-space-analyzer`](disk-space-analyzer) —— 扫描 Windows 磁盘占用并生成 HTML 报告（只统计，不删除）
