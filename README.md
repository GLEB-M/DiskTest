# DiskTest
Disk drive surface testing using BIOS Enhanced Disk Drive Services

***Run via GRUB***
```
title DiskTest
chainloader --force --load-segment=0x0 --load-offset=0x8000 --boot-cs=0x800 --boot-ip=0x0 /disktest.bin
```

![DiskTest](https://raw.githubusercontent.com/dx8vb/DiskTest/master/disktest.png)
