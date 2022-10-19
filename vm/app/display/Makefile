# SPDX-License-Identifier: EUPL-1.2+
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-system-aarch64
CLOUD_HYPERVISOR = cloud-hypervisor

VMM = qemu

HOST_FILES = \
	host/data/appvm-display/providers/net/netvm \
	host/data/appvm-display/imx8qm-mek-hdmi-vm.dtb

HOST_BUILD_FILES = \
	build/host/data/appvm-display/rootfs.ext4 \
	build/host/data/appvm-display/Image

# We produce a directory, but that doesn't play nice with Make,
# because it won't know to update if some file in the directory is
# changed, or a file is created or removed in a subdirectory.  Using
# the whole directory could also end up including files that aren't
# intended to be part of the input, like temporary editor files or
# .license files.  So for all these reasons, only explicitly listed
# files are included in the build result.
build/svc: $(HOST_FILES) $(HOST_BUILD_FILES)
	rm -rf $@
	mkdir -p $@

	tar -c $(HOST_FILES) | tar -C $@ -x --strip-components 1
	tar -c $(HOST_BUILD_FILES) | tar -C $@ -x --strip-components 2

build/host/data/appvm-display/Image: $(IMAGE)
	mkdir -p $$(dirname $@)
	cp $(IMAGE) $$(dirname $@)/Image

# tar2ext4 will leave half a filesystem behind if it's interrupted
# half way through.
build/host/data/appvm-display/rootfs.ext4: build/rootfs.tar
	mkdir -p $$(dirname $@)
	tar2ext4 -i build/rootfs.tar -o $@.tmp
	dd if=/dev/zero of=$@.tmp bs=1MiB count=500 conv=notrunc oflag=append
	resize2fs $@.tmp
	tune2fs -O ^read-only $@.tmp
	mv $@.tmp $@

VM_FILES = \
	etc/fstab \
	etc/init \
	etc/login \
	etc/mdev.conf \
	etc/mdev/block/add \
	etc/mdev/listen \
	etc/mdev/net/add \
	etc/mdev/wait \
	etc/passwd \
	etc/resolv.conf \
	etc/s6-linux-init/run-image/service/getty-tty1/run \
	etc/s6-linux-init/run-image/service/getty-tty2/run \
	etc/s6-linux-init/run-image/service/getty-tty3/run \
	etc/s6-linux-init/run-image/service/getty-tty4/run \
	etc/s6-linux-init/run-image/service/getty-ttyS0/run \
	etc/s6-linux-init/run-image/service/getty-ttyLP0/run \
	etc/s6-linux-init/scripts/rc.init \
	etc/xdg/weston/autolaunch \
	etc/xdg/weston/weston.ini \

	
VM_DIRS = dev run proc sys \
	etc/s6-linux-init/env \
	etc/s6-linux-init/run-image/service

# These are separate because they need to be included, but putting
# them as make dependencies would confuse make.
VM_LINKS = bin etc/ssl/certs/ca-certificates.crt

VM_BUILD_FILES = build/etc/s6-rc
VM_MOUNTPOINTS = dev run proc sys

build/empty:
	mkdir -p $@

build/rootfs.tar: build/empty $(PACKAGES_TAR) $(VM_FILES) $(VM_BUILD_FILES)
	cp --no-preserve=mode -f $(PACKAGES_TAR) $@
	tar $(TARFLAGS) --append -f $@ $(VM_FILES) $(VM_LINKS)
	echo $(VM_BUILD_FILES) | cut -d/ -f2 | \
	    tar $(TARFLAGS) --append -f $@ -C build -T -
	for m in $(VM_DIRS); do \
	    tar $(TARFLAGS) --append -hf $@ --xform="s,.*,$$m," build/empty ; \
	done

VM_S6_RC_FILES = \
	etc/s6-rc/card0/type \
	etc/s6-rc/card0/up \
	etc/s6-rc/ext-rc-init/dependencies \
	etc/s6-rc/ext-rc-init/type \
	etc/s6-rc/ext-rc-init/up \
	etc/s6-rc/ext-rc/contents \
	etc/s6-rc/ext-rc/type \
	etc/s6-rc/ext/type \
	etc/s6-rc/ext/up \
	etc/s6-rc/display/run \
	etc/s6-rc/display/type \
	etc/s6-rc/mdevd-coldplug/dependencies \
	etc/s6-rc/mdevd-coldplug/type \
	etc/s6-rc/mdevd-coldplug/up \
	etc/s6-rc/mdevd/notification-fd \
	etc/s6-rc/mdevd/run \
	etc/s6-rc/mdevd/type \
	etc/s6-rc/ok-all/contents \
	etc/s6-rc/ok-all/type \
	etc/s6-rc/static-nodes/type \
	etc/s6-rc/static-nodes/up \
	etc/s6-rc/weston/dependencies \
	etc/s6-rc/weston/notification-fd \
	etc/s6-rc/weston/type \
	etc/s6-rc/weston/run

build/etc/s6-rc: $(VM_S6_RC_FILES)
	mkdir -p $$(dirname $@)
	rm -rf $@

	dir=$$(mktemp -d) && \
	    tar -c $(VM_S6_RC_FILES) | tar -C $$dir -x --strip-components 2 && \
	    s6-rc-compile $@ $$dir; \
	    exit=$$?; rm -r $$dir; exit $$exit

run-qemu: build/host/data/appvm-display/rootfs.ext4
	echo To run display VM with QEMU
	echo vfio-platform > /sys/bus/platform/devices/56000000.bus/driver_override
	echo 56000000.bus > /sys/bus/platform/drivers_probe
	echo vfio-platform  > /sys/bus/platform/devices/5d1d0000.mailbox/driver_override
	echo 5d1d0000.mailbox > /sys/bus/platform/drivers_probe
	echo vfio-platform > /sys/bus/platform/devices/53100000.gpu/driver_override
	echo 53100000.gpu > /sys/bus/platform/drivers_probe
	echo vfio-platform > /sys/bus/platform/devices/d0000000.vm_cma_p/driver_override
	echo d0000000.vm_cma_p > /sys/bus/platform/drivers_probe
	echo
	echo
	ls -lah /sys/bus/platform/drivers/vfio-platform/
	find /sys/kernel/iommu_groups/ -type l
	qemu-system-aarch64 \
		-M virt,gic-version=host -enable-kvm \
		-cpu host \
		-m 1G \
		-kernel /ext/svc/data/appvm-display/Image \
		-drive file=/ext/svc/data/appvm-display/rootfs.ext4,if=virtio,format=raw,readonly=on \
		-dtb /ext/svc/data/appvm-display/imx8qm-mek-hdmi-vm.dtb \
		-nographic -vga none \
		-append "loglevel=7 rootwait root=/dev/vda console=ttyS0 galcore.showArgs=1" \
		-device qemu-xhci,id=usb                                     \
		-device usb-host,bus=usb.0,vendorid=0x1357,productid=0x1000 \
		-device vfio-platform,host=d0000000.vm_cma_p \
		-device vfio-platform,host=56000000.bus \
		-device vfio-platform,host=5d1d0000.mailbox \
		-device vfio-platform,host=53100000.gpu \
		-netdev user,id=net0 \
		-device virtio-net,netdev=net0,mac=0A:B3:EC:00:00:00 \
		-chardev vc,id=virtiocon0 \
		-device virtio-serial-pci \
		-device virtconsole,chardev=virtiocon0 
.PHONY: run-qemu

run-cloud-hypervisor: build/host/data/appvm-display/rootfs.ext4
	echo To run display VM with cloudhypervisor
	$(CLOUD_HYPERVISOR) \
	    --api-socket path=vmm.sock \
	    --memory size=128M \
	    --disk path=build/host/data/appvm-display/rootfs.ext4,readonly=on \
	    --net tap=tap0,mac=0A:B3:EC:00:00:00 \
	    --kernel $(KERNEL) \
	    --cmdline "console=ttyS0 root=/dev/vda" \
	    --console tty \
	    --serial pty
.PHONY: run-cloud-hypervisor

run: run-$(VMM)
	echo To run display VM
.PHONY: run

clean:
	rm -rf build
.PHONY: clean
