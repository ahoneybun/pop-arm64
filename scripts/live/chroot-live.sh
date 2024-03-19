#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

info "Fixing DNS"
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt-get --yes update 2>&1| capture_and_log "apt update"
if [ ${#LIVE_PKGS[@]} -ne 0 ]; then
    eatmydata apt-get --yes install ${LIVE_PKGS[@]} 2>&1| capture_and_log "install live utilities"
fi

NUM_DEBS_TO_INSTALL=$(find /debs -name "*.deb" -type f | wc -l)
if [ ${NUM_DEBS_TO_INSTALL} -gt 0 ]; then
    info "Found ${NUM_DEBS_TO_INSTALL} extra debs to install"
    eatmydata apt-get --yes install /debs/*.deb 2>&1| capture_and_log "install custom debs"
fi
rm -rf /debs

info "Setting up pool"
mkdir -p /iso/pool/main
if [ ${#MAIN_POOL[@]} -ne 0 ]; then
    pushd "/iso/pool/main"
       apt-get --yes download ${MAIN_POOL[@]} 2>&1| capture_and_log "download main pool"
    popd
fi

info "Synchronizing changes to disk"
sync

info "Setting up casper scripts"
rm -f /usr/share/initramfs-tools/scripts/casper-bottom/01integrity_check

update-initramfs -c -k all 2>&1| capture_and_log "updating initramfs"

info "Copying new initrd to /iso/${CASPER_NAME}"
ACTUAL_INITRD="/boot/$(readlink /boot/initrd.img)"
rm -f "/iso/initrd.gz"
mkdir -p "/iso/${CASPER_NAME}"
cp -f "$ACTUAL_INITRD" "/iso/${CASPER_NAME}/initrd.gz"

info "Moving vmlinuz to /iso/${CASPER_NAME}"
mv -f "/iso/vmlinuz" "/iso/${CASPER_NAME}/vmlinuz.efi"

info "Creating live filesystem manifest"
dpkg-query -W --showformat='${Package}\t${Version}\n' > /manifest

# Clean up any left-behind crap, such as tempfiles and machine-id.
info "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id
