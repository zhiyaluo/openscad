# This script enables use of OpenGL(TM) drivers when OpenSCAD is built
# under the Nix packaging system.
#
# As of 2017 Nix did not include working GL system, so it is necessary to
# use special scripts like this as a workaround. This work was pioneered
# on Nix's github issue here:
# https://github.com/NixOS/nixpkgs/issues/9415#issuecomment-170661702
#
# The basic theory is like this. Nix has it's own libGL.so, but it doesnt
# have any specific DRI GL drivers, such as the i965_dri.so file for
# Intel(TM) video chips. Instead nix's code will search a specific path,
# /run/opengl-driver/lib/dri when it tries to load those drivers.
# Therefore, we must create symlink of the drivers under that path, linking
# to their true location in the filesystem. As well as everything
# they depend on, like libdrm_intel.so and whatnot.
#
# The other trick is we have to use
# LD_LIBRARY_PATH=/run/opengl-driver/lib/dri when running openscad. This
# allows i965_dri.so various routines to load their own dependencies
# properly. However this gets a bit tricky since it could cause
# libraries in that path to interfere with Nix libraries. So we can't
# allow i965_dri.so to use the system's libc.so.5. We only copy certain
# dependencies over to /run/opengl-driver/lib/dri
# and hope that ones like libc and libm are stable enough that the
# the difference between them and Nix's will not matter too much.
#
# See Also
# https://anonscm.debian.org/git/pkg-xorg/lib/mesa.git/tree/docs/libGL.txt
# https://github.com/deepfire/nix-install-vendor-gl
# https://nixos.org/patchelf.html
# https://en.wikipedia.org/wiki/Direct_Rendering_Manager
# rpath, mmap, strace, shared libraries, linkers, loaders

if [ ! $IN_NIX_SHELL ]; then
  echo sorry, this needs to be run from within nix-shell environment. exiting.
  exit
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

find_system_libgldir() {
  glxinfobin=`which glxinfo`
  libglfile=`ldd $glxinfobin | grep libGL.so | awk ' { print $3 } '`
  libgldir=`dirname $libglfile`
  echo $libgldir
}

find_DRIDIR() {
  sysgldir=$(find_system_libgldir)
  sysgldir_parent=$sysgldir/..
  i965_drifile=`find $sysgldir_parent | grep i965_dri.so | head -1`
  i965dir=`dirname $i965_drifile`
  i965_canonical_dir=`readlink -f $i965dir`
  echo $i965_canonical_dir
}

find_swrast_driverdir() {
  sysgldir=$(find_system_libgldir)
  sysgldir_parent=$sysgldir/..
  swrast_drifile=`find $sysgldir_parent | grep swrast_dri.so | head -1`
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
  shlibs=`ldd $find_shlib | grep "=>" | grep -v "vdso.so" | grep -v "nix.store" | awk ' { print $1 } ' `
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
    sudo cp -av $original $target
    sudo chown $USER.$USER $target
    patchelf --set-rpath /tmp/nog/lib/dri $target
  else
    echo $target already exist, not linking
  fi
}

set -x
set -e

SYSTEM_MESA_LIBGLDIR=$(find_system_libgldir)
SYSTEM_DRIDIR=$(find_DRIDIR)
SYSTEM_SWRAST_DRIVERDIR=$(find_swrast_driverdir)
#RUN_OGL_LIBGLDIR=/run/opengl-driver/lib
#RUN_OGL_DRIDIR=/run/opengl-driver/lib/dri
RUN_OGL_LIBGLDIR=/tmp/nog/lib
RUN_OGL_DRIDIR=/tmp/nog/lib/dri

#sudo rm -f /run/opengl-driver/lib/dri/*
#sudo rm -f /run/opengl-driver/lib/*.so

SYS_LIBGL_SO_FILE=$(find_regular_file_in_dir libGL.so $SYSTEM_MESA_LIBGLDIR)
#sudo ln -sf $SYS_LIBGL_SO_FILE $RUN_OGL_LIBGLDIR/libGL.so

SYS_I965_SO_FILE=$(find_regular_file_in_dir i965_dri.so $SYSTEM_DRIDIR)
symlink_if_not_there $SYS_I965_SO_FILE $RUN_OGL_DRIDIR/i965_dri.so
i965_dep_libs=$(find_shlibs $SYS_I965_SO_FILE)
sys_libdir1=`readlink -f $SYSTEM_MESA_LIBGLDIR/..`
sys_libdir2=`echo $sys_libdir1 | sed s/\\\/usr//g`
# pciaccess comes from libdrm_intel.so
for filenm in $i965_dep_libs libpciaccess.so.0 ; do
  fullnm1=$sys_libdir1/$filenm
  fullnm2=$sys_libdir2/$filenm
  for fullnm in $fullnm1 $fullnm2; do
    if [ -e $fullnm ]; then
      fullnm_true=`readlink -f $fullnm `
      basenm_true=`basename $fullnm_true`
      symlink_if_not_there $fullnm_true $RUN_OGL_DRIDIR/$basenm_true
      symlink_if_not_there $fullnm $RUN_OGL_DRIDIR/$filenm
    else
      echo skipping $fullnm
    fi
  done
done

set +x
set +e


