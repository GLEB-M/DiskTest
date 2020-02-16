# DiskTest
**Disk drive surface testing using BIOS Enhanced Disk Drive Services**

***Run from GRUB***
```
title DiskTest
chainloader --force --load-segment=0x0 --load-offset=0x8000 --boot-cs=0x800 --boot-ip=0x0 /disktest.bin
```

***Build***

Use **FASM**

***Restrictions***

No S.M.A.R.T. Only disk surface checking to detect bad blocks

![DiskTest](https://raw.githubusercontent.com/dx8vb/DiskTest/master/disktest.png)
