---
name: verify-algorithm
description: 用 CSV 原始数据验证 UDP 测量算法，与算法工程师 Excel 结果对比
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
---

使用 weixing-udp-server 中的验证脚本，直接 import server 的 `computeDiameters_spline` 和 `processDiameterData` 函数，处理 CSV 原始数据并输出结果。

## 用法

```
/verify-algorithm <csv文件路径> [参数...]
```

## 执行步骤

1. 进入 `weixing-udp-server` 目录
2. 运行验证脚本：

```bash
cd /Users/yijun/Projects/Weixing/Weixing-LocalPC/weixing-udp-server
npx ts-node scripts/verify_algorithm.ts $ARGUMENTS 2>&1 | grep -v "已保存\|圆心:\|内圈圆心\|外圈圆心"
```

## 可用参数

所有参数可选，默认使用算法工程师参数：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `--outerCorr` | -18330 | 外径校正值 |
| `--innerCorr` | 4680 | 内径校正值 |
| `--factor` | 1 | maxValueAdjustmentFactor |
| `--calOuter` | 1 | 外径校准因子 |
| `--calInner` | 1 | 内径校准因子 |
| `--calWall` | 1 | 壁厚校准因子 |
| `--swOuter` | 60 | 外径平滑窗口 |
| `--swInner` | 60 | 内径平滑窗口 |
| `--swWall` | 60 | 壁厚平滑窗口 |
| `--frames` | 全部 | 只处理前 N 帧 |

## 示例

```bash
# 算法工程师参数（默认）
/verify-algorithm ~/Downloads/data.csv

# 现场参数
/verify-algorithm ~/Downloads/data.csv --outerCorr -18430 --innerCorr 4767 --factor 0.8 --calOuter 0.9996001599360256 --calWall 1.0160642570281122 --swOuter 90 --swInner 120 --swWall 150

# 快速验证前5帧
/verify-algorithm ~/Downloads/data.csv --frames 5
```

输出中位数统计和逐帧明细，用于与算法工程师的 Excel 对比。
