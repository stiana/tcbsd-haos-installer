# Default paths
INSTALL_PATH ?= /vms
CONFIG_DIR ?= /usr/local/etc

# Attempt to include configuration variables (optional)
-include $(wildcard $(CONFIG_DIR)/*.conf)

# Default make target
all: configure

# Interactive configuration wizard
configure:
	sh configure.sh

# Install rc.d service script for VM
install: check-config
	@echo "Installing VM startup script..."
	install -m 755 /etc/rc.d/$(vm_name) /etc/rc.d/$(vm_name)
	@echo "Enabling service..."
	sysrc $(vm_name)_enable=YES

# Uninstall VM and service
uninstall: check-config
	@echo "Stopping and uninstalling VM..."
	-service $(vm_name) stop || true
	rm -f /etc/rc.d/$(vm_name)
	rm -f $(CONFIG_DIR)/$(vm_name).conf
	rm -rf $(INSTALL_PATH)/$(vm_name)

# Clean downloaded/generated files
clean:
	rm -f *.raw *.qcow2 *.xz *.log

# Clean network interfaces
clean-network:
	@ifconfig $(tap_interface) destroy || true
	@ifconfig bridge0 destroy || true

# Ensure config file exists
check-config:
	@if [ -z "$(vm_name)" ]; then \
		echo "No VM configuration found. Please run 'make configure' first."; \
		exit 1; \
	fi
