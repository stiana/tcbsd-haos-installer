#!/bin/sh

# Interactive configuration wizard for bhyve Home Assistant VM
# This script generates a config file for use with rc.d and Makefile tooling

CONFIG_DIR="/usr/local/etc"
LOG_FILE="configure.log"

# Enable timestamped logging to both terminal and logfile
exec > >(tee -a "$LOG_FILE") 2>&1
export PS4='+ [$(date "+%Y-%m-%d %H:%M:%S")] '
set -x

echo "==== Starting Home Assistant VM configuration wizard ===="
echo "Logging to: $LOG_FILE"

# Check for required tools
TOOLS="fetch xz qemu-img mkdir cp"
echo "Checking required tools..."
for tool in $TOOLS; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ Error: required tool '$tool' is missing. Please install it."
        exit 1
    fi
    echo "✅ Found: $tool"
done


prompt() {
    var="$1"
    default="$2"
    prompt_text="$3"
    read -p "$prompt_text [$default]: " input
    eval "$var="${input:-$default}""
}

# Ask for main settings
prompt vm_name "home-assistant-vm" "Enter VM name"
prompt memory_size "2G" "Enter VM memory size (e.g. 2G, 4096M)"
prompt cpu_sockets "1" "Enter number of CPU sockets"
prompt cpu_cores "2" "Enter number of CPU cores per socket"
prompt cpu_threads "1" "Enter number of CPU threads per core"
prompt ext_if "igb1" "Enter external network interface (e.g. igb1)"
prompt tap_interface "tap0" "Enter tap interface name"
prompt vnc_port "5900" "Enter VNC port (5900 = :0)"
prompt framebuffer_width "1280" "Enter framebuffer width"
prompt framebuffer_height "1024" "Enter framebuffer height"
prompt haos_image_url "https://github.com/home-assistant/operating-system/releases/download/12.3/haos_ova-12.3.qcow2.xz" "Enter Home Assistant OS image URL"

# Paths derived from vm_name
install_path="/vms/${vm_name}"
disk_path="${install_path}/haos.raw"
bhyve_uefi_fd="${install_path}/UEFI.fd"
bhyve_efi_vars="${install_path}/EFI_VARS.fd"
rcd_script_path="/etc/rc.d/${vm_name}"

# Config output file
config_file="${CONFIG_DIR}/${vm_name}.conf"

# Write config file with comments for manual editing
cat > "$config_file" <<EOF
# Configuration for bhyve-based Home Assistant VM "$vm_name"

# VM name (used for filenames and rc.d script name)
vm_name="$vm_name"

# Memory size for VM
memory_size="$memory_size"

# CPU topology
cpu_sockets=$cpu_sockets
cpu_cores=$cpu_cores
cpu_threads=$cpu_threads

# Networking
ext_if="$ext_if"
tap_interface="$tap_interface"

# VNC display settings
vnc_port=$vnc_port
framebuffer_width=$framebuffer_width
framebuffer_height=$framebuffer_height

# Home Assistant OS image source
haos_image_url="$haos_image_url"

# Paths (auto-generated)
install_path="$install_path"
disk_path="$disk_path"
bhyve_uefi_fd="$bhyve_uefi_fd"
bhyve_efi_vars="$bhyve_efi_vars"
rcd_script_path="$rcd_script_path"
EOF

echo "\nConfiguration saved to $config_file"

# Download HAOS image if not present
IMG_FILE="haos.qcow2.xz"
IMG_URL="$haos_image_url"

if [ ! -f "$IMG_FILE" ]; then
    echo "\nDownloading Home Assistant image..."
    fetch -o "$IMG_FILE" "$IMG_URL"
else
    echo "\n$IMG_FILE already exists. Skipping download."
fi

# Unpack image
QCOW2_FILE="haos.qcow2"
if [ ! -f "$QCOW2_FILE" ]; then
    echo "\nExtracting image..."
    xz -d "$IMG_FILE"
fi

# Create install path if not exists
if [ ! -d "$install_path" ]; then
    echo "\nCreating VM directory: $install_path"
    mkdir -p "$install_path"
fi

# Convert to raw if not already done
if [ ! -f "$disk_path" ]; then
    echo "\nConverting image to raw..."
    qemu-img convert -f qcow2 -O raw "$QCOW2_FILE" "$disk_path"
fi

# Copy UEFI firmware files
if [ ! -f "$bhyve_uefi_fd" ]; then
    cp /boot/firmware/UEFI.fd "$bhyve_uefi_fd"
fi
if [ ! -f "$bhyve_efi_vars" ]; then
    cp /boot/firmware/EFI_VARS.fd "$bhyve_efi_vars"
fi

# Generate rc.d script for this VM
cat > "$rcd_script_path" <<RC
#!/bin/sh
# PROVIDE: $vm_name
# REQUIRE: NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="$vm_name"
rcvar=\${name}_enable

load_rc_config \$name
: \${\$rcvar:=NO}

start_cmd="\${name}_start"
stop_cmd="\${name}_stop"

\${name}_start() {
    . "$config_file"
    echo "Starting VM: \$vm_name"
    bhyve -c sockets=\$cpu_sockets,cores=\$cpu_cores,threads=\$cpu_threads \
        -m \$memory_size \
        -l bootrom,\$bhyve_uefi_fd,\$bhyve_efi_vars,fwcfg=qemu \
        -s 0,hostbridge \
        -s 2,fbuf,rfb=0.0.0.0:\$vnc_port,w=\$framebuffer_width,h=\$framebuffer_height \
        -s 3,xhci,tablet \
        -s 10,ahci-hd,\$disk_path \
        -s 20,virtio-net,\$tap_interface \
        -s 31,lpc -A -H -P -w \$vm_name
}

\${name}_stop() {
    echo "Stopping VM: \$vm_name"
    bhyvectl --destroy --vm=\$vm_name
}

run_rc_command "\$1"
RC

chmod +x "$rcd_script_path"
echo "✅ rc.d script created at $rcd_script_path"

# Done
echo "\n✅ Home Assistant VM setup complete. Run 'make install' to finish setup."
echo "📄 Log written to $LOG_FILE"
