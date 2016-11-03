There is no currently way to prepare Windows images
for basiliQA in a completly automatic way. This README
describes the manual or semi-manual steps to do it.


# Obtain Windows ISO

You must first obtain a Windows ISO image and make sure you are
licensed to spawn virtual machines based on these images.


# Prepare VM

## Hardware requirements

If you set the disk to be IDE or SCSI you probably won't be able to switch
once installed, so make sure you set the proper type before installing.

If you use virtio storage or network, you will need proper drivers for it. The
[Windows Virtio Drivers](https://fedoraproject.org/wiki/Windows_Virtio_Drivers)
Fedora project provides a pre-built ISO image with all of them. Declare
a second CD-ROM drive for that ISO while installing, in addition to the
first drive that will contain the Windows install ISO image.

That .iso file contains the following bits:
* `NetKVM/`: virtio network driver
* `viostor/`: virtio block driver
* `vioscsi/`: virtio SCSI driver
* `viorng/`: virtio RNG driver
* `vioser/`: virtio serial driver
* `Balloon/`: virtio memory balloon driver
* `qxl/`: QXL graphics driver for Windows 7 and earlier
* `qxldod/`: QXL graphics driver for Windows 8 and later
* `pvpanic/`: QEMU pvpanic device driver
* `guest-agent/`: QEMU Guest Agent 32bit and 64bit MSI installers
* `qemupciserial/`: QEMU PCI serial device driver
* `*.vfd`: VFD floppy images for using during install of Windows XP

You will have to load the one in `viostor/` during the install. The
rest can be done later. You probably want to install `NetKVM/` first. To
install a driver later is simply a matter of right-clicking the `.inf`
file and run _Install_.

## Setup correct disk image

Disks made through VirtualManager somehow grow when copied (probably has to
do with sparse files and btrfs). Create the disk manually to get a "normal"
qcow2 file that stays the same size when copied. basiliQA standard size
is 18GB, sufficient for Windows OSes.
```bash
  $ qemu-img create -f qcow2 windowsXYZ.qcow2 18G
```

# Install Windows

If you install a GUI-less windows here are a few Powershell commands that might reveal useful:

* set kb layout: <code>set-winuserlanguagelist -languagelist fr-FR</code>
* download file: <code>wget -UseBasicParsing -outfile output.zip http://example.com</code>
* extract zip: <code>expand-archive foo.zip -dest C:\foo\destination</code>
* rename: <code>mv old new</code>
* edit file: <code>notepad file.txt</code>


# Automatic Setup

At this point you can either use the automated setup script from
`automated` directory, or do it manually.

The automated setup script is a Powershell+bash script based on the msys2
solution. If you want to use another openSSH implementation, you'll have
to go for the manual method.

For further information on the automated script, please refer to the README
file in the same directory.


# Manual Setup

## Setup the SSH server

You can use msys2 openSSH, cygwin openSSH, or the new openSSH port for
Windows maintained by Microsoft.

With cygwin and msys2, you get a UNIX environment (bash, gnu coreutils, etc).
The MS port is much more lightweight and only provides the ssh session
(you get a cmd.exe prompt from which you can run Powershell though).

At the time of this writing (2016-10-19), the MS port is still not very
mature: we've experienced issues with the sshd service not starting and
strange broken pipes.

### msys2 OpenSSH

* Install msys2 http://msys2.github.io/
* Open the msys2 shell
* Install tools through the package manager
```
  pacman -S --force openssh cygrunsrv mingw-w64-x86_64-editrights
```
* Run the `msys2-sshd-setup.sh` script to setup the sshd service
  (copied into `manual` directory from
   [github.com/samhocevar](https://gist.github.com/samhocevar/00eec26d9e9988d080ac)
  ).
* Open or disable firewall
```
    # open port 22
    PS> New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH
    # or disable firewall entirely
    PS> netsh advfirewall set allprofiles state off
```

### Microsoft OpenSSH

Microsoft maintains an official port of OpenSSH.
See https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH

* Download the latest build
* Extract contents to <code>C:\Program Files\OpenSSH</code>
* Start Powershell as Administrator
```
    PS> cd 'C:\Program Files\OpenSSH'
```
* Install sshd and ssh-agent services
```
    PS> powershell -executionpolicy bypass -file install-sshd.ps1
```
* Setup SSH host keys (this will generate all the 'host' keys that sshd expects when its starts)
```
    PS> .\ssh-keygen.exe -A
```
* Open the firewall, either by opening port 22
```
    PS> New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH
```
  or by completly disabling the firewall
```
    PS> netsh advfirewall set allprofiles state off
```
* As you will need key-based authentication, run the following to setup the key-auth package
```
    PS> powershell -executionpolicy bypass -file install-sshlsa.ps1
```
* Set sshd in auto-start mode
```
    PS> Set-Service sshd -StartupType Automatic
    PS> Set-Service ssh-agent -StartupType Automatic
    PS> Restart-Computer
```
* Try login from a ssh client (Administrator@<ip>)
```
    unix$ ssh Administrator@<ip>
```

### Cygwin OpenSSH

(TODO)

## Disable password policy

As we want to set dumb passwords, we have to disable the password security requirements.

### GUI install

* `Win+r secpol.msc`
* _Account Policies_ > _Password Policy_ > _Password must meet complexity requirements_ > _Disabled_

### GUI-less

Extract security policy to a file:
```
    PS> secedit /export /cfg sec.cfg
    PS> notepad sec.cfg
```
Change line `PasswordComplexity = 1` to `PasswordComplexity = 0`, then
reinject the modified configuration:
```
    PS> secedit /configure /db C:\Windows\security\new.sdb /cfg sec.cfg /areas SECURITYPOLICY
```

## Create users

* Add basiliQA users

```
    WIN> net user root opensuse /add
    WIN> net user testuser opensuse /add
    WIN> net localgroup administrators root /add
```

* Change Administrator password

```
  WIN> net user administrator opensuse
```

## SSH key auth

* For msys2 and cygwin using `ssh-copy-id` from a UNIX client should work as usual.
* For Microsoft OpenSSH:
```
    unix$ ssh <user>@<ip>
    WIN> mkdir .ssh
    WIN> cd .ssh
    WIN> echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDACq4gE5DkYy/QoYsZhA8klmziLOwXRsCo7OKoCeaYYgSPNwdsnqYrXTiYv8cJX3tqsXlu+h4BESokKIDIlRMHkULek8ctIpC5EeDDY3of/1fUwJKDf0xdYLtOT/Y4gHVYm6qAo23Mj0dtVVH+uv+O7I2j3VNW/8cAL3KDtV24jpa3fZUyf1G59xiENK0MR6UGNXYD0sSffstwJtFP+va1eRsepcp6Es612dfPJGnBBqpncIMg9lLuTe8HSCY7QIdciFdE0mk7MjHx1BpDrJ0M4KgqOxWh5Lpueflg0b9TERK1NgjN96gjBMbd+ln7vsESXbJSxmyXcEBXb5d6U6jr basiliqa@opensuse > authorized_keys
    WIN> exit
```
  __Don't use quotes in the echo command.__ Use `cls` to clear messed up screen.
* Test key login
```
    unix$ ssh -i /usr/lib/basiliqa/init-jail/ssh_id_rsa <user>@<ip>
```
