#!/bin/bash

set -ouex pipefail

LTS=6.12

KERNEL=$(skopeo inspect --retry-times 3 docker://ghcr.io/ublue-os/akmods:longterm-${LTS}-"$(rpm -E %fedora)" | jq -r '.Labels["ostree.linux"]')

skopeo copy --retry-times 3 docker://ghcr.io/ublue-os/akmods:longterm-${LTS}-"$(rpm -E %fedora)"-${KERNEL} dir:/tmp/akmods
AKMODS_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods/manifest.json | cut -d : -f 2)
tar -xvzf /tmp/akmods/"$AKMODS_TARGZ" -C /tmp/
mv /tmp/rpms/* /tmp/akmods/

dnf5 -y install /tmp/kernel-rpms/kernel-longterm{,-core,-modules,-modules-core,-modules-extra}-"${KERNEL}".rpm

dnf5 -y remove kernel{,-core,-modules,-modules-core,-modules-extra,-tools,-tools-libs,-headers}


# Prevent kernel stuff from upgrading again
dnf5 versionlock add kernel-longterm{,-core,-modules,-modules-core,-modules-extra,-tools,-tools-lib,-headers,-devel,-devel-matched}


# Turns out we need an initramfs if we wan't to boot
KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-longterm(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-longterm(|'"$KERNEL_SUFFIX"'-)//')"
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible -v --add ostree -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
