# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {}
, terminfo ? pkgs.foot.terminfo
}:

pkgs.pkgsStatic.callPackage (

{ lib, stdenvNoCC, runCommand, writeReferencesToFile, buildPackages
, s6-rc, tar2ext4
, busybox, cacert, execline, kmod, mdevd, s6, s6-linux-init, xorg
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep hasSuffix;

  pkgsGui = pkgs.pkgsMusl.extend (final: super: {
    systemd = final.libudev-zero;
  });

  foot = pkgsGui.foot.override { allowPgo = false; };

  packages = [
    execline kmod mdevd s6 s6-linux-init s6-rc

    (busybox.override {
      extraConfig = ''
        CONFIG_DEPMOD n
        CONFIG_INSMOD n
        CONFIG_LSMOD n
        CONFIG_MODINFO n
        CONFIG_MODPROBE n
        CONFIG_RMMOD n
      '';
    })
  ] ++ (with pkgsGui; [ foot westonLite ]);

  packagesSysroot = runCommand "packages-sysroot" {
    inherit packages;
    passAsFile = [ "packages" ];
    nativeBuildInputs = [ xorg.lndir ];
  } ''
    mkdir -p $out/usr/bin $out/usr/share
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/usr/bin

    for pkg in ${lib.escapeShellArgs [ pkgsGui.mesa.drivers pkgsGui.dejavu_fonts ]}; do
        lndir -silent "$pkg" "$out/usr"
    done

    ln -s ${kernel}/lib "$out"
    ln -s ${terminfo}/share/terminfo $out/usr/share
    ln -s ${cacert}/etc/ssl $out/usr/share
  '';

  packagesTar = runCommand "packages.tar" {} ''
    cd ${packagesSysroot}
    tar -cf $out --verbatim-files-from \
        -T ${writeReferencesToFile packagesSysroot} .
  '';

  kernel = pkgs.linux_imx8.override {
    structuredExtraConfig = with lib.kernel; {
      EFI_STUB=yes;
      EFI=yes;
      VIRTIO = yes;
      VIRTIO_PCI = yes;
      VIRTIO_BLK = yes;
      VIRTIO_CONSOLE = yes;
      EXT4_FS = yes;
      DRM_BOCHS = yes;
      DRM = yes;
      AGP = yes;
    };
  };
in

stdenvNoCC.mkDerivation {
  name = "spectrum-appvm-display";

  src = cleanSourceWith {
    filter = name: _type:
      name != "${toString ./.}/build" &&
      !(hasSuffix ".nix" name);
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ s6-rc tar2ext4 ];

  PACKAGES_TAR = packagesTar;
  VMLINUX = "${kernel.dev}/vmlinux";
  IMAGE = "${kernel}/Image";

  installPhase = ''
    mv build/svc $out
  '';

  enableParallelBuilding = true;

  passthru = { inherit kernel; };

  meta = with lib; {
    license = licenses.eupl12;
    platforms = platforms.linux;
  };
}
) {}
