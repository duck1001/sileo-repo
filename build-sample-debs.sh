#!/bin/bash
# ============================================================
# 示例 DEB 包构建脚本
# 运行: bash build-sample-debs.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  构建示例 DEB 软件包"
echo "=========================================="

# ---- Roothide 插件示例 ----
echo "[*] 构建 Roothide 插件示例..."
mkdir -p /tmp/debbuild/roothide-sample/DEBIAN
cat > /tmp/debbuild/roothide-sample/DEBIAN/control << 'CONTROL'
Package: com.subos000.roothide-sample
Name: Roothide Sample Tweak
Version: 1.0.0
Architecture: iphoneos-arm
Description: 一个示例 Roothide 插件
Maintainer: Subos000
Author: Subos000
Section: Roothide 插件
Depends: mobilesubstrate (>= 0.9.5000), firmware (>= 13.0)
Tag: roothide
CONTROL

mkdir -p /tmp/debbuild/roothide-sample/Library/MobileSubstrate/DynamicLibraries
echo "{}" > /tmp/debbuild/roothide-sample/Library/MobileSubstrate/DynamicLibraries/roothide-sample.plist
dpkg-deb -Zgzip -b /tmp/debbuild/roothide-sample debs/roothide/
echo "    - 已生成: debs/roothide/com.subos000.roothide-sample_1.0.0_iphoneos-arm.deb"

# ---- Tweaks 示例 ----
echo "[*] 构建 Tweaks 示例..."
mkdir -p /tmp/debbuild/tweaks-sample/DEBIAN
cat > /tmp/debbuild/tweaks-sample/DEBIAN/control << 'CONTROL'
Package: com.subos000.tweaks-sample
Name: Sample Tweak
Version: 1.0.0
Architecture: iphoneos-arm
Description: 一个示例系统增强插件
Maintainer: Subos000
Author: Subos000
Section: Tweaks
Depends: mobilesubstrate (>= 0.9.5000)
CONTROL

mkdir -p /tmp/debbuild/tweaks-sample/Library/MobileSubstrate/DynamicLibraries
echo "{}" > /tmp/debbuild/tweaks-sample/Library/MobileSubstrate/DynamicLibraries/sample.plist
dpkg-deb -Zgzip -b /tmp/debbuild/tweaks-sample debs/tweaks/
echo "    - 已生成: debs/tweaks/com.subos000.tweaks-sample_1.0.0_iphoneos-arm.deb"

# ---- Widgets 示例 ----
echo "[*] 构建 Widgets 示例..."
mkdir -p /tmp/debbuild/widgets-sample/DEBIAN
cat > /tmp/debbuild/widgets-sample/DEBIAN/control << 'CONTROL'
Package: com.subos000.widgets-sample
Name: Sample Widget
Version: 1.0.0
Architecture: iphoneos-arm
Description: 一个示例桌面小部件
Maintainer: Subos000
Author: Subos000
Section: Widgets
Depends: firmware (>= 14.0)
CONTROL

mkdir -p /tmp/debbuild/widgets-sample/Library/Widgets
echo "Sample Widget" > /tmp/debbuild/widgets-sample/Library/Widgets/SampleWidget.html
dpkg-deb -Zgzip -b /tmp/debbuild/widgets-sample debs/widgets/
echo "    - 已生成: debs/widgets/com.subos000.widgets-sample_1.0.0_iphoneos-arm.deb"

# ---- Utilities 示例 ----
echo "[*] 构建 Utilities 示例..."
mkdir -p /tmp/debbuild/utilities-sample/DEBIAN
cat > /tmp/debbuild/utilities-sample/DEBIAN/control << 'CONTROL'
Package: com.subos000.utilities-sample
Name: Sample Utility
Version: 1.0.0
Architecture: iphoneos-arm
Description: 一个示例实用工具
Maintainer: Subos000
Author: Subos000
Section: Utilities
Depends: firmware (>= 12.0)
CONTROL

mkdir -p /tmp/debbuild/utilities-sample/usr/bin
echo "#!/bin/bash" > /tmp/debbuild/utilities-sample/usr/bin/sample-util
echo "echo 'Hello from Subos000 Repo!'" >> /tmp/debbuild/utilities-sample/usr/bin/sample-util
chmod 755 /tmp/debbuild/utilities-sample/usr/bin/sample-util
dpkg-deb -Zgzip -b /tmp/debbuild/utilities-sample debs/utilities/
echo "    - 已生成: debs/utilities/com.subos000.utilities-sample_1.0.0_iphoneos-arm.deb"

# ---- 清理 ----
rm -rf /tmp/debbuild

echo ""
echo "=========================================="
echo "  完成！示例 DEB 包已生成到 debs/ 目录"
echo "=========================================="
echo ""
for dir in debs/*/; do
    count=$(ls "$dir"*.deb 2>/dev/null | wc -l)
    echo "  - ${dir%/}: $count 个软件包"
done
echo ""
echo "运行 'bash gen.sh' 生成 Packages 和 Release 文件"
