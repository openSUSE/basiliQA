#
# powershell script to run first
#

# this script install msys2 and runs the bash setup script for openssh

$pkg = @(ls msys2-*.tar.xz)[0] | select -expand name
$tar = $pkg -replace ".xz$", ""

# extract .tar.xz to .tar
.\7za x $pkg
# extract .tar
.\7za x -oC:\ $tar

del $pkg
del $tar

# first run will setup msys2
cmd /c C:\msys64\usr\bin\bash.exe --login -c "echo ok"

# - Powershell will expand $PWD before calling cmd to a Windows path (C:\...)
# - bash will implicitely convert it in cd
# - We can now run setup.sh
cmd /c C:\msys64\usr\bin\bash.exe --login -c "cd '$PWD' ; bash setup.sh"
