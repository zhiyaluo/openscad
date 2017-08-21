# This script enables use of OpenGL(TM) drivers when OpenSCAD is built
# under the Nix packaging system.
#
# As of 2017 Nix did not include working GL system, so it is necessary to
# use special scripts like this as a workaround. This work was pioneered
# on Nix's github issue here:
# https://github.com/NixOS/nixpkgs/issues/9415#issuecomment-170661702
#

if [ ! $IN_NIX_SHELL ]; then
  echo sorry, this needs to be run from within nix-shell environment. exiting.
  exit
fi
if [ ! "`command -v rsync`" ]; then
  echo sorry, this script, $*, needs rsync. exiting.
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
if [ ! "`command -v patchelf`" ]; then
  echo sorry, this script requires patchelf from Nix pkgs
  exit
fi
if [ ! "`which patchelf | grep nix`" ]; then
  echo sorry, this script requires Nixs own patchelf, not system patchelf
  echo please run this script under nix-shell
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
  shlibs=`readelf -d $1 | grep NEED | sed s/'\]'//g | sed s/'\['//g | awk ' { print $5 } '`
  echo $shlibs
}

symlink_if_not_there() {
  original=$1
  target=$2
  if [ ! -e $target ]; then
    sudo ln -sf $original $target
  else
    echo $target already exist, not linking
  fi
}

set -x
set -e

SYSTEM_MESA_LIBGLDIR=$(find_system_libgldir)
SYSTEM_DRIDIR=$(find_DRIDIR)
SYSTEM_SWRAST_DRIVERDIR=$(find_swrast_driverdir)
RUN_OGL_LIBGLDIR=/run/opengl-driver/lib
RUN_OGL_DRIDIR=/run/opengl-driver/lib/dri

#sudo rm -f /run/opengl-driver/lib/dri/*
#sudo rm -f /run/opengl-driver/lib/*.so

SYS_LIBGL_SO_FILE=$(find_regular_file_in_dir libGL.so $SYSTEM_MESA_LIBGLDIR)
#sudo ln -sf $SYS_LIBGL_SO_FILE $RUN_OGL_LIBGLDIR/libGL.so

SYS_I965_SO_FILE=$(find_regular_file_in_dir i965_dri.so $SYSTEM_DRIDIR)
symlink_if_not_there $SYS_I965_SO_FILE $RUN_OGL_DRIDIR/i965_dri.so
i965_dep_libs=$(find_shlibs $SYS_I965_SO_FILE)
sys_libdir1=`readlink -f $SYSTEM_MESA_LIBGLDIR/..`
sys_libdir2=`echo $sys_libdir1 | sed s/\\\/usr//g`
for filenm in $i965_dep_libs libpciaccess.so.0 ; do
  fullnm1=$sys_libdir1/$filenm
  fullnm2=$sys_libdir2/$filenm
  for fullnm in $fullnm1 $fullnm2; do
    if [ "`echo $filenm | egrep \"(libc.so|libm.so|libstdc|libgcc|pthread|libdl)\"`" ]; then
      echo skipping $filenm
    elif [ -e $fullnm ]; then
      symlink_if_not_there $fullnm $RUN_OGL_DRIDIR/$filenm
    fi
  done
done

set +x
set +e

echo run openscad like so:
#echo LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver/lib/dri ./openscad
echo LD_LIBRARY_PATH=/run/opengl-driver/lib/dri ./openscad

