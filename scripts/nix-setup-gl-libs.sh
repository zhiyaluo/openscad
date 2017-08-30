# This script enables use of OpenGL(TM) drivers when OpenSCAD is built
# under the Nix packaging system.
#
# As of 2017 Nix did not include simple GL setup, so this script
# is a workaround.
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
# See Also
# https://github.com/NixOS/nixpkgs/issues/9415#issuecomment-170661702
# https://anonscm.debian.org/git/pkg-xorg/lib/mesa.git/tree/docs/libGL.txt
# https://github.com/deepfire/nix-install-vendor-gl
# https://nixos.org/patchelf.html
# https://en.wikipedia.org/wiki/Direct_Rendering_Manager
# rpath, mmap, strace, shared libraries, linkers, loaders

if [ ! $IN_NIX_SHELL ]; then
  echo sorry, this needs to be run from within nix-shell environment. exiting.
  exit
fi
if [ ! $1 ]; then
  echo this script is usually run from openscad/scripts/nixshell-.
  echo please run with first arg being dir containing modified DRI libs
fi
if [ ! "`command -v glxinfo`" ]; then
  echo sorry, this script, $*, needs glxinfo. exiting.
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

find_swrast_driverdir() {
  sysGL_DIR=$(find_system_libGL_DIR)
  sysGL_DIR_parent=$sysGL_DIR/..
  swrast_drifile=`find $sysGL_DIR_parent | grep swrast_dri.so | head -1`
  swrastdir=`dirname $swrast_drifile`
  swrast_canonical_dir=`readlink -f $swrastdir`
  echo $swrast_canonical_dir
}

build_rpaths() {
  result=$1
  result=$result:/lib
  result=$result:/usr/lib
  result=$result:/lib/x86_64-linux-gnu
  result=$result:/usr/lib/x86_64-linux-gnu
  echo $result
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
  #shlibs=`readelf -d $1 | grep NEED | sed s/'\]'//g | sed s/'\['//g | awk ' { print $5 } '`
  #shlibs=`ldd $find_shlib | grep "=>" | grep -v "vdso.so" | grep -v "nix.store" | awk ' { print $1 } ' `
  shlibs=`ldd $find_shlib | grep "=>" | grep -v "vdso.so" | awk ' { print $1 } ' `
  #shlibs=`readelf -d $1 | grep NEED | sed s/'\]'//g | sed s/'\['//g | awk ' { print $5 } '`
  echo $shlibs
}

symlink_if_not_there() {
  original=$1
  target=$2
  target_dir=`dirname $target`
  if [ ! -d $target_dir ]; then
    mkdir -p $target_dir
  fi
  if [ ! -e $target ]; then
    #sudo ln -sf $original $target
    cp -v $original $target
    #sudo chown $USER.$USER $target
    patchelf --set-rpath $NIXGL_DRI_DIR $target
  else
    echo $target already exist, not linking
  fi
}

set -x
set -e

SYSTEM_MESA_LIBGL_DIR=$(find_system_libGL_DIR)
SYSTEM_DRI_DIR=$(find_DRI_DIR)
SYSTEM_SWRAST_DRIVERDIR=$(find_swrast_driverdir)
#NIXGL_LIBGL_DIR=/run/opengl-driver/lib
#NIXGL_DRI_DIR=/run/opengl-driver/lib/dri
#NIXGL_LIBGL_DIR=$PWD/__nix_gl__
#NIXGL_DRI_DIR=$PWD/__nix_gl__/dri
#NIXGL_LIBGL_DIR=$1/..
NIXGL_DRI_DIR=$1

#sudo rm -f /run/opengl-driver/lib/dri/*
#sudo rm -f /run/opengl-driver/lib/*.so

SYS_LIBGL_SO_FILE=$(find_regular_file_in_dir libGL.so $SYSTEM_MESA_LIBGL_DIR)
#sudo ln -sf $SYS_LIBGL_SO_FILE $NIXGL_LIBGL_DIR/libGL.so

SYS_I965_SO_FILE=$(find_regular_file_in_dir i965_dri.so $SYSTEM_DRI_DIR)
symlink_if_not_there $SYS_I965_SO_FILE $NIXGL_DRI_DIR/i965_dri.so
i965_dep_libs=$(find_shlibs $SYS_I965_SO_FILE)
sys_libdir1=`readlink -f $SYSTEM_MESA_LIBGL_DIR/..`
sys_libdir2=`echo $sys_libdir1 | sed s/\\\/usr//g`
# pciaccess is needed by libdrm_intel.so
for filenm in $i965_dep_libs libpciaccess.so.0 ; do
  fullnm1=$sys_libdir1/$filenm
  fullnm2=$sys_libdir2/$filenm
  for fullnm in $fullnm1 $fullnm2; do
    if [ -e $fullnm ]; then
      fullnm_true=`readlink -f $fullnm `
      basenm_true=`basename $fullnm_true`
      symlink_if_not_there $fullnm_true $NIXGL_DRI_DIR/$basenm_true
      symlink_if_not_there $fullnm $NIXGL_DRI_DIR/$filenm
    else
      echo skipping $fullnm
    fi
  done
done

set +x
set +e


