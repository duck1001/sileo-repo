#!/bin/bash
# ============================================================
# Sileo Repo - Packages & Release 增量自动生成脚本 v2.2
# 修复：致命的前导空格问题 | 优化：纯流写入，无数组拼接
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

CACHE_FILE=".repo_cache"
FORCE_UPDATE=false
GENERATE_BZ2=false
# -------------------------------------------------------------

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force) FORCE_UPDATE=true; shift ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "  -f, --force    强制全量重新生成"
            echo "  -h, --help     显示帮助"
            exit 0 ;;
        *) echo "未知选项: $1"; exit 1 ;;
    esac
done

echo "=========================================="
echo "  Sileo Repo 增量生成器 v2.2"
echo "=========================================="

mkdir -p debs

# 收集子目录的deb
echo "[*] 收集软件包..."
find debs -mindepth 2 -name "*.deb" -print0 | while IFS= read -r -d '' deb; do
    dest="debs/$(basename "$deb")"
    if [ ! -f "$dest" ] || [ "$deb" -nt "$dest" ]; then
        cp "$deb" "$dest"
        echo "    + 复制: $(basename "$deb")"
    fi
done

# 加载缓存
declare -A cache=()
if [ "$FORCE_UPDATE" = false ] && [ -f "$CACHE_FILE" ]; then
    echo "[*] 加载缓存..."
    current_key=""
    current_entry=""
    while IFS= read -r line; do
        if [[ "$line" == "===CACHE_START==="* ]]; then
            current_key="${line#===CACHE_START===}"
            current_entry=""
        elif [[ "$line" == "===CACHE_END===" ]]; then
            cache["$current_key"]="$current_entry"
        else
            current_entry+="$line"$'\n'
        fi
    done < "$CACHE_FILE"
    echo "    ✓ 已加载 ${#cache[@]} 个缓存条目"
fi

# 清空Packages文件，准备写入
> Packages
updated=0
skipped=0
total=0

echo "[*] 处理软件包..."
for deb in debs/*.deb; do
    [ -f "$deb" ] || continue
    filename=$(basename "$deb")
    total=$((total + 1))
    
    # 生成缓存键（文件名+修改时间+大小）
    mtime=$(stat -c %Y "$deb")
    size=$(stat -c %s "$deb")
    key="$filename:$mtime:$size"
    
    if [ "$FORCE_UPDATE" = false ] && [ -n "${cache["$key"]:-}" ]; then
        # 直接写入缓存内容（确保没有前导空格）
        echo -n "${cache["$key"]}" >> Packages
        skipped=$((skipped + 1))
    else
        # 重新生成并写入
        echo "    → 处理: $filename"
        control=$(dpkg-deb -f "$deb")
        md5=$(md5sum "$deb" | awk '{print $1}')
        sha1=$(sha1sum "$deb" | awk '{print $1}')
        sha256=$(sha256sum "$deb" | awk '{print $1}')
        sha512=$(sha512sum "$deb" 2>/dev/null | awk '{print $1}' || true)
        
        # 生成条目（严格保证Package顶格）
        entry="$control"$'\n'
        entry+="Filename: ./debs/$filename"$'\n'
        entry+="Size: $size"$'\n'
        entry+="MD5sum: $md5"$'\n'
        entry+="SHA1: $sha1"$'\n'
        entry+="SHA256: $sha256"$'\n'
        [ -n "$sha512" ] && entry+="SHA512: $sha512"$'\n'
        entry+=$'\n'
        
        # 直接写入文件，避免数组拼接产生空格
        echo -n "$entry" >> Packages
        cache["$key"]="$entry"
        updated=$((updated + 1))
    fi
done

if [ "$total" -eq 0 ]; then
    echo "[!] 未找到任何deb文件"
    exit 0
fi

echo "[*] 统计: 总计 $total | 更新 $updated | 跳过 $skipped"

# 压缩
echo "[*] 压缩中..."
gzip -9fc Packages > Packages.gz
$GENERATE_BZ2 && bzip2 -9fc Packages > Packages.bz2

# 生成Release
echo "[*] 生成Release..."
DATE=$(date -R)
S_PKG=$(stat -c %s Packages)
S_GZ=$(stat -c %s Packages.gz)
M_PKG=$(md5sum Packages | awk '{print $1}')
M_GZ=$(md5sum Packages.gz | awk '{print $1}')
S1_PKG=$(sha1sum Packages | awk '{print $1}')
S1_GZ=$(sha1sum Packages.gz | awk '{print $1}')
S2_PKG=$(sha256sum Packages | awk '{print $1}')
S2_GZ=$(sha256sum Packages.gz | awk '{print $1}')

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

# 保存新缓存
echo "[*] 更新缓存文件..."
> "$CACHE_FILE"
for key in "${!cache[@]}"; do
    echo "===CACHE_START===$key" >> "$CACHE_FILE"
    echo -n "${cache["$key"]}" >> "$CACHE_FILE"
    echo "===CACHE_END===" >> "$CACHE_FILE"
done

echo "=========================================="
echo "  ✅ 生成完成！"
echo "  总计: $total 个软件包"
echo "  更新: $updated 个"
echo "  跳过: $skipped 个"
echo "=========================================="
ls -lh Packages Packages.gz Release