#!/bin/sh
# ============================================================
# Sileo Repo 生成脚本 - Filza / sh 兼容版 v2.4
# 去掉了 bash 专有语法，支持在 Filza 中直接运行
# ============================================================

# 配置区域
REPO_NAME="鸭鸭"
REPO_LABEL="Sileo Repo"
REPO_DESC="duck's Sileo jailbreak repository"
REPO_CODENAME="ios"
REPO_ARCH="iphoneos-arm64 iphoneos-arm64e"
REPO_COMPONENTS="main"
SUITE="stable"

# 切换到脚本所在目录
cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo "  Sileo Repo 生成器 v2.4 (sh 兼容版)"
echo "=========================================="

mkdir -p debs

# 清空文件准备写入
> Packages
total=0

echo "[*] 处理软件包..."

for deb in debs/*.deb; do
    # 跳过不存在的文件（防止没有 deb 时循环出错）
    [ -f "$deb" ] || continue
    
    filename=$(basename "$deb")
    total=$((total + 1))
    echo "    → 处理: $filename"

    # 获取包控制信息
    control=$(dpkg-deb -f "$deb")
    # 获取文件大小和哈希
    size=$(wc -c < "$deb" | tr -d ' ')
    md5=$(md5sum "$deb" | awk '{print $1}')
    sha1=$(sha1sum "$deb" | awk '{print $1}')
    sha256=$(sha256sum "$deb" | awk '{print $1}')
    sha512=$(sha512sum "$deb" 2>/dev/null | awk '{print $1}')

    # 写入 Packages（使用 printf 保证格式正确，无多余空格）
    printf "%s\n" "$control" >> Packages
    printf "Filename: ./debs/%s\n" "$filename" >> Packages
    printf "Size: %s\n" "$size" >> Packages
    printf "MD5sum: %s\n" "$md5" >> Packages
    printf "SHA1: %s\n" "$sha1" >> Packages
    printf "SHA256: %s\n" "$sha256" >> Packages
    [ -n "$sha512" ] && printf "SHA512: %s\n" "$sha512" >> Packages
    printf "\n" >> Packages
done

if [ "$total" -eq 0 ]; then
    echo "[!] 未找到任何 deb 文件"
    exit 0
fi

echo "[*] 压缩中..."
gzip -9fc Packages > Packages.gz
xz -9fc Packages > Packages.xz

echo "[*] 生成 Release..."
DATE=$(date -R)

# 使用 wc -c 替代 stat，兼容 iOS 环境
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
echo "  总计: $total 个软件包"
echo "=========================================="
ls -lh Packages Packages.gz Packages.xz Release
