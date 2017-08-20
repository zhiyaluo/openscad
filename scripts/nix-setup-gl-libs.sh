# This script enables use of OpenGL(TM) drivers when OpenSCAD is built
# under the Nix packaging system.
#
# As of 2017 Nix did not include working GL system, so it is necessary
# to follow https://github.com/NixOS/nixpkgs/issues/9415#issuecomment-170661702
# as a workaround.
#

if [ ! "`command -v rsync`" ]; then
  echo sorry, this script, $*, needs rsync. exiting.
  exit
fi
if [ ! "`command -v glxinfo`" ]; then
  echo sorry, this script, $*, needs glxinfo. exiting.
  exit
fi
if [ ! "`command -v dirname`" ]; then
  echo sorry, this script, $*, needs glxinfo. exiting.
  exit
fi
if [ ! "`command -v patchelf`" ]; then
  echo sorry, this script requires patchelf from Nix pkgs
  exit
fi
if [ ! "`which patchelf | grep nix`" ]; then
  echo sorry, this script requires Nixs own patchelf, not system patchelf
  exit
fi

find_system_libgldir() {
  glxinfobin=`which glxinfo`
  libglfile=`ldd $glxinfobin | grep libGL.so | awk ' { print $3 } '`
  libgldir=`dirname $libglfile`
  echo $libgldir
}

find_i965_driverdir() {
  sysgldir=$(find_system_libgldir)
  sysgldir_parent=$sysgldir/..
  i965_drifile=`find $sysgldir_parent | grep i965_dri.so | head -1`
  i965dir=`dirname $i965_drifile`
  i965_canonical_dir=`readlink -f $i965dir`
  echo $i965_canonical_dir
}

build_rpaths() {
  result=/lib
  result=$result:/usr/lib
  result=$result:/lib/x86_64-linux-gnu
  result=$result:/usr/lib/x86_64-linux-gnu
  echo $result
}

find_regular_file() {
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

set -x
set -e

OSNL_BASEDIR=$HOME/openscad_deps/nix_libs
OSNL_MESADIR=$OSNL_BASEDIR/mesa
OSNL_DRIDIR=$OSNL_BASEDIR/dri
chmod -R ugo+w $OSNL_BASEDIR
rm -rf $OSNL_BASEDIR
mkdir -p $OSNL_BASEDIR
mkdir -p $OSNL_MESADIR
mkdir -p $OSNL_DRIDIR
OSNL_RPATHS=$(build_rpaths)
SYSTEM_MESA_LIBGLDIR=$(find_system_libgldir)
NIXSTORE_LIBPCIACCESS_DIR=$(find_nixstore_dir_for libpciaccess.so)
SYSTEM_I965_DRIVERDIR=$(find_i965_driverdir)

rsync -aszvi $SYSTEM_MESA_LIBGLDIR/libGL.* $OSNL_MESADIR
OSNL_LIBGL_SO_FILE=$(find_regular_file libGL.so $OSNL_MESADIR)
patchelf --set-rpath $OSNL_RPATHS $OSNL_LIBGL_SO_FILE
# this ln is necessary because system libGL.so looks under "./dri" rather than
# wherever LD_LIBRARY_PATH is pointing to.
ln -s $OSNL_DRIDIR $OSNL_MESADIR/dri

rsync -aszvi $SYSTEM_I965_DRIVERDIR/i965* $OSNL_DRIDIR
OSNL_I965_DRI_SO_FILE=$(find_regular_file i965_dri.so $OSNL_DRIDIR)
patchelf --set-rpath $OSNL_RPATHS $OSNL_I965_DRI_SO_FILE

rsync -aszvi $NIXSTORE_LIBPCIACCESS_DIR/* $OSNL_MESADIR

set +x
set +e

find $OSNL_BASEDIR
which patchelf

echo use LD_LIBRARY_PATH=$OSNL_MESADIR:$OSNL_DRIDIR ./openscad

