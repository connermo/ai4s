#!/bin/bash

echo "=== 组目录写权限测试 ==="
echo ""

USER=$(whoami)
echo "当前用户: $USER"
echo "用户ID: $(id -u)"  
echo "主组ID: $(id -g)"
echo "所属组: $(groups)"
echo ""

if [ ! -d "/groups" ]; then
    echo "错误: /groups 目录不存在"
    exit 1
fi

echo "检查 /groups 目录权限:"
ls -la /groups
echo ""

# 测试每个组目录的写权限
for group_dir in /groups/*; do
    if [ -d "$group_dir" ]; then
        group_name=$(basename "$group_dir")
        echo "测试组目录: $group_name"
        echo "  权限: $(ls -ld "$group_dir")"
        
        # 检查用户是否在该组中
        if groups | grep -q "$group_name"; then
            echo "  ✓ 用户属于组 $group_name"
            
            # 测试写权限
            test_file="$group_dir/test_write_$(date +%s).txt"
            if echo "测试写入" > "$test_file" 2>/dev/null; then
                echo "  ✓ 写权限正常 - 成功创建测试文件"
                rm -f "$test_file" 2>/dev/null
            else
                echo "  ✗ 写权限失败 - 无法创建文件"
                echo "    详细错误:"
                echo "测试写入" > "$test_file"
            fi
        else
            echo "  - 用户不属于组 $group_name，跳过写权限测试"
        fi
        echo ""
    fi
done

echo "权限检查完成"