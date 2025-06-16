# Home Assistant OS bhyve VM Installer for TC/BSD

This project provides an interactive installer and rc.d integration to run Home Assistant OS in a bhyve virtual machine on **TwinCAT/BSD** or **FreeBSD-based** systems.

## Features

- ✅ Interactive `configure.sh` wizard with default values
- ✅ Auto-downloads and converts latest HAOS QCOW2 image
- ✅ Auto-generates `/etc/rc.d/<vm_name>` startup script
- ✅ Creates system config in `/usr/local/etc/<vm_name>.conf`
- ✅ Supports VNC framebuffer, CPU/memory config, and networking
- ✅ Designed and tested for **TC/BSD** (uses `doas` instead of `sudo`)
- ✅ Fully scriptable with `make` commands

## Requirements

- Tested on: **TC/BSD** (Beckhoff), based on FreeBSD
- Tools: `fetch`, `xz`, `qemu-img`, `bhyve`, `doas`, `rc.subr`
- bhyve UEFI firmware at `/boot/firmware/UEFI.fd` and `EFI_VARS.fd`

## Usage

```bash
make configure
```

The wizard will prompt you for:

- VM name
- Memory (e.g., 2G)
- CPU topology (sockets, cores, threads)
- VNC port and framebuffer size
- External NIC and TAP interface
- Home Assistant OS download URL (defaults to latest stable)

The resulting config is stored in:

```
/usr/local/etc/<vm_name>.conf
```

And the VM will be installed in:

```
/vms/<vm_name>
```

To install the VM service and enable autostart:

```bash
make install
service <vm_name> start
```

To uninstall:

```bash
make uninstall
```

To clean up files and VM state:

```bash
make clean
```

To reset TAP/bridge network config:

```bash
make clean-network
```

## Notes

- Default image URL: https://github.com/home-assistant/operating-system/releases/download/12.3/haos_ova-12.3.qcow2.xz
- You may change this in the wizard or later in the config file
- All service scripts are placed in `/etc/rc.d/<vm_name>`

## License

MIT — Feel free to modify and distribute for custom automation environments.
