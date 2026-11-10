# 代码与镜像发布流程

## 固定顺序

1. 确认本次涉及的仓库和改动；保留无关的用户工作，不使用 `git add -A` 混入其他修改。
2. 跑相关业务回归、类型检查和构建检查，复核最终 diff。
3. 按仓库提交本次文件，记录 commit SHA；先推送 Git 分支，再发布镜像。
4. 在相应仓库运行 `bash build.sh`。默认构建并推送 `linux/amd64,linux/arm64`，不再默认只构建 amd64。
5. 检查远端版本标签与 `latest` 的摘要一致、双平台齐全；必要时对两种架构做运行检查。
6. 分别报告：代码 commit/推送结果、镜像标签/摘要/平台、现场是否已部署。构建、镜像推送和现场更新是三个独立状态。

## build.sh 自动保证的事项

- 必须处于有上游的 Git 分支；跟踪文件的修改、暂存修改及未跟踪文件均会阻止发布。
- 通过 fetch 核验当前 commit 已包含在上游分支中；本地尚未推送的 commit 不能发布。
- 从这个 commit 导出临时源码快照，并让 Docker 正常应用仓库里的 `.dockerignore`。构建不读取未跟踪 `.env`，也不靠手工 tar 规则筛源码。
- 镜像版本为 `YYYY.MM.DD-<12位commit>`，日期使用 Asia/Shanghai；revision label 保存完整 SHA，不能带 `-dirty`。
- 默认推送 `latest` 与 commit 版本标签。功能名称不能替代可追溯的版本；显式 `-t` 只作为额外别名，commit 版本始终保留。
- 发布后核对远端摘要及多平台清单；核验失败则脚本失败，不能报告成功。
- 复用 Buildx 构建器，不改变用户默认构建器，不删除共享缓存。只清理本次临时源码目录。
- 不自动提交用户文件、不自动更新现场容器。没有有效 commit 时不能用旧 SHA 加 `dirty` 冒充发布版本。

现阶段已应用于 weixing-service、weixing-tcp-server、weixing-frontend 的 build.sh。

## 日常调用

```bash
# 先按文件选择提交，再推送当前分支
# git add <本次相关文件>
# git commit -m '<描述>'
# git push

# 在对应仓库运行；自动构建和推送双平台
bash build.sh
```

原有 `--push`、`-p/--platform`、`-t/--tag`、`-r/--registry`、`-n/--name` 调用仍兼容。
只有用户明确要求时，才用 `-p linux/amd64` 或 `-p linux/arm64` 单平台发布。
如果当前分支没有上游，先执行 `git push -u <remote> <branch>`。
若存在无关修改，应先明确它们的归属，或在独立干净工作区发布；不能擅自提交、删除、隐藏它们来通过检查。

## 代理与构建器

可用 `WEIXING_BUILDER` 指定构建器名称。已有构建器会直接复用；代理配置改变时，可指定一个新名称，避免删除其他任务缓存。
CLI 代理和 BuildKit 容器代理可能需要不同地址，例如 macOS 的本机代理：

```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export WEIXING_BUILDKIT_HTTP_PROXY=http://host.docker.internal:7890
export WEIXING_BUILDKIT_HTTPS_PROXY=http://host.docker.internal:7890
bash build.sh
```

配置了 `FLEET_API_URL` 与 `FLEET_TOKEN` 时，镜像核验成功后登记设备看板版本。
登记失败会明确提示，但不会把已经成功推送的镜像说成未推送。

## 回归验证

```bash
python3 -m unittest discover -s weixing-setup/tests -p 'test_*.py' -v
```

测试使用一次性 Git 仓库与本地 bare 上游，并用替代 Docker 命令记录操作，不向真实 Git/镜像仓库推送。
覆盖三个仓库各九种情况：未提交修改、未跟踪文件、未推送 commit、正常双平台发布、缺少 arm64、远端摘要不一致、自定义别名仍更新 latest、单平台正确与错误架构。

## 当前历史镜像

先前的 `2026.11.06-no-code` 是工作区快照构建的历史镜像，不是 commit 版本。
不能通过改标签把它变成干净 commit 构建；后续应在对应代码提交并推送后，按本流程重新构建。
