#!/usr/bin/env python3
"""
共享工具脚本示例
包含常用的数据处理和机器学习工具函数
"""

import os
import numpy as np
import pandas as pd
from pathlib import Path

def load_dataset(dataset_path, file_format='csv'):
    """
    加载数据集的通用函数
    
    Args:
        dataset_path (str): 数据集路径
        file_format (str): 文件格式 ('csv', 'json', 'parquet')
    
    Returns:
        pandas.DataFrame: 加载的数据
    """
    dataset_path = Path(dataset_path)
    
    if not dataset_path.exists():
        raise FileNotFoundError(f"数据集文件不存在: {dataset_path}")
    
    if file_format == 'csv':
        return pd.read_csv(dataset_path)
    elif file_format == 'json':
        return pd.read_json(dataset_path)
    elif file_format == 'parquet':
        return pd.read_parquet(dataset_path)
    else:
        raise ValueError(f"不支持的文件格式: {file_format}")

def preprocess_text(text_series, remove_punctuation=True, lowercase=True):
    """
    文本预处理函数
    
    Args:
        text_series (pd.Series): 文本数据
        remove_punctuation (bool): 是否移除标点符号
        lowercase (bool): 是否转换为小写
    
    Returns:
        pd.Series: 预处理后的文本
    """
    import re
    
    processed = text_series.copy()
    
    if lowercase:
        processed = processed.str.lower()
    
    if remove_punctuation:
        processed = processed.str.replace(r'[^\w\s]', '', regex=True)
    
    # 移除多余空格
    processed = processed.str.strip().str.replace(r'\s+', ' ', regex=True)
    
    return processed

def split_train_val_test(data, train_ratio=0.7, val_ratio=0.15, test_ratio=0.15, random_state=42):
    """
    数据集划分函数
    
    Args:
        data (pd.DataFrame): 输入数据
        train_ratio (float): 训练集比例
        val_ratio (float): 验证集比例
        test_ratio (float): 测试集比例
        random_state (int): 随机种子
    
    Returns:
        tuple: (train_data, val_data, test_data)
    """
    from sklearn.model_selection import train_test_split
    
    assert abs(train_ratio + val_ratio + test_ratio - 1.0) < 1e-6, "比例之和必须为1"
    
    # 首先分离出测试集
    train_val_data, test_data = train_test_split(
        data, test_size=test_ratio, random_state=random_state
    )
    
    # 再从训练+验证集中分离出验证集
    val_size = val_ratio / (train_ratio + val_ratio)
    train_data, val_data = train_test_split(
        train_val_data, test_size=val_size, random_state=random_state
    )
    
    return train_data, val_data, test_data

def setup_reproducible_training(seed=42):
    """
    设置可复现的训练环境
    
    Args:
        seed (int): 随机种子
    """
    import random
    import torch
    
    # 设置Python随机种子
    random.seed(seed)
    
    # 设置NumPy随机种子
    np.random.seed(seed)
    
    # 设置PyTorch随机种子
    torch.manual_seed(seed)
    torch.cuda.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    
    # 确保CUDA操作的确定性
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
    
    print(f"✅ 已设置随机种子为 {seed}，确保训练可复现")

def get_gpu_info():
    """
    获取GPU信息
    
    Returns:
        dict: GPU信息字典
    """
    try:
        import torch
        
        if not torch.cuda.is_available():
            return {"available": False, "message": "CUDA不可用"}
        
        gpu_count = torch.cuda.device_count()
        current_device = torch.cuda.current_device()
        device_name = torch.cuda.get_device_name(current_device)
        memory_total = torch.cuda.get_device_properties(current_device).total_memory
        memory_allocated = torch.cuda.memory_allocated(current_device)
        memory_free = memory_total - memory_allocated
        
        return {
            "available": True,
            "gpu_count": gpu_count,
            "current_device": current_device,
            "device_name": device_name,
            "memory_total_gb": memory_total / (1024**3),
            "memory_allocated_gb": memory_allocated / (1024**3),
            "memory_free_gb": memory_free / (1024**3)
        }
    except ImportError:
        return {"available": False, "message": "PyTorch未安装"}

if __name__ == "__main__":
    # 示例用法
    print("=== 共享工具脚本示例 ===")
    
    # 显示GPU信息
    gpu_info = get_gpu_info()
    print(f"GPU信息: {gpu_info}")
    
    # 设置可复现训练
    setup_reproducible_training()
    
    print("\n可用函数:")
    print("- load_dataset(): 加载数据集")
    print("- preprocess_text(): 文本预处理")
    print("- split_train_val_test(): 数据集划分")
    print("- setup_reproducible_training(): 设置可复现训练")
    print("- get_gpu_info(): 获取GPU信息")