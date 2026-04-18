---
name: pull-all
description: 拉取 Weixing-LocalPC 下所有 git 仓库的最新代码
disable-model-invocation: true
allowed-tools:
  - Bash
---

拉取工作区下所有 weixing-* 仓库的最新代码。

执行以下命令：

```bash
for dir in /Users/yijun/Projects/Weixing/Weixing-LocalPC/weixing-*/; do
  name=$(basename "$dir")
  if [ -d "$dir/.git" ]; then
    echo "=== $name ==="
    git -C "$dir" pull 2>&1
    echo
  fi
done
```

输出每个仓库的拉取结果，简要告诉用户哪些仓库有更新、哪些已是最新。
