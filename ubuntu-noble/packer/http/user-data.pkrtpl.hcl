#cloud-config
autoinstall:
  version: 1
  locale: en_US
  keyboard:
    layout: us
  ssh:
    install-server: true
    allow-pw: true
    emit_keys_to_console: false
    authorized-keys:
      - ${default_user_ssh_key}
      - ${ansible_user_ssh_key}
  packages:
    - qemu-guest-agent
    - cloud-init
    - sudo
  storage:
    config:
      # Custom LVM partition schema
      - type: disk
        id: disk0
        ptable: gpt
        path: /dev/sda
        wipe: superblock-recursive
        preserve: false
        grub_device: true

      # EFI System Partition (512MB)
      - type: partition
        id: partition-efi
        device: disk0
        size: 512M
        flag: boot
        grub_device: true

      # Boot partition (512MB)
      - type: partition
        id: partition-boot
        device: disk0
        size: 512M

      # LVM Physical Volume (rest of disk)
      - type: partition
        id: partition-lvm
        device: disk0
        size: -1

      # Create Volume Group
      - type: lvm_volgroup
        id: vg0
        name: vg0
        devices:
          - partition-lvm

      # Logical Volumes
      - type: lvm_partition
        id: lv-root
        volgroup: vg0
        name: root
        size: 10G

      - type: lvm_partition
        id: lv-home
        volgroup: vg0
        name: home
        size: 5G

      - type: lvm_partition
        id: lv-var
        volgroup: vg0
        name: var
        size: 5G

      - type: lvm_partition
        id: lv-var-log
        volgroup: vg0
        name: var_log
        size: 3G

      - type: lvm_partition
        id: lv-opt
        volgroup: vg0
        name: opt
        size: 2G

      - type: lvm_partition
        id: lv-var-tmp
        volgroup: vg0
        name: var_tmp
        size: 5G

      - type: lvm_partition
        id: lv-swap
        volgroup: vg0
        name: swap
        size: 2G

      # Format EFI partition
      - type: format
        id: format-efi
        volume: partition-efi
        fstype: fat32
        label: EFI

      # Format boot partition
      - type: format
        id: format-boot
        volume: partition-boot
        fstype: ext4
        label: BOOT

      # Format LVM volumes
      - type: format
        id: format-root
        volume: lv-root
        fstype: ext4
        label: ROOT

      - type: format
        id: format-home
        volume: lv-home
        fstype: ext4
        label: HOME

      - type: format
        id: format-var
        volume: lv-var
        fstype: ext4
        label: VAR

      - type: format
        id: format-var-log
        volume: lv-var-log
        fstype: ext4
        label: VARLOG

      - type: format
        id: format-opt
        volume: lv-opt
        fstype: ext4
        label: OPT

      - type: format
        id: format-var-tmp
        volume: lv-var-tmp
        fstype: ext4
        label: VARTMP

      - type: format
        id: format-swap
        volume: lv-swap
        fstype: swap

      # Mount filesystems
      - type: mount
        id: mount-efi
        device: format-efi
        path: /boot/efi

      - type: mount
        id: mount-boot
        device: format-boot
        path: /boot

      - type: mount
        id: mount-root
        device: format-root
        path: /

      - type: mount
        id: mount-home
        device: format-home
        path: /home

      - type: mount
        id: mount-var
        device: format-var
        path: /var

      - type: mount
        id: mount-var-log
        device: format-var-log
        path: /var/log

      - type: mount
        id: mount-opt
        device: format-opt
        path: /opt

      - type: mount
        id: mount-var-tmp
        device: format-var-tmp
        path: /var/tmp

      # Enable swap
      - type: mount
        id: mount-swap
        device: format-swap
        path: none
        fstype: swap
  identity:
    hostname: ubuntu-template
    username: ${default_user}
    password: "${default_user_password}"
  user-data:
    disable_root: false
    timezone: Europe/Athens
    package_upgrade: true
    users:
      - name: ${default_user}
        groups: sudo
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
        passwd: "${default_user_password}"
        lock_passwd: false
        ssh_authorized_keys:
          - ${default_user_ssh_key}
      - name: ${ansible_user}
        groups: sudo
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
        passwd: "${ansible_user_password}"
        lock_passwd: false
        ssh_authorized_keys:
          - ${ansible_user_ssh_key}
  late-commands:
    # Ensure sudo group has NOPASSWD
    - curtin in-target --target=/target -- sed -i 's/%sudo\s\+ALL=(ALL:ALL)\s\+ALL/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/' /etc/sudoers
    # Create sudoers.d files for both users
    - echo '${default_user} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${default_user}
    - echo '${ansible_user} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${ansible_user}
    - curtin in-target --target=/target -- chmod 440 /etc/sudoers.d/${default_user}
    - curtin in-target --target=/target -- chmod 440 /etc/sudoers.d/${ansible_user}
    # Configure /tmp as tmpfs (exec allowed for Packer provisioning)
    - echo 'tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777,size=2G 0 0' >> /target/etc/fstab
    # # Ensure home directories exist
    # - curtin in-target --target=/target -- mkdir -p /home/${default_user}
    # - curtin in-target --target=/target -- mkdir -p /home/${ansible_user}
    # - curtin in-target --target=/target -- chown ${default_user}:${default_user} /home/${default_user}
    # - curtin in-target --target=/target -- chown ${ansible_user}:${ansible_user} /home/${ansible_user}
    # # Ensure SSH directories
    # - curtin in-target --target=/target -- mkdir -p /home/${default_user}/.ssh
    # - curtin in-target --target=/target -- mkdir -p /home/${ansible_user}/.ssh
    # - curtin in-target --target=/target -- chmod 700 /home/${default_user}/.ssh
    # - curtin in-target --target=/target -- chmod 700 /home/${ansible_user}/.ssh
    # - curtin in-target --target=/target -- chown -R ${default_user}:${default_user} /home/${default_user}/.ssh
    # - curtin in-target --target=/target -- chown -R ${ansible_user}:${ansible_user} /home/${ansible_user}/.ssh
