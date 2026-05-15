#!/bin/bash
# ============================================================
# Sileo Repo - Packages & Release 增量自动生成脚本 v2.0
# 核心特性：增量更新 | 缓存机制 | 强制全量 | 错误处理 | 跨平台兼容
# ============================================================

set -euo pipefail

# -------------------------- 配置区域 --------------------------
REPO_NAME="鸭鸭"
REPO_LABEL="Sileo Repo"
REPO_DESC="duck's Sileo jailbreak repository"
REPO_CODENAME="ios"
REPO_ARCH="iphoneos-arm64 iphoneos-arm64e"
REPO_COMPONENTS="main"
SUITE="stable"

# 缓存配置（核心增量功能）
CACHE_FILE=".repo_cache"  # 缓存文件，存储已处理deb的信息
FORCE_UPDATE=false        # 默认不强制全量更新
KEEP_SUBDEBS=false        # 是否保留子目录中的deb副本（默认复制到根目录后不删除原文件）
GENERATE_BZ2=false        # 是否同时生成 Packages.bz2（部分旧源需要）
# -------------------------------------------------------------

# 切换到脚本所在目录
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
            FORCE_UPDATE=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  -f, --force    强制全量重新生成所有包（忽略缓存）"
            echo "  -h, --help     显示此帮助信息"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 -h 查看帮助"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  Sileo Repo 增量生成器 v2.0"
echo "=========================================="

# 确保debs目录存在
mkdir -p debs

# 收集所有 .deb 到 debs/ 根目录（保留原文件）
echo "[*] 收集 debs 目录中的软件包..."
find debs -mindepth 2 -name "*.deb" | while read -r deb; do
    dest="debs/$(basename "$deb")"
    if [ ! -f "$dest" ] || [ "$deb" -nt "$dest" ]; then
        cp "$deb" "$dest"
        echo "    + 复制: $(basename "$deb")"
    fi
done

# 初始化变量
declare -A cache_entries  # 缓存字典: 文件名 -> 条目内容
declare -A cache_mtimes   # 缓存字典: 文件名 -> 修改时间
declare -A cache_sizes    # 缓存字典: 文件名 -> 文件大小
new_entries=()
updated_count=0
skipped_count=0
total_count=0

# 读取现有缓存（如果存在且不强制更新）
if [ "$FORCE_UPDATE" = false ] && [ -f "$CACHE_FILE" ]; then
    echo "[*] 加载缓存文件..."
    current_entry=""
    current_file=""
    while IFS= read -r line; do
        if [[ "$line" == "---CACHE_ENTRY_START---"* ]]; then
            current_file="${line#*:}"
            current_entry=""
        elif [[ "$line" == "---CACHE_ENTRY_END---"* ]]; then
            mtime="${line#*:mtime=}"
            size="${mtime#*:size=}"
            mtime="${mtime%:size=*}"
            cache_entries["$current_file"]="$current_entry"
            cache_mtimes["$current_file"]="$mtime"
            cache_sizes["$current_file"]="$size"
        else
            current_entry+="$line"$'\n'
        fi
    done < "$CACHE_FILE"
    echo "    ✓ 已加载 ${#cache_entries[@]} 个缓存条目"
fi

# 处理 debs/ 根目录下的所有 .deb
echo "[*] 检查软件包更新..."
for deb in debs/*.deb; do
    [ -f "$deb" ] || continue
    filename=$(basename "$deb")
    total_count=$((total_count + 1))
    
    # 获取当前文件的修改时间和大小
    current_mtime=$(stat -c %Y "$deb" 2>/dev/null || stat -f %m "$deb")  # 兼容Linux和macOS
    current_size=$(stat -c %s "$deb" 2>/dev/null || stat -f %z "$deb")
    
    # 检查是否需要处理（强制更新 | 新增 | 修改过）
    if [ "$FORCE_UPDATE" = true ] || \
       [ -z "${cache_entries["$filename"]:-}" ] || \
       [ "${cache_mtimes["$filename"]:-0}" -ne "$current_mtime" ] || \
       [ "${cache_sizes["$filename"]:-0}" -ne "$current_size" ]; then
        
        echo "    → 处理: $filename"
        # 提取deb控制信息
        control_info=$(dpkg-deb -f "$deb")
        # 计算哈希值
        md5=$(md5sum "$deb" | cut -d' ' -f1)
        sha1=$(sha1sum "$deb" | cut -d' ' -f1)
        sha256=$(sha256sum "$deb" | cut -d' ' -f1)
        sha512=$(sha512sum "$deb" 2>/dev/null | cut -d' ' -f1 || true)
        
        # 生成Packages条目
        entry="$control_info"$'\n'
        entry+="Filename: ./debs/$filename"$'\n'
        entry+="Size: $current_size"$'\n'
        entry+="MD5sum: $md5"$'\n'
        entry+="SHA1: $sha1"$'\n'
        entry+="SHA256: $sha256"$'\n'
        if [ -n "$sha512" ]; then
            entry+="SHA512: $sha512"$'\n'
        fi
        entry+=$'\n'
        
        new_entries+=("$entry")
        # 更新缓存
        cache_entries["$filename"]="$entry"
        cache_mtimes["$filename"]="$current_mtime"
        cache_sizes["$filename"]="$current_size"
        updated_count=$((updated_count + 1))
    else
        # 从缓存中读取条目
        new_entries+=("${cache_entries["$filename"]}")
        skipped_count=$((skipped_count + 1))
    fi
done

if [ "$total_count" -eq 0 ]; then
    echo "[!] 未找到任何 .deb 文件"
    exit 0
fi

echo "[*] 统计: 总计 $total_count 个包 | 更新 $updated_count 个 | 跳过 $skipped_count 个"

# 生成完整的Packages文件
echo "[*] 生成 Packages 文件..."
printf "%s" "${new_entries[*]}" > Packages

# 压缩
echo "[*] 正在压缩..."
gzip -9fc Packages > Packages.gz
if [ "$GENERATE_BZ2" = true ]; then
    bzip2 -9fc Packages > Packages.bz2
fi

# 计算文件信息用于Release
S_PKG=$(stat -c %s Packages 2>/dev/null || stat -f %z Packages)
S_GZ=$(stat -c %s Packages.gz 2>/dev/null || stat -f %z Packages.gz)

M_PKG=$(md5sum Packages | cut -d' ' -f1)
M_GZ=$(md5sum Packages.gz | cut -d' ' -f1)
S1_PKG=$(sha1sum Packages | cut -d' ' -f1)
S1_GZ=$(sha1sum Packages.gz | cut -d' ' -f1)
S2_PKG=$(sha256sum Packages | cut -d' ' -f1)
S2_GZ=$(sha256sum Packages.gz | cut -d' ' -f1)

# 生成 Release 文件
echo "[*] 生成 Release 文件..."
DATE=$(date -R)
cat > Release << EOF
Origin: $REPO_NAME
Label: $REPO_LABEL
Suite: $SUITE
Codename: $REPO_CODENAME
Architectures: $REPO_ARCH
Components: $REPO_COMPONENTS
Description: $REPO_DESC
Date: $DATE
MD5Sum:
 $M_PKG $S_PKG Packages
 $M_GZ $S_GZ Packages.gz
SHA1:
 $S1_PKG $S_PKG Packages
 $S1_GZ $S_GZ Packages.gz
SHA256:
 $S2_PKG $S_PKG Packages
 $S2_GZ $S_GZ Packages.gz
EOF

# 可选：添加Packages.bz2到Release
if [ "$GENERATE_BZ2" = true ]; then
    S_BZ2=$(stat -c %s Packages.bz2 2>/dev/null || stat -f %z Packages.bz2)
    M_BZ2=$(md5sum Packages.bz2 | cut -d' ' -f1)
    S1_BZ2=$(sha1sum Packages.bz2 | cut -d' ' -f1)
    S2_BZ2=$(sha256sum Packages.bz2 | cut -d' ' -f1)
    echo " $M_BZ2 $S_BZ2 Packages.bz2" >> Release
    sed -i "/SHA1:/a\ $S1_BZ2 $S_BZ2 Packages.bz2" Release
    sed -i "/SHA256:/a\ $S2_BZ2 $S_BZ2 Packages.bz2" Release
fi

# 保存新的缓存
echo "[*] 更新缓存文件..."
> "$CACHE_FILE"
for filename in "${!cache_entries[@]}"; do
    # 只保留当前存在的文件的缓存
    if [ -f "debs/$filename" ]; then
        echo "---CACHE_ENTRY_START---:$filename" >> "$CACHE_FILE"
        printf "%s" "${cache_entries["$filename"]}" >> "$CACHE_FILE"
        echo "---CACHE_ENTRY_END---:mtime=${cache_mtimes["$filename"]}:size=${cache_sizes["$filename"]}" >> "$CACHE_FILE"
    fi
done

echo "=========================================="
echo "  ✅ 生成完成！"
echo "  总计: $total_count 个软件包"
echo "  更新: $updated_count 个"
echo "  跳过: $skipped_count 个（使用缓存）"
echo "=========================================="
ls -lh Packages Packages.gz Release
if [ "$GENERATE_BZ2" = true ]; then
    ls -lh Packages.bz2
fi