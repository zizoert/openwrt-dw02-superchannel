#!/usr/bin/env bash
set -euo pipefail
echo "Starting OpenWrt build script..."
WORKDIR="$(pwd)"
if [ ! -d openwrt ]; then
  git clone https://github.com/openwrt/openwrt.git
fi
cd openwrt
git fetch --all --tags
git checkout v23.05.3

./scripts/feeds update -a
./scripts/feeds install -a

# Apply regdb patch (unlock bands)
mkdir -p package/kernel/mac80211/patches/regdb
cat > package/kernel/mac80211/patches/regdb/9999-unlock-bands.patch <<'PATCH'
--- a/package/kernel/mac80211/files/regdb.txt
+++ b/package/kernel/mac80211/files/regdb.txt
@@
 country 00: DFS-UNSET
-	(2402 - 2472 @ 40), (N/A, 20), (N/A)
+	(2312 - 2472 @ 40), (30), (N/A)
+	# Full unlocked 5GHz SuperChannel range (80MHz max)
+	(5100 - 5900 @ 80), (30), (N/A)
PATCH

# Prepare .config for the device
cat > .config <<'CONF'
CONFIG_TARGET_ath79=y
CONFIG_TARGET_ath79_nand=y
CONFIG_TARGET_ath79_nand_DEVICE_dongwon_dw02-412h-128m=y
CONFIG_PACKAGE_kmod-ath10k=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_wpad-mesh-wolfssl=y
CONF

make defconfig

# Copy wireless config from repository files (if exists)
mkdir -p files/etc/config
if [ -f ../files/etc/config/wireless ]; then
  cp ../files/etc/config/wireless files/etc/config/wireless
else
  echo "Warning: ../files/etc/config/wireless not found; continuing without custom wireless file."
fi

# Add modprobe option to set regdom on boot
mkdir -p files/etc/modprobe.d
echo "options cfg80211 ieee80211_regdom=00" > files/etc/modprobe.d/99-regdom.conf

# Build
make -j$(nproc) || make -j1 V=s

echo "Build finished. Artifacts are in: $(pwd)/bin/targets"
