#!/bin/sh
# ============================================================
# Sileo Repo 生成脚本 - Filza / sh 兼容版 v2.5
# 支持增量：已处理过的 deb 直接复用缓存，不再重算哈希
# ============================================================

# 配置区域
REPO_NAME="鸭鸭"
REPO_LABEL="Sileo Repo"
REPO_DESC="duck's Sileo jailbreak repository"
REPO_CODENAME="ios"
REPO_ARCH="iphoneos-arm64 iphoneos-arm64e"
REPO_COMPONENTS="main"
SUITE="stable"

CACHE_DIR=".repo_cache"

# 切换到脚本所在目录
cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo "  Sileo Repo 生成器 v2.5 (增量缓存版)"
echo "=========================================="

mkdir -p debs
mkdir -p "$CACHE_DIR"

# 清理已删除 deb 对应的缓存
for cache_file in "$CACHE_DIR"/*; do
    [ -f "$cache_file" ] || continue
    deb_name=$(basename "$cache_file")
    if [ ! -f "debs/$deb_name" ]; then
        rm -f "$cache_file"
        echo "    - 清理缓存: $deb_name"
    fi
done

> Packages
total=0
updated=0
cached=0

echo "[*] 处理软件包..."

for deb in debs/*.deb; do
    [ -f "$deb" ] || continue
    filename=$(basename "$deb")
    total=$((total + 1))

    cache_file="$CACHE_DIR/$filename"
    size=$(wc -c < "$deb" | tr -d ' ')

    # 判断缓存是否可用：size 相同 且 缓存文件比 deb 新
    need_update=1
    if [ -f "$cache_file" ]; then
        cached_size=$(head -n 1 "$cache_file" | sed 's/^SIZE://')
        if [ "$cached_size" = "$size" ] && [ "$cache_file" -nt "$deb" ]; then
            need_update=0
        fi
    fi

    if [ "$need_update" -eq 0 ]; then
        # 复用缓存（去掉首行 SIZE:xxx）
        tail -n +2 "$cache_file" >> Packages
        cached=$((cached + 1))
        echo "    ✓ 复用: $filename"
    else
        # 重新解析 + 计算哈希
        echo "    → 处理: $filename"
        control=$(dpkg-deb -f "$deb")
        md5=$(md5sum "$deb" | awk '{print $1}')
        sha1=$(sha1sum "$deb" | awk '{print $1}')
        sha256=$(sha256sum "$deb" | awk '{print $1}')
        sha512=$(sha512sum "$deb" 2>/dev/null | awk '{print $1}')

        # 写入缓存文件（首行存 size 用于校验）
        {
            printf "SIZE:%s\n" "$size"
            printf "%s\n" "$control"
            printf "Filename: ./debs/%s\n" "$filename"
            printf "Size: %s\n" "$size"
            printf "MD5sum: %s\n" "$md5"
            printf "SHA1: %s\n" "$sha1"
            printf "SHA256: %s\n" "$sha256"
            [ -n "$sha512" ] && printf "SHA512: %s\n" "$sha512"
            printf "\n"
        } > "$cache_file"

        # 追加到 Packages（去掉首行 SIZE）
        tail -n +2 "$cache_file" >> Packages
        updated=$((updated + 1))
    fi
done

if [ "$total" -eq 0 ]; then
    echo "[!] 未找到任何 deb 文件"
    exit 0
fi

echo "[*] 统计: 总计 $total | 新增/更新 $updated | 复用 $cached"

echo "[*] 压缩中..."
gzip -9fc Packages > Packages.gz
xz -9fc Packages > Packages.xz

echo "[*] 生成 Release..."
DATE=$(date -R)

S_PKG=$(wc -c < Packages | tr -d ' ')
S_GZ=$(wc -c < Packages.gz | tr -d ' ')
S_XZ=$(wc -c < Packages.xz | tr -d ' ')

M_PKG=$(md5sum Packages | awk '{print $1}')
M_GZ=$(md5sum Packages.gz | awk '{print $1}')
M_XZ=$(md5sum Packages.xz | awk '{print $1}')

S1_PKG=$(sha1sum Packages | awk '{print $1}')
S1_GZ=$(sha1sum Packages.gz | awk '{print $1}')
S1_XZ=$(sha1sum Packages.xz | awk '{print $1}')

S2_PKG=$(sha256sum Packages | awk '{print $1}')
S2_GZ=$(sha256sum Packages.gz | awk '{print $1}')
S2_XZ=$(sha256sum Packages.xz | awk '{print $1}')

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
 $M_XZ $S_XZ Packages.xz
SHA1:
 $S1_PKG $S_PKG Packages
 $S1_GZ $S_GZ Packages.gz
 $S1_XZ $S_XZ Packages.xz
SHA256:
 $S2_PKG $S_PKG Packages
 $S2_GZ $S_GZ Packages.gz
 $S2_XZ $S_XZ Packages.xz
EOF

echo "=========================================="
echo "  ✅ 生成完成！"
echo "  总计: $total 个 | 更新: $updated 个 | 复用: $cached 个"
echo "=========================================="
ls -lh Packages Packages.gz Packages.xz Release