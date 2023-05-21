#!/bin/sh

echo "Install custom arch based system"

DISK = /dev/sda

# Set locale, keymaps and console font on live iso
localectl set-keymap --no-convert fr-latin1
echo FONT=eurlatgr >> /etc/vconsole.conf
setfont eurlatgr

# Set date and time on live iso
timedatectl set-ntp true

# Set better mirrors !
# TODO use reflector !!!

# Update repository cache and install git on live iso
pacman -Sy --needed --noconfirm git

# Delete all filesystem meta data
wipefs -afq $DISK
# Delete all disk data
sgdisk --zap-all $DISK

# Create new GTP partition table
sgdisk $DISK -o

# Create efi partition
sgdisk $DISK -n 1::+512MiB -t 1:ef00

# Create root partition
sgdisk $DISK -n 2::-2GiB

# Create swap partition
sgdisk $DISK -n 3 -t 3:8200

# Format partitions
mkfs.vfat -F32 -n EFI "${$DISK}1"
mkfs.btrfs -L ROOT -f "${$DISK}2"
mkswap -L SWAP "${$DISK}3"

# Activate swap
swapon "${$DISK}3"

# Create and mount subvolumes
mount "${$DISK}2" /mnt
btrfs sub create /mnt/@
btrfs sub create /mnt/@home
btrfs sub create /mnt/@pkg
btrfs sub create /mnt/@snapshots
umount /mnt

mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@ "${$DISK}2" /mnt
mkdir -p /mnt/{boot,home,var/cache/pacman/pkg,.snapshots,btrfs}
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@home "${$DISK}2" /mnt/home
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@pkg "${$DISK}2" /mnt/var/cache/pacman/pkg
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@snapshots "${$DISK}2" /mnt/.snapshots
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvolid=5 "${$DISK}2" /mnt/btrfs
mount "${$DISK}1" /mnt/boot

# Install base system
pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware lunix-firmware-qlogic btrfs-progs networkmanager efibootmgr sudo zsh git neovim --needed --noconfirm
# man-db man-pages textinfo zip unzip
# keepassxc


# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Go to the fresh system
# arch-chroot /mnt

# Set keyboard layout and font
arch-chroot /mnt bash -c "echo KEYMAP=fr-latin1 > /etc/vconsole.conf"
arch-chroot /mnt bash -c "echo FONT=eurlatgr >> /etc/vconsole.conf"

# Set timezone
arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime"
arch-chroot /mnt bash -c "hwclock --systohc"

# Set locale
arch-chroot /mnt bash -c "sed -i '/en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen"
arch-chroot /mnt bash -c "locale-gen"
arch-chroot /mnt bash -c "localectl set-locale LANG=en_US.UTF-8"
arch-chroot /mnt bash -c "echo LANG=us_EN.UTF-8 > /etc/locale.conf"

# Set hostname
hostname=archvm
arch-chroot /mnt bash -c "echo ${hostname} > /etc/hostname"
# Set hosts
arch-chroot /mnt bash -c "echo '127.0.0.1   localhost' > /etc/hosts"
arch-chroot /mnt bash -c "echo '127.0.0.1 ${hostname}  ${hostname}.localdomain' >> /etc/hosts"
arch-chroot /mnt bash -c "echo '::1   localhost' >> /etc/hosts"
arch-chroot /mnt bash -c "echo '::1 ${hostname}  ${hostname}.localdomain' >> /etc/hosts"

# Set root password
arch-chroot /mnt bash -c "passwd"

# Recreate initramfs
arch-chroot /mnt bash -c "mkinitcpio -p linux-zen"

# Setup boot manager
arch-chroot /mnt bash -c "bootctl --path=/boot install"

# Add default users
groupname=admin
arch-chroot /mnt bash -c "groupadd -g 1001 ${groupname}"
username=lowkos
# TODO make function
arch-chroot /mnt bash -c "useradd -m ${username} -g ${groupname} -G users,wheel,audio,video,optical,storage -s /bin/zsh"
arch-chroot /mnt bash -c "passwd ${username}"
arch-chroot /mnt bash -c "echo '${username} ALL=(ALL) ALL' > /etc/sudoers.d/${username}"
username=lorillis
arch-chroot /mnt bash -c "useradd -m ${username} -g ${groupname} -G users,wheel,audio,video,optical,storage -s /bin/zsh"
arch-chroot /mnt bash -c "passwd ${username}"
arch-chroot /mnt bash -c "echo '${username} ALL=(ALL) ALL' > /etc/sudoers.d/${username}"

# Login as lowkos
arch-chroot /mnt bash -c "su lowkos"

# Install paru
git clone https://aur.archlinux.org/paru.git
cd paru && makepkg -si
cd .. && sudo rm -r paru