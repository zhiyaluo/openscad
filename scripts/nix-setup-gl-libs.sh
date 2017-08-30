# This script enables use of OpenGL(TM) drivers when OpenSCAD is built
# under the Nix packaging system.
#
# As of 2017 Nix did not include simple GL setup, so this script
# is a workaround.
#
# This works by creating a subdirectory under the present working directory,
# named __oscd_nix_gl__, copies the system DRI driver files to this directory,
# edits their rpath, and uses LIBGL_DRIVERS_DIR to direct Nix's libGL.so
# to load these drivers.
#
# The basic operation is as follows:
# Nix has it's own version of Mesa libGL.so. Programs that use GL will
# cause the dynamic-linker to load nix's libGL.so, which will in turn figure
# out which video card is being used, then find a driver file for it,
# and load it using dlopen() instead of the dynamic linker.
#
# These driver files are Direct Rendering Interface, or DRI, files,
# On a non-nix system they are usually under some /lib directory 
# with a 'dri' name, for example on ubuntu linux 16 they are here:
#
# don@serebryanya:~/src/openscad/binnix$ ls /usr/lib/x86_64-linux-gnu/dri/
# dummy_drv_video.so  nouveau_dri.so        r600_dri.so       vdpau_drv_video.so
# i915_dri.so         nouveau_vieux_dri.so  radeon_dri.so     virtio_gpu_dri.so
# i965_dri.so         nvidia_drv_video.so   radeonsi_dri.so   vmwgfx_dri.so
# i965_drv_video.so   r200_dri.so           s3g_drv_video.so
# kms_swrast_dri.so   r300_dri.so           swrast_dri.so
#
# However, Nix's libGL.so is specially built to search for these dri files under
# /run/opengl-driver/lib/dri . There are ways to override this, for example
# some people use LD_LIBRARY_PATH, but the problem with that is it overrides
# all libraries. Mesa's LibGL however has a special feature, it reads the
# environment variable LIBGL_DRIVERS_DIR and will use this path to look
# for the DRI drivers.
#
# There is a catch. Those dri.so files in turn depend on other non-nix
# system libraries as well. For example lets look at i965_dri.so on Ubuntu16
#
# don@serebryanya:~/src/openscad/binnix$ ldd /usr/lib/x86_64-linux-gnu/dri/i965_dri.so 
#  linux-vdso.so.1 =>  (0x00007fff20071000)
#  libgcrypt.so.20 => /lib/x86_64-linux-gnu/libgcrypt.so.20 (0x00007fb55410c000)
#  libdrm_intel.so.1 => /usr/lib/x86_64-linux-gnu/libdrm_intel.so.1 (0x00007fb553ee9000)
#  libdrm_nouveau.so.2 => /usr/lib/x86_64-linux-gnu/libdrm_nouveau.so.2 (0x00007fb553ce0000)
#  libdrm_radeon.so.1 => /usr/lib/x86_64-linux-gnu/libdrm_radeon.so.1 (0x00007fb553ad4000)
#  libdrm.so.2 => /usr/lib/x86_64-linux-gnu/libdrm.so.2 (0x00007fb5538c3000)
#  libexpat.so.1 => /lib/x86_64-linux-gnu/libexpat.so.1 (0x00007fb553699000)
#  libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007fb55347c000)
#  libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007fb553278000)
#  libstdc++.so.6 => /usr/lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007fb552ef5000)
#  libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007fb552bec000)
#  libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fb552822000)
#  libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007fb55260b000)
#  libgpg-error.so.0 => /lib/x86_64-linux-gnu/libgpg-error.so.0 (0x00007fb5523f7000)
#  libpciaccess.so.0 => /usr/lib/x86_64-linux-gnu/libpciaccess.so.0 (0x00007fb5521ed000)
#  /lib64/ld-linux-x86-64.so.2 (0x00005566de529000)
#  libz.so.1 => /lib/x86_64-linux-gnu/libz.so.1 (0x00007fb551fd2000)
#
# Now we could use Nix supplied .so files instead of these system .so files,
# but there is no guarantee they will be compatible. How to deal with this?
#
# The answer is within the linking system and binary executable
# format used on linux, called ELF (Executable Linkable Format). The key
# is a feature of ELF called rpath.
#
# (to be continued)
#
# There is another huge catch. We don't want to copy all the driver files.
# The less dependencies, the better. What do we do? We find out which
# is being used, and we copy only what we need.
#
# See Also
# https://github.com/NixOS/nixpkgs/issues/9415#issuecomment-170661702
# https://anonscm.debian.org/git/pkg-xorg/lib/mesa.git/tree/docs/libGL.txt
# https://github.com/deepfire/nix-install-vendor-gl
# https://nixos.org/patchelf.html
# https://en.wikipedia.org/wiki/Direct_Rendering_Manager
# rpath, mmap, strace, shared libraries, linkers, loaders
# https://unix.stackexchange.com/questions/97676/how-to-find-the-driver-module-associated-with-a-device-on-linux
# https://stackoverflow.com/questions/5103443/how-to-check-what-shared-libraries-are-loaded-at-run-time-for-a-given-process
# sudo cat /proc/$Xserverprocessid/maps | grep dri
# sudo lsof -p $Xserverprocessid | grep dri



if [ ! $IN_NIX_SHELL ]; then
  echo sorry, this needs to be run from within nix-shell environment. exiting.
  exit
fi
if [ ! $1 ]; then
  echo this script is usually run from openscad/scripts/nixshell-run.sh
  echo if you are working on the build system, you can try running this
  echo with first arg being dir containing modified DRI libs
  exit
fi
if [ ! "`command -v glxinfo`" ]; then
  echo sorry, this script, $0, needs glxinfo in your PATH. exiting.
  exit
fi
glxinfo > /dev/null
if [ ! $? -eq 0 ]; then
  echo sorry, your glxinfo appears to be inoperable. please get
  echo a working glxinfo. perhaps you have not an X11 server started?
  exit
fi
if [ ! "`glxinfo | grep nix.store`" ]; then
  echo sorry, this script, $0, needs system glxinfo in your PATH.
  echo it appears your glxinfo is from Nix. please use a clean shell.
  exit
fi
if [ ! "`command -v dirname`" ]; then
  echo sorry, this script, $*, needs dirname. exiting.
  exit
fi
if [ ! "`command -v ldd`" ]; then
  echo sorry, this script, $*, needs ldd. exiting.
  exit
fi

find_system_libGL_DIR() {
  glxinfobin=`which glxinfo`
  libglfile=`ldd $glxinfobin | grep libGL.so | awk ' { print $3 } '`
  libGL_DIR=`dirname $libglfile`
  echo $libGL_DIR
}

find_DRI_DIR() {
  sysGL_DIR=$(find_system_libGL_DIR)
  sysGL_DIR_parent=$sysGL_DIR/..
  i965_drifile=`find $sysGL_DIR_parent | grep i965_dri.so | head -1`
  i965dir=`dirname $i965_drifile`
  i965_canonical_dir=`readlink -f $i965dir`
  echo $i965_canonical_dir
}

find_driver_used_by_glxinfo() {
  sttxt=`strace -f $glxinfobin 2>&1 | grep open`
  driline=`echo $sttxt | grep dri | grep -v open..dev | grep -v NOENT`
  drifilepath=`echo $driline | sed s/\\"/\\ /g - | awk ' { print $2 } '`
  echo $drifilepath
}

find_swrast_driverdir() {
  sysGL_DIR=$(find_system_libGL_DIR)
  sysGL_DIR_parent=$sysGL_DIR/..
  swrast_drifile=`find $sysGL_DIR_parent | grep swrast_dri.so | head -1`
  swrastdir=`dirname $swrast_drifile`
  swrast_canonical_dir=`readlink -f $swrastdir`
  echo $swrast_canonical_dir
}

find_regular_file_in_dir() {
  filepattern_wanted=$1
  dir_name=$2
  result=''
  for filename in $dir_name/*; do
    if [ -f $filename ]; then
      if [ "`echo $filename | grep $filepattern_wanted`" ]; then
        result=$filename
      fi
    fi
  done
  echo $result
}

find_nixstore_dir_for() {
  filepattern=$1
  filename=`find /nix/store | grep $filepattern | tail -1`
  filename_parentdir=`dirname $filename`
  echo $filename_parentdir
}

find_shlibs() {
  find_shlib=$1
  shlibs=`ldd $find_shlib | grep "=>" | grep -v "vdso.so" | awk ' { print $1 } ' `
  echo $shlibs
}

install_under_specialdir() {
  original_path=$1
  target_dir=$2
  target_path=$target_dir
  #`basename $original_path`
  if [ ! -d $target_dir ]; then
    mkdir -p $target_dir
  fi
  cp -v $original_path $target_path
  patchelf --set-rpath $OSCD_NIXGL_DIR $target_path
}

set -x
set -e

SYSTEM_MESA_LIBGL_DIR=$(find_system_libGL_DIR)
SYSTEM_DRI_DIR=$(find_DRI_DIR)
SYSTEM_SWRAST_DRIVERDIR=$(find_swrast_driverdir)
#OSCD_NIXGL_DIR=/run/opengl-driver/lib/dri
#OSCD_NIXGL_DIR=$PWD/__oscd_nix_gl__/dri
OSCD_NIXGL_DIR=$1

SYS_LIBGL_SO_FILE=$(find_regular_file_in_dir libGL.so $SYSTEM_MESA_LIBGL_DIR)
SYS_DRI_SO_FILE=$(find_driver_used_by_glxinfo)
#echo install_under_specialdir $SYS_DRI_SO_FILE $OSCD_NIXGL_DIR
echo driver_dep_libs=$(find_shlibs $SYS_DRI_SO_FILE)
for filenm in $driver_dep_libs ; do
  echo $filenm
done

set +x
set +e


