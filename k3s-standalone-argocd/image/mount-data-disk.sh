#!/bin/bash
# Mount the secondary "data" disk at /mnt/data so k3s local-path PVCs persist across
# a re-provision. Durantic reimages only the SYSTEM disk; the data disk is left intact,
# so PVC data (e.g. MongoDB) on it survives.
#
# The data disk is formatted ONLY if it has no filesystem yet (first provision);
# afterwards it is just mounted, preserving the data. The root disk is never touched.
set -euo pipefail
LABEL="k3s-data"
MNT="/mnt/data"

# Identify the root disk so we never format it.
root_src="$(findmnt -no SOURCE / 2>/dev/null || true)"
root_pk="$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -n1 || true)"
root_disk="${root_pk:+/dev/$root_pk}"
[ -z "$root_disk" ] && root_disk="$root_src"

# Pick the first whole disk that is not the root disk = the data disk.
data_disk=""
while read -r name type; do
  [ "$type" = "disk" ] || continue
  [ "$name" = "$root_disk" ] && continue
  data_disk="$name"; break
done < <(lsblk -dpno NAME,TYPE)

if [ -z "$data_disk" ]; then
  echo "data-disk: none found (root=$root_disk) - using the system disk for storage"
  mkdir -p "$MNT/local-path"
  exit 0
fi
echo "data-disk: $data_disk (root=$root_disk)"

# Format only when there is no filesystem yet, so existing data is preserved.
if blkid "$data_disk" >/dev/null 2>&1; then
  echo "data-disk: existing filesystem - preserving data"
else
  echo "data-disk: empty - mkfs.ext4 (first provision)"
  mkfs.ext4 -F -L "$LABEL" "$data_disk"
fi

# Persist across plain reboots (fstab) and mount now.
mkdir -p "$MNT"
grep -q " $MNT " /etc/fstab 2>/dev/null || echo "LABEL=$LABEL $MNT ext4 defaults,nofail 0 2" >> /etc/fstab
mountpoint -q "$MNT" || mount "$MNT" 2>/dev/null || mount "$data_disk" "$MNT"
mkdir -p "$MNT/local-path"
echo "data-disk: mounted $data_disk at $MNT"
