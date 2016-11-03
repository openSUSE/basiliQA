# What is this?

This directory contains a bunch of code to automate the preparation of a
Window install so that it can be used by basiliQA.

It creates the users and sets up a SSH server with key
authentification with the basiliQA pub keys already added.

The script installs a recent msys2 build which gives you very basic
UNIX environement.

The msys2 distribution tarball can be downloaded from here:
```
    http://repo.msys2.org/distrib/
```

The `7za.exe` command line binary can be downloaded from there:
```
    http://www.7-zip.org/download.html
```

The `full-install.ps1` script is the only thing you are supposed to
run. It's a powershell script. It later calls the setup.sh bash
script on its own.

This whole thing has only been tested on Windows Server 2016, but it
should hopefully work on other Windows version, as long as Powershell
is available.


# Usage

1. Copy over the files to the Windows OS

   * Solution 1: For this you can simply zip the content of the repo
     somewhere online, download it in windows and extract it.
     ```
        PS> wget -UseBasicParsing -outfile prep.zip http://example.com/prep.zip
        PS> expand-archive prep.zip -dest basiliqa
        PS> del prep.zip
     ```

   * Solution 2: Alternatively you can set up a samba share on a linux
     host and copy it from there
     ```
        linux$ mkdir -p /tmp/public && chmod 777 /tmp/public
        linux$ # put the files in /tmp/public
        linux$ echo -e "[public]\npath = /tmp/public\nread only = no\nbrowseable = yes\nguest ok = yes\n" >> /etc/samba/smb.conf
        linux$ systemctl restart smb
     ```
     Then from the Windows host
     ```
        PS> copy-item -recurse \\linuxhost\public -dest basiliqa
     ```

2. Run main script
   ```
      PS> cd basiliqa
      PS> powershell -executionpolicy bypass -file full-install.ps1
   ```

3. Go take a coffee or something, cross fingers while you're at it.

4. Try to login from the linux box
   ```
      linux$ ssh -i /usr/lib/basiliqa/init-jail/ssh_id_rsa testuser@windowshost
      ^D
      linux$ ssh -i /usr/lib/basiliqa/init-jail/ssh_id_rsa root@windowshost
      ^D
   ```

5. Enjoy!
