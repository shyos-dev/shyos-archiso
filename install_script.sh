#!/bin/sh

str_prompt() {

    while true; do
        printf "$1"
        read str

        if [ -z "$str" ]; then
            echo -e "Input cannot be empty\n"
            continue

        fi

        break

    done

    STR_INPUT="$str"

}

num_prompt() {

    while true; do
        printf "$1"
        read num

        if [ -z "$num" ]; then
            echo -e "Input cannot be empty\n"
            continue

        elif ! [ -z $2 ] && ! [ -z $3 ]; then
            if [ $num -eq $num 2> /dev/null ] && [ $num -ge $2 ] && [ $num -le $3 ]; then
                break

            else
                echo -e "Invalid integer input\n"
                continue

            fi

        fi

    done

    NUM_INPUT="$num"

}

echo "==============="
echo "ShyOS Installer"
echo "==============="

BASE_PACKAGES="base base-devel linux linux-firmware sudo nano wget networkmanager fuse polkit-gnome lxappearance-gtk3 xdg-desktop-portal arc-gtk-theme mesa firewalld"

# Partitioning (i am not gonna make a CLI Partitioning tool)
cat << EOF
Welcome to ShyOS Installer

!! IMPORTANT !!
BEFORE TRYING TO INSTALL THE OS, MAKE SURE TO PARTITION YOUR DRIVE MANUALY. WHILE DOING SO, DOUBLE CHECK YOUR PARTITION LAYOUT.

Partitions required to boot the system are:
1. EFI partition (at least 256MB) mounted on /mnt/boot
2. ROOT partition mounted on /mnt
3. (OPTIONAL) HOME partition mounted on /mnt/home

After you're done. Press y to continue
EOF

printf "Continue (y/n): "
read continue

case $continue in
    y|Y) true;;
    n|N) echo "\nExting installer..." && exit;;

esac

echo -e "\nPlease choose your timezone from the available list"
timedatectl list-timezones > /tmp/timezone-list.txt
timedatectl list-timezones

while true; do
    printf "Timezone: "
    read timezone

    if [ -z "$(cat /tmp/timezone-list.txt | grep -F $timezone)" ]; then
        echo -e "\nTimezone does not exist, please enter your timezone correctly"
        continue

    fi

    break

done

echo -e "\nPlease choose which CPU you're using:"
echo -e "1. AMD\n2. Intel"
num_prompt "CPU: " 1 2
cpu=$NUM_INPUT

if [ $cpu -eq 1 ]; then
    extra_packages="${extra_packages} amd-ucode"
    cpu="amd"

elif [ $cpu -eq 2 ]; then
    extra_packages="${extra_packages} intel-ucode"
    cpu="intel"

fi

echo -e "\nPlease enter your username for your installation"
str_prompt "Username: "
username="$STR_INPUT"

echo -e "\nPlease enter your hostname for your installation"
str_prompt "Hostname: "
hostname="$STR_INPUT"

echo -e "\nPlease choose which edition to use"
echo -e "1. Light"
num_prompt "Edition: " 1 1
edition=$NUM_INPUT

if [ $edition -eq 1 ]; then
    extra_packages="${extra_packages} bspwm sxhkd feh picom thunar gvfs gvfs-mtp xorg-server xorg-xrandr xorg-xprop xorg-xinput xorg-xinit xorg-xsetroot polybar"

fi

# installation
pacstrap -K /mnt $BASE_PACKAGES $extra_packages

# boring stuff
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i 's/#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo $hostname > /mnt/etc/hostname

echo -e "\nWhen using LVM, RAID, or encryption in your installation. It is recommended to regenerate initramfs.\nDo you want to regenerate it?\n"
printf "Regenerate (y/n): "
read regen_initrd

case "$regen_initrd" in
    y|Y) arch-chroot /mnt mkinitcpio -P;;
    n|N) true;;

esac

arch-chroot /mnt useradd -m -G wheel,video -s /bin/bash $username
echo -e "\nPlease set your user password"
arch-chroot /mnt passwd $username

echo -e "\nPlease set your root password"
arch-chroot /mnt passwd

echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/1-very-impotant-without-this-you-cant-use-sudo

arch-chroot /mnt bootctl install
root_uuid=$(grep '/ ' /mnt/etc/fstab | grep -o 'UUID=[^[:space:]]*' | sed 's/UUID=//')

cat << EOF > /mnt/boot/loader/loader.conf
default shyos.conf
timout 5
editor no
EOF

cat << EOF > /mnt/boot/loader/entries/shyos.conf
title ShyOS
linux /vmlinuz-linux
initrd /$cpu-ucode.img
initrd /initramfs-linux.img
options root=UUID=$root_uuid rw nowatchdog
EOF

cat << EOF > /mnt/boot/loader/entries/shyos-fallback.conf
title ShyOS (fallback)
linux /vmlinuz-linux
initrd /$cpu-ucode.img
initrd /initramfs-linux-fallback.img
options root=UUID=$root_uuid rw nowatchdog
EOF

systemctl enable --root=/mnt NetworkManager.service
systemctl enable --root=/mnt firewalld.service
