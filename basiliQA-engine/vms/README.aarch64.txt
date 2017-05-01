For working EFI/vga/ipxe support on aarch64 in qemu/kvm and in qemu aarch64 emulation on x86_64, please do following:

* Add repo with aarch64 EFI firmware: # zypper ar http://download.opensuse.org/ports/aarch64/factory/repo/oss/ aarch64-oss
* Install packages: # zypper ref && zypper in qemu-uefi-aarch64 qemu-ipxe qemu-vgabios

NOTE: If you want create your own aarch64 emulated machine on x86_64 directly via virt-manager, you have to add
      the following into /etc/libvirt/qemu.conf:

      nvram = [
         "/usr/share/qemu/ovmf-x86_64-ms-code.bin:/usr/share/qemu/ovmf-x86_64-ms-vars.bin",
         "/usr/share/qemu/aavmf-aarch64-code.bin:/usr/share/qemu/aavmf-aarch64-vars.bin"
      ]

      and then to restart libvirtd service.

Provided repository is compatible with openSUSE and SLE12* as well. See bsc#1029061 and bsc#1029062 for details.
