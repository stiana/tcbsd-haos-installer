INSTALL_PATH ?= /vms
CONFIG_DIR ?= /usr/local/etc

include $(wildcard $(CONFIG_DIR)/*.conf)

all: configure

configure:
	sh configure.sh

install:
	@echo "Installing VM startup script..."
	install -m 755 /etc/rc.d/$(vm_name) /etc/rc.d/$(vm_name)
	@echo "Enabling service..."
	sysrc $(vm_name)_enable=YES

uninstall:
	@echo "Stopping and uninstalling..."
	-service $(vm_name) stop || true
	rm -f /etc/rc.d/$(vm_name)
	rm -f $(CONFIG_DIR)/$(vm_name).conf
	rm -rf $(INSTALL_PATH)/$(vm_name)

clean:
	rm -f *.raw *.qcow2 *.xz *.log

clean-network:
	@ifconfig $(tap_interface) destroy || true
	@ifconfig bridge0 destroy || true
