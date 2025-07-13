# 共享数据集目录

这个目录用于存放所有用户共享的数据集。

## 使用说明

### 管理员添加数据集

1. 将数据集文件放到此目录下
2. 创建对应的说明文档
3. 确保文件权限正确（所有用户可读）

### 用户使用数据集

在容器中，可以通过 `/shared/datasets/` 路径访问：

```bash
# 查看可用数据集
ls /shared/datasets/

# 在代码中使用
import pandas as pd
data = pd.read_csv('/shared/datasets/example_dataset.csv')
```

## 推荐的数据集组织结构

```
datasets/
├── mnist/
│   ├── train/
│   ├── test/
│   └── README.md
├── cifar10/
│   ├── data/
│   └── README.md
└── text_classification/
    ├── train.csv
    ├── test.csv
    └── README.md
```

## 添加新数据集的步骤

1. **创建数据集目录**：
   ```bash
   mkdir -p datasets/new_dataset_name
   ```

2. **添加数据文件**：
   ```bash
   cp your_data_files datasets/new_dataset_name/
   ```

3. **创建说明文档**：
   ```bash
   cat > datasets/new_dataset_name/README.md << 'EOF'
   # 数据集名称
   
   ## 描述
   数据集的详细描述
   
   ## 格式
   数据文件的格式说明
   
   ## 使用示例
   如何加载和使用这个数据集
   EOF
   ```

4. **设置权限**：
   ```bash
   chmod -R 755 datasets/new_dataset_name
   ```

## 数据集清单

目前可用的数据集：

- **示例数据集** (即将添加)
  - 描述：机器学习入门示例数据
  - 路径：`/shared/datasets/examples/`
  - 格式：CSV, JSON

*管理员可以在这里添加更多数据集的说明*