echo "I will need your input for the following:"
echo "  - disk selection"
echo "  - encrypted LUKS volume passphrase"
echo "Please stick arround until you have provided user input for those items."
echo ""

# disk selection
lsblk --nodeps
echo ""
read -p "Target Disk: " disk
echo
if [ ! -e /dev/"$disk" ]; then
    echo "Not a disk."
    exit 1
fi

# encrypted LUKS volume passphrase
read -p "LUKS Passphrase: " -s pass
echo
if [ -z "$pass" ]; then
    echo "Passphrase empty."
    exit 1
fi
read -p "LUKS Passphrase (confirmation): " -s pass_confirm
echo
if [ "$pass" != "$pass_confirm" ]; then
    echo "Passphrase mismatch."
    exit 1
fi

# mirror selection
sudo pacman-mirrors -m rank --geoip # --country United_States
sudo pacman -Sy
sudo pacman --noconfirm -S base-devel git libutil-linux emacs mtr htop

# disk format
sudo parted --script /dev/"$disk" mklabel gpt
sudo parted --script /dev/"$disk" unit MiB mkpart primary 2 514 mkpart primary 516 1540 mkpart primary 1542 100% set 1 boot on set 1 esp on
sudo mkfs.vfat /dev/"$disk"p1
yes | sudo mkfs.ext3 -m 0 /dev/"$disk"p2 -F # XKCD because this gets noisy doing tests on the SAME disk

# luks setup
echo -n "$pass" | sudo cryptsetup luksFormat /dev/"$disk"p3 -v --cipher aes-xts-plain64 --hash sha512 --iter-time 5000 --use-random --key-file=-
echo -n "$pass" | sudo cryptsetup open --type luks /dev/"$disk"p3 e1 --key-file=-
yes | sudo pvcreate /dev/mapper/e1 -ff # XKCD this only happens because we're repeating on the SAME disk
sudo vgcreate vg0 /dev/mapper/e1
sudo lvcreate --size 32GiB -n swap vg0
sudo lvcreate --extents 100%FREE -n root vg0
sudo mkfs.ext4 /dev/vg0/root
sudo mkswap /dev/vg0/swap

# mount
sudo mount -t ext4 /dev/vg0/root  /mnt/
sudo mkdir /mnt/boot/
sudo mount -t ext3 /dev/nvme0n1p2 /mnt/boot/
sudo mkdir /mnt/boot/EFI/
sudo mount -t vfat /dev/nvme0n1p1 /mnt/boot/EFI/
sudo swapon /dev/vg0/swap

# get and install latest version of manjaro-architect
git clone https://github.com/Chrysostomus/manjaro-architect
cd manjaro-architect
make
makepkg -sric --noconfirm

# run manjaro-architect
sudo manjaro-architect

# unmount
# sudo umount /mnt/boot/EFI/
# sudo umount /mnt/boot/
# sudo umount /mnt/
# sudo swapoff /dev/vg0/swap

# things to do to clean up testing
# sudo lvchange --activate n /dev/vg0/swap
# sudo lvchange --activate n /dev/vg0/root
# sudo vgchange --activate n vg0
# sudo cryptsetup close e1
