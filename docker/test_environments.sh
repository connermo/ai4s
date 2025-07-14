#!/bin/bash

echo "=== 深度学习环境测试 ==="

echo ""
echo "1. 测试PyTorch环境 (主环境)"
echo "PyTorch版本:"
python3 -c "import torch; print(f'PyTorch: {torch.__version__}')" 2>/dev/null || echo "PyTorch未安装或导入失败"

echo ""
echo "PyTorch GPU支持:"
python3 -c "import torch; print(f'CUDA可用: {torch.cuda.is_available()}'); print(f'GPU数量: {torch.cuda.device_count()}')" 2>/dev/null || echo "GPU检测失败"

echo ""
echo "2. 测试TensorFlow环境 (conda环境)"
echo "TensorFlow版本:"
conda run -n tf python -c "import tensorflow as tf; print(f'TensorFlow: {tf.__version__}')" 2>/dev/null || echo "TensorFlow未安装或导入失败"

echo ""
echo "TensorFlow GPU支持:"
conda run -n tf python -c "import tensorflow as tf; print(f'GPU设备: {tf.config.list_physical_devices(\"GPU\")}')" 2>/dev/null || echo "TensorFlow GPU检测失败"

echo ""
echo "3. 环境信息"
echo "Conda环境列表:"
conda info --envs

echo ""
echo "4. 便捷命令测试"
echo "使用 'tf' 命令激活TensorFlow环境"
echo "使用 'tfexit' 命令退出TensorFlow环境"
echo "使用 'tftest' 命令测试TensorFlow环境"
echo "使用 'tfjupyter' 启动TensorFlow专用Jupyter"

echo ""
echo "=== 测试完成 ===" 