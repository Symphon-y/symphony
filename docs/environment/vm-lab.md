# System report

## Identity

```text
generated: 2026-09-13T04:00:13Z
hostname:  archiso
kernel:    Linux 7.2.2-arch1-1 x86_64
```

## Virtualization

```text
detected: kvm
sys_vendor:   QEMU
product_name: Standard PC (Q35 + ICH9, 2009)
bios_vendor:  EDK II
bios_version: unknown
```

## Firmware

```text
boot mode:     UEFI
platform size: 64-bit
```

## CPU

```text
Architecture:                            x86_64
CPU(s):                                  8
Model name:                              13th Gen Intel(R) Core(TM) i9-13900K
Thread(s) per core:                      2
Core(s) per socket:                      4
Socket(s):                               1
Virtualization:                          VT-x
Hypervisor vendor:                       KVM
Virtualization type:                     full
```

## Memory

```text
               total        used        free      shared  buff/cache   available
Mem:            15Gi       569Mi        14Gi       114Mi       692Mi        15Gi
Swap:             0B          0B          0B
```

## GPU

```text
00:1e.0 VGA compatible controller [0300]: Red Hat, Inc. QXL paravirtual graphic card [1b36:0100] (rev 05)
	Subsystem: Red Hat, Inc. QEMU Virtual Machine [1af4:1100]
	Kernel driver in use: qxl
	Kernel modules: qxl

DRM device nodes: /dev/dri/by-path /dev/dri/card1
```

## Storage

```text
NAME     SIZE TYPE FSTYPE   MOUNTPOINTS           MODEL        ROTA DISC-GRAN
loop0 1018.8M loop squashfs /run/archiso/airootfs                 1        0B
sr0      1.5G rom  iso9660  /run/archiso/bootmnt  QEMU DVD-ROM    1        0B
vda      128G disk                                                1      512B
```

## Network

```text
lo               UNKNOWN        <mac> <LOOPBACK,UP,LOWER_UP> 
enp1s0           UP             <mac> <BROADCAST,MULTICAST,UP,LOWER_UP> 

lo               UNKNOWN        <ipv4>/8 ::1/128 
enp1s0           UP             <ipv4>/24 metric 100 <ipv6>/64 <ipv6>/64 <ipv6>/64 

default via <ipv4> dev enp1s0 proto dhcp src <ipv4> metric 100 
<ipv4>/24 dev enp1s0 proto kernel scope link src <ipv4> metric 100 
<ipv4> dev enp1s0 proto dhcp scope link src <ipv4> metric 100 
<ipv4> dev enp1s0 proto dhcp scope link src <ipv4> metric 100 
<ipv4> dev enp1s0 proto dhcp scope link src <ipv4> metric 100 

Global:
Link 2 (enp1s0): <ipv4> <ipv4> <ipv4>
```

## Time

```text
               Local time: Sun 2026-09-13 04:00:13 UTC
           Universal time: Sun 2026-09-13 04:00:13 UTC
                 RTC time: Sun 2026-09-13 04:00:13
                Time zone: UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```

## Audio

```text
(no PCI audio device)
```

## Input devices

```text
N: Name="Power Button"
N: Name="AT Translated Set 2 keyboard"
N: Name="QEMU QEMU USB Tablet"
N: Name="PC Speaker"
N: Name="VirtualPS/2 VMware VMMouse"
N: Name="VirtualPS/2 VMware VMMouse"
```

## Session and packages

```text
XDG_SESSION_TYPE: tty
1 0 root seat0 788  user-early    tty1 no -
2 0 root -     1043 manager-early -    no -
installed packages: 462
```

## Install gates

| Gate | Checks | Result |
|---|---|---|
| uefi64 | 64-bit UEFI firmware | PASS |
| disk | an installable disk is present | PASS |
| network | a default route exists | PASS |
| dns | archlinux.org resolves | PASS |
| ntp | clock is NTP-synchronized | PASS |
