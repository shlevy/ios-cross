{ pkgs ? import <nixpkgs> {} }: 
let
  inherit (pkgs) runCommand lib darwin;

  llvmPackages = pkgs.llvmPackages_38;

  inherit (llvmPackages) llvm clang;

  inherit (lib) concatStringsSep;

  inherit (darwin) binutils;

  # target-prefixed wrappers inspired by https://github.com/angerman/ghc-ios-scripts
  prefixed-progs = runCommand "prefixed-ios-toolchain" {} ''
    mkdir -p $out/bin
    ${concatStringsSep "\n" (map ({ prefix, arch, simulator ? false }: let
      sdkType = if simulator then "Simulator" else "OS";
      sdk = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhone${sdkType}.platform/Developer/SDKs/iPhone${sdkType}9.3.sdk";
      wrapper = import (pkgs.path + "/pkgs/build-support/cc-wrapper") {
        inherit (pkgs) stdenv coreutils gnugrep;
        nativeTools = false;
        nativeLibc = false;
        inherit binutils;
	libc = runCommand "empty-libc" {} "mkdir -p $out/{lib,include}";
        cc = clang;
        extraBuildCommands = ''
          # ugh
          tr '\n' ' ' < $out/nix-support/cc-cflags > cc-cflags.tmp
          mv cc-cflags.tmp $out/nix-support/cc-cflags
          echo "-target ${prefix} -arch ${arch} -idirafter ${sdk}/usr/include ${if simulator then "-mios-simulator-version-min=7.0" else "-miphoneos-version-min=7.0"}" >> $out/nix-support/cc-cflags

          # Purposefully overwrite libc-ldflags-before, cctools ld doesn't know dynamic-linker and cc-wrapper doesn't do cross-compilation well enough to adjust
          echo "-arch ${arch} -L${sdk}/usr/lib -L${sdk}/usr/lib/system" > $out/nix-support/libc-ldflags-before
        '';
      };
    in ''
      ln -sv ${wrapper}/bin/clang $out/bin/${prefix}-cc
      ln -sv ${wrapper}/bin/ld $out/bin/${prefix}-ld
      for prog in ar nm ranlib; do
        ln -s ${binutils}/bin/$prog $out/bin/${prefix}-$prog
      done'') [
        { prefix = "aarch64-apple-darwin14"; arch = "aarch64"; }
        { prefix = "arm-apple-darwin10"; arch = "armv7"; }
        { prefix = "i386-apple-darwin11"; arch = "i386"; simulator = true; }
        { prefix = "x86_64-apple-darwin14"; arch = "x86_64"; simulator = true; }
      ])}
      mkdir -p $out/nix-support
      echo ${llvm} > $out/nix-support/propagated-native-build-inputs
      fixupPhase
  '';
in prefixed-progs
