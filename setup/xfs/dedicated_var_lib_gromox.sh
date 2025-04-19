#!/bin/sh
set -e
if [ $# -eq 0 ]; then
  echo "scanning for new disks"
  partprobe --summary
  # get only real disks, no cdrom, swap, special-cases..
  REALDISKS=$(lsblk -npd -o NAME,SIZE,FSTYPE,LABEL -e "$(awk '/(zram|zvol)/ {printf "%s,",$1}' /proc/devices)"7,11)
  echo "Listing of all real disks:"
  echo "$REALDISKS"
  echo "Next time you run me supply either one or two(raid1) disks"
  echo
  exit 0
fi
if [ $# -eq 2 ]; then
  echo "Creating a software raid 1 with $1 and $2."
  echo "Accept?"
  read -r ACCEPT || exit 1
  mdadm --zero-superblock "$1" "$2"
  if ! [ -d /dev/md ]; then
    MDNAME=md0
    mdadm --create "/dev/$MDNAME" --level=mirror --raid-devices=2 "$1" "$2" --metadata 1.2
  else
    echo "Seems like there is already a MD present. Please provide a name"
    echo "You only need to write: md1"
    read -r MDNAME
    echo "Is this correct? /dev/$MDNAME"
    # shellcheck disable=SC2034
    read -r ACCEPT || exit 1
    # shellcheck disable=SC2086
    mdadm --create "/dev/$MDNAME" --level=mirror --raid-devices=2 --metadata 1.2 $1 $2
  fi
  DISK="/dev/$MDNAME" PART="p1"
else
  DISK="$1" PART="1"
fi
echo "Creating LVM on $DISK"
parted -s "$DISK" mklabel gpt
sleep 1
parted -s "$DISK" mkpart primary 0GB 100%
sleep 1
pvcreate "${DISK}${PART}" -v
sleep 1
vgcreate gromox "${DISK}${PART}" -v
echo "use only 80% so we can make use of lvm snapshots for backups"
lvcreate gromox -n maildir -l80%VG -v
sleep 1
mkfs.xfs -f /dev/gromox/maildir
sleep 2
#lsblk -f /dev/gromox/maildir --output UUID --noheadings
UUID="$(lsblk -f /dev/gromox/maildir --noheadings --output UUID)"
FSTAB="UUID=${UUID} /var/lib/gromox xfs defaults 0 0"
printf '%s\n' "$FSTAB" |tee -a /etc/fstab
echo "Moving original maildir away"
mv -v /var/lib/gromox /var/lib/gromox-bak
mkdir -v /var/lib/gromox
mount -v /var/lib/gromox
cp -va /var/lib/gromox-bak/* /var/lib/gromox/
chown -v gromox:gromox /var/lib/gromox
chmod -v 770 /var/lib/gromox
rm -Rfv /var/lib/gromox.bak
