#!/bin/sh
# ============================================================
# Sileo Repo - Packages & Release 增量生成脚本 v2.2-sh
# 基于原 2.2 版，适配 sh / Filza 运行环境
# ============================================================

REPO_NAME="鸭鸭"
REPO_LABEL="Sileo Repo"
REPO_DESC="duck's Sileo jailbreak repository"
REPO_CODENAME="ios"
REPO_ARCH="iphoneos-arm64 iphoneos-arm64e"
REPO_COMPONENTS="main"
SUITE="stable"

CACHE_FILE=".repo_cache"
TMP_CACHE=".repo_cache.tmp"
FORCE_UPDATE=0

# 解析参数
[ "$1" = "-f" ] || [ "$1" = "--force" ] && FORCE_UPDATE=1

cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo "  Sileo Repo 增量生成器 v2.2-sh"
echo "=========================================="

mkdir -p debs
> Packages
> "$TMP_CACHE"

# ---- 缓存查询：从 .repo_cache 里取出 key 对应的 entry ----
cache_get() {
    awk -v k="$1" '
        $0 == "===CACHE_START===" k { f=1; next }
        f && $0 == "===CACHE_END==="  { exit }
        f { print }
    ' "$CACHE_FILE" 2>/dev/null
}

total=0; updated=0; skipped=0

echo "[*] 处理软件包..."
for deb in debs/*.deb; do
    [ -f "$deb" ] || continue
    filename=$(basename "$deb")
    total=$((total + 1))

    mtime=$(date -r "$deb" +%s)
    size=$(wc -c < "$deb" | tr -d ' ')
    key="$filename:$mtime:$size"

    cached=$(cache_get "$key")

    if [ "$FORCE_UPDATE" -eq 0 ] && [ -n "$cached" ]; then
        printf "%s\n" "$cached" >> Packages
        skipped=$((skipped + 1))
        echo "    ✓ 复用: $filename"
    else
        echo "    → 处理: $filename"
        control=$(dpkg-deb -f "$deb")
        md5=$(md5sum "$deb" | awk '{print $1}')
        sha1=$(sha1sum "$deb" | awk '{print $1}')
        sha256=$(sha256sum "$deb" | awk '{print $1}')

        entry=$(printf "%s\nFilename: ./debs/%s\nSize: %s\nMD5sum: %s\nSHA1: %s\nSHA256: %s" \
            "$control" "$filename" "$size" "$md5" "$sha1" "$sha256")

        printf "%s\n\n" "$entry" >> Packages
        updated=$((updated + 1))
    fi

    # 写入新缓存（本次存在的 deb 才写，被删的自动淘汰）
    printf "===CACHE_START===%s\n%s\n===CACHE_END===\n" "$key" "$entry" >> "$TMP_CACHE"
done

if [ "$total" -eq 0 ]; then
    echo "[!] 未找到任何 deb 文件"
    rm -f "$TMP_CACHE"
    exit 0
fi

mv "$TMP_CACHE" "$CACHE_FILE"
echo "[*] 统计: 总计 $total | 更新 $updated | 复用 $skipped"

echo "[*] 压缩..."
gzip -9fc Packages > Packages.gz
xz -9fc Packages > Packages.xz

echo "[*] 生成 Release..."
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
Date: $(date -R)
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
echo "  总计: $total | 更新: $updated | 复用: $skipped"
echo "=========================================="
ls -lh Packages Packages.gz Packages.xz Release