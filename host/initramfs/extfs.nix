# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs, runCommand, tar2ext4, e2fsprogs}:

let
  appvm-display = import ../../vm/app/display {
    inherit pkgs;
    # inherit (foot) terminfo;
  };
in

runCommand "ext.ext4" {
  nativeBuildInputs = [ tar2ext4 e2fsprogs];
} ''
  mkdir svc

  tar -C ${appvm-display} -c data | tar -C svc -x
  chmod +w svc/data

  tar -cf ext.tar svc
  tar2ext4 -i ext.tar -o $out
	dd if=/dev/zero of=$out bs=1MiB count=100 conv=notrunc oflag=append
	resize2fs $out
	tune2fs -O ^read-only $out
''
