# 共享模型目录

这个目录用于存放预训练模型和共享的模型文件。

## 目录用途

- 存放预训练的深度学习模型
- 共享训练好的模型权重
- 提供模型配置文件和使用说明

## 使用方法

### 在代码中加载共享模型

```python
import torch

# 加载PyTorch模型
model = torch.load('/shared/models/resnet50_pretrained.pth')

# 或者加载模型权重
model.load_state_dict(torch.load('/shared/models/my_model_weights.pth'))
```

### TensorFlow模型

```python
import tensorflow as tf

# 加载SavedModel格式
model = tf.keras.models.load_model('/shared/models/tensorflow_model/')

# 加载权重
model.load_weights('/shared/models/model_weights.h5')
```

## 推荐的模型组织结构

```
models/
├── pytorch/
│   ├── resnet50/
│   │   ├── model.pth
│   │   ├── config.json
│   │   └── README.md
│   └── bert/
│       ├── pytorch_model.bin
│       ├── config.json
│       └── tokenizer_config.json
├── tensorflow/
│   ├── mobilenet/
│   │   ├── saved_model.pb
│   │   ├── variables/
│   │   └── README.md
│   └── transformer/
│       ├── model.h5
│       └── config.json
└── onnx/
    ├── yolo/
    │   ├── model.onnx
    │   └── README.md
    └── efficientnet/
        ├── model.onnx
        └── README.md
```

## 添加新模型

### 1. 创建模型目录

```bash
mkdir -p models/framework_name/model_name
```

### 2. 添加模型文件

```bash
# 复制模型文件
cp your_model_files models/framework_name/model_name/

# 设置权限
chmod -R 755 models/framework_name/model_name
```

### 3. 创建说明文档

```bash
cat > models/framework_name/model_name/README.md << 'EOF'
# 模型名称

## 模型描述
- 模型架构：
- 训练数据：
- 性能指标：

## 文件说明
- `model.pth` - PyTorch模型文件
- `config.json` - 模型配置
- `requirements.txt` - 依赖包

## 使用示例
```python
import torch
model = torch.load('/shared/models/framework_name/model_name/model.pth')
```

## 引用
如果使用此模型，请引用相关论文
EOF
```

## 模型清单

目前可用的模型：

*管理员可以在这里添加可用模型的列表*

## 注意事项

1. **文件大小**: 大型模型文件建议压缩存储
2. **版本管理**: 重要模型建议保留多个版本
3. **文档完整**: 每个模型都应该有详细的使用说明
4. **许可证**: 注意模型的使用许可和引用要求