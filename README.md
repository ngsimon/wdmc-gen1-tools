# Tools and scripts for WD MyCloud 1st generation (Gen1)
----------
**More info on my website: https://anionix.ru and archive: http://ftp.anionix.ru**

- **build-64k-packages** directory:
 - For install build env:
`./make_buildenv.sh`
  - Then, chroot inside and do:
`./mountall.sh`
  - After this you can build packages from official Debian site:
`./batch_build.sh {package1} {package2} {package3}...`
  - When you done, you can clean current dir (Removes only downloaded files):
`./clear_dir.sh`
  - Before exit env, unmount all:
`./mountall.sh done`
- Install chroot in WDMyCloud:
`./Install-chroot-jessie-64k.sh {folder_name}`
- Create and update repositiory (Must be inside web folder, where you want to place repository):
`./update-debian-dist.sh`