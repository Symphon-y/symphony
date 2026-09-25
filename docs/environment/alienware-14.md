# Alienware 14 (P39G) -- ground truth

The machine symphony is installed on and driven from since 2026-09-20 (D-0063). Below
the report is what the work learned about it that a report cannot show. Regenerate the
report with `scripts/system-report`. Open work on this machine is tracked in GitHub
issues; the reasoning behind each choice is in `DECISIONS.md`.

### System report (2026-09-21, installed system, linux-lts)

### Identity

```text
generated: 2026-09-21T03:34:54Z
hostname:  alien
kernel:    Linux 6.18.52-1-lts x86_64
```

### Virtualization

```text
detected: none
sys_vendor:   Alienware
product_name: Alienware 14
board_name:   07MJ2Y
bios_vendor:  Alienware
bios_version: A09
```

### Firmware

```text
boot mode:     UEFI
platform size: 64-bit
```

### CPU

```text
Architecture:                            x86_64
CPU(s):                                  4
Model name:                              Intel(R) Core(TM) i5-4200M CPU @ 2.50GHz
Thread(s) per core:                      2
Core(s) per socket:                      2
Socket(s):                               1
CPU(s) scaling MHz:                      82%
Virtualization:                          VT-x
```

### Memory

```text
               total        used        free      shared  buff/cache   available
Mem:           7.6Gi       2.0Gi       3.3Gi       325Mi       2.9Gi       5.7Gi
Swap:           19Gi          0B        19Gi
```

### GPU

```text
00:02.0 VGA compatible controller [0300]: Intel Corporation 4th Gen Core Processor Integrated Graphics Controller [8086:0416] (rev 06)
	Subsystem: Dell Device [1028:05a9]
	Kernel driver in use: i915
	Kernel modules: i915
--
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK107M [GeForce GT 750M] [10de:0fe4] (rev a1)
	Subsystem: Dell Device [1028:05a9]
	Kernel driver in use: nouveau
	Kernel modules: nouveau

DRM device nodes: /dev/dri/by-path /dev/dri/card0 /dev/dri/card1 /dev/dri/renderD128 /dev/dri/renderD129
```

### Storage

```text
NAME            SIZE TYPE  FSTYPE      MOUNTPOINTS           MODEL                   ROTA DISC-GRAN
sda           465.8G disk                                    ST500LM000-1EJ162          1        0B
├─sda1            2G part  vfat        /efi                                             1        0B
├─sda2           16G part  crypto_LUKS                                                  1        0B
│ └─cryptswap    16G crypt swap        [SWAP]                                           1        0B
└─sda3        447.8G part  crypto_LUKS                                                  1        0B
  └─root      447.7G crypt btrfs       /var/cache/pacman/pkg                            1        0B
                                       /home                                              
                                       /var/log                                           
                                       /.snapshots                                        
                                       /                                                  
sr0            1024M rom                                     HL-DT-ST DVD+/-RW GS40N    0        0B
zram0           3.8G disk  swap        [SWAP]                                           0        4K
```

### Network

```text
lo               UNKNOWN        <mac> <LOOPBACK,UP,LOWER_UP> 
enp8s0           DOWN           <mac> <NO-CARRIER,BROADCAST,MULTICAST,UP> 
wlp10s0          UP             <mac> <BROADCAST,MULTICAST,UP,LOWER_UP> 

lo               UNKNOWN        <ipv4>/8 ::1/128 
enp8s0           DOWN           
wlp10s0          UP             <ipv4>/24 <ipv6>/64 <ipv6>/64 

default via <ipv4> dev wlp10s0 proto dhcp src <ipv4> metric 600 
<ipv4>/24 dev wlp10s0 proto kernel scope link src <ipv4> metric 600 

Global:
Link 2 (enp8s0):
Link 3 (wlp10s0): <ipv4> <ipv4> <ipv4>
```

### Wi-Fi

```text
WIFI-HW  WIFI     WWAN-HW  WWAN    
enabled  enabled  missing  enabled 

0: phy0: Wireless LAN
	Soft blocked: no
	Hard blocked: no
1: hci0: Bluetooth
	Soft blocked: no
	Hard blocked: no

Machine: Alienware Alienware 14
Wi-Fi adapter: 14e4:43b1 (driver wl)
Wireless interfaces: wlp10s0
rfkill phy0 (wlan, driver wl): not blocked
rfkill hci0 (bluetooth): not blocked

0a:00.0 Network controller [0280]: Broadcom Inc. and subsidiaries BCM4352 802.11ac Dual Band Wireless Network Adapter [14e4:43b1] (rev 03)
	Subsystem: AzureWave Device [1a3b:2b23]
	Kernel driver in use: wl
	Kernel modules: bcma, wl

dell_wmi               28672  0
dell_smbios            36864  1 dell_wmi
dcdbas                 20480  1 dell_smbios
dell_wmi_descriptor    20480  2 dell_wmi,dell_smbios
wmi_bmof               12288  0
sparse_keymap          12288  2 dell_wmi,quickstart
dell_lis3lv02d         16384  0
rfkill                 45056  5 bluetooth,cfg80211
dell_smo8800           16384  0
mxm_wmi                12288  1 nouveau
video                  81920  3 dell_wmi,i915,nouveau
wmi                    32768  7 video,dell_wmi,wmi_bmof,dell_smbios,dell_wmi_descriptor,mxm_wmi,nouveau

(no relevant kernel messages, or dmesg is not readable)
```

### Time

```text
               Local time: Sun 2026-09-20 22:34:55 CDT
           Universal time: Mon 2026-09-21 03:34:55 UTC
                 RTC time: Mon 2026-09-21 03:34:55
                Time zone: America/Chicago (CDT, -0500)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```

### Audio

```text
00:03.0 Audio device [0403]: Intel Corporation Xeon E3-1200 v3/4th Gen Core Processor HD Audio Controller [8086:0c0c] (rev 06)
00:1b.0 Audio device [0403]: Intel Corporation 8 Series/C220 Series Chipset High Definition Audio Controller [8086:8c20] (rev 05)
01:00.1 Audio device [0403]: NVIDIA Corporation GK107 HDMI Audio Controller [10de:0e1b] (rev a1)
 0 [HDMI           ]: HDA-Intel - HDA Intel HDMI
                      HDA Intel HDMI at 0xd2910000 irq 35
 1 [PCH            ]: HDA-Intel - HDA Intel PCH
                      HDA Intel PCH at 0xd2914000 irq 36
 2 [NVidia         ]: HDA-Intel - HDA NVidia
                      HDA NVidia at 0xd1000000 irq 17
```

### Input devices

```text
N: Name="Power Button"
N: Name="Lid Switch"
N: Name="Power Button"
N: Name="AT Translated Set 2 keyboard"
N: Name="Video Bus"
N: Name="Video Bus"
N: Name="Quickstart Button 4"
N: Name="Quickstart Button 5"
N: Name="Quickstart Button 8"
N: Name="Quickstart Button 6"
N: Name="PC Speaker"
N: Name="Dell WMI hotkeys"
N: Name="HDA Intel HDMI HDMI/DP,pcm=3"
N: Name="HDA Intel HDMI HDMI/DP,pcm=7"
N: Name="HDA Intel HDMI HDMI/DP,pcm=8"
N: Name="HDA Intel PCH Mic"
N: Name="HDA Intel PCH Headphone Front"
N: Name="HDA Intel PCH Headphone Surround"
N: Name="HDA NVidia HDMI/DP,pcm=3"
N: Name="HDA NVidia HDMI/DP,pcm=7"
N: Name="HDA NVidia HDMI/DP,pcm=8"
N: Name="HDA NVidia HDMI/DP,pcm=9"
N: Name="SynPS/2 Synaptics TouchPad"
```

### Session and packages

```text
XDG_SESSION_TYPE: wayland
1 1000 travis seat0 665 user    tty1 no -
2 1000 travis -     672 manager -    no -
installed packages: 704
```

### Install gates

| Gate | Checks | Result |
|---|---|---|
| uefi64 | 64-bit UEFI firmware | PASS |
| disk | an installable disk is present | PASS |
| network | a default route exists | PASS |
| dns | archlinux.org resolves | PASS |
| ntp | clock is NTP-synchronized | PASS |

## What the phases learned (not in the report)

- **Firmware:** BIOS A09 (2014-04-23). Has *Advanced > Function Key Behavior* and a
  *Wireless* menu. `Fn+F2` (Wi-Fi symbol) moves a firmware airplane-mode slider that
  `dell_rbtn` used to expose as an rfkill that is hard-blocked and cannot be cleared from
  software; the state is intermittent (three blocked boots, then an unblocked one after
  Fn+F2 plus an EC power-cycle). `module_blacklist=dell_rbtn` on the kernel command line
  removes it, proven on all three boot entries (D-0076; the entry now lives in
  `system/hardware.txt`, which absorbed `quirks.txt` in D-0082). With the
  blacklist, Fn+F2 does nothing; use the bar or `nmcli radio wifi off`.
- **Wi-Fi:** Broadcom BCM4352 (`14e4:43b1`, AzureWave `1a3b:2b23`, Dell DW1550). No open
  driver; `broadcom-wl-dkms` builds `wl` for `linux` and `linux-lts` at install
  (D-0074, `system/hardware.txt`). Consequences: no Wi-Fi in the live ISO (the installer's
  Wi-Fi page says the driver comes with the installed system); `wl` cannot do SAE, so a
  WPA2/WPA3 transition network must be joined with `wpa-psk` (D-0077); the kernel is
  tainted `P S W IOE` and logs two `WARNING`s from `wl` at every boot ("Unpatched return
  thunk in use", a `memcpy` field-spanning write in `wl_cfg80211_hybrid.c`) -- known
  noise on current kernels, the card works. Regulatory domain `US` is honoured
  (`iw reg get`). 2.4 and 5 GHz both associate.
- **Ethernet:** Qualcomm Atheros Killer E220x (`1969:e091`, `alx`), `enp8s0`, untested with a cable.
- **GPU:** Intel HD 4600 (`i915`) drives the desktop; Hyprland renders fine on it and the
  installer needed `GSK_RENDERER=gl` (D-0066). The NVIDIA GT 750M binds `nouveau` and
  provides a second DRM node; nothing uses it deliberately (bonus, untested — issue #2).
- **Storage:** 500 GB 2.5" HDD (ST500LM000, rotational). LUKS2 root on Btrfs with the
  `@`/`@home`/`@log`/`@pkg`/`@snapshots` layout, 16 GB LUKS swap for hibernation
  (`resume=` wired; hibernate/resume itself still unverified -- issue #1), 2 GB ESP
  at `/efi` with UKIs for `linux`, `linux-lts` and their fallbacks.
- **Memory:** 8 GB, plus a 3.8 GB zram swap.
- **Input:** Synaptics PS/2 touchpad; Dell WMI hotkeys; four "Quickstart" buttons.
- **Audio:** three HDA controllers (Intel HDMI, Intel PCH, NVIDIA HDMI). The PCH card
  (`card1`) is the one with the speakers and jack; its codec is a **Realtek ALC3661**.
  Nothing played until a *global* ALSA soft-mixer rule was dropped: it muted every output
  pin in hardware on every card, which `symphony-hardware scan` now reports as
  "every output pin muted" by reading `Amp-Out vals` bit 7 out of
  `/proc/asound/card*/codec#*`. PipeWire manages the hardware mixer; `alsa-utils` and
  `rtkit` ship (D-0083).
- **AlienFX lighting:** a USB HID controller at `187c:0525`, four bits per colour channel.
  Driven by our own `alienfx` package (D-0084) — upstream's AUR build is uninstallable and
  its zone map is for a different model. `alienfx --zonescan` on this machine found seven
  usable zones: keyboard `0x0001`/`0x0002`/`0x0004`/`0x0008` left to right, alien head
  `0x0080`, logo `0x0100`, touchpad `0x0200`, status LEDs `0x0800`. `alienfx-theme` repaints
  them from the palette's `PRIMARY` on every wallpaper change, after removing the colour's
  white floor — Material You pastels otherwise read as washed-out pink through 4-bit
  channels regardless of hue. Access is granted by a `uaccess` udev rule (ours, not
  upstream's `MODE=666`), which only applies to an already-plugged device after
  `udevadm control --reload` plus a re-trigger, so `symphony-hardware apply` does both.
- **Power:** `power-profiles-daemon` enabled and active, `balanced` by default (D-0083;
  folded in from Phase 12's task list).
- **Not on this machine:** TPM (Secure Boot deferred), a working `docker` daemon (podman
  with docker emulation, so local ISO builds need `SYMPHONY_CONTAINER_ENGINE="sudo podman"`
  — rootless podman cannot mount the chroot).
- **A trap worth remembering:** `/dev/bus/usb` is mode 755 from devtmpfs. A `chmod` aimed
  at a device node but landing on the directory takes the execute bits away, and every
  libusb tool then fails with `EACCES` no matter what udev grants on the nodes.
  `symphony-hardware scan` reports it.
- **Install history:** `2026.09.17-test14` (base, Phase 14), `2026.09.18-test2` (GUI,
  Phase 15), `2026.09.19-test1` (desktop round 1, Phase 16), `local-5c8bcf1` (2026-09-20,
  the current install, D-0074's commit; later checkouts deployed over it with
  `symphony-update apply --from`, D-0079). It will not be reinstalled to test ISOs -- it is
  the dev seat; fresh-install proofs need a second machine (issues #3 and #4).
