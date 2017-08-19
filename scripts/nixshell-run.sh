# This starts up a nix-shell with a build environment that includes
# dependencies necessary to build OpenSCAD. The Nix system must be
# installed for this to work. For more info see http://nixos.org

# Addig packages:
# to find a package name, run nix-env -qaP. For example to find qscintilla:
# nix-env -qaP | grep scintilla
# the 'nix package' will be on the left, the package details on the right.


# enable GL on nix takes a bit of work, not standard
# https://github.com/NixOS/nixpkgs/issues/9415

source ~/.nix-profile/etc/profile.d/nix.sh

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
 result=''
 result=$result:/lib
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

OSNLDIR=$HOME/openscad_deps/nix_libs
OSNL_MESADIR=$OSNLDIR/mesa
OSNL_DRIDIR=$OSNLDIR/dri
rm -rf $OSNLDIR
mkdir -p $OSNLDIR
mkdir -p $OSNL_MESADIR
mkdir -p $OSNL_DRIDIR
OSNL_RPATHS=$(build_rpaths)
SYSTEM_MESA_LIBGLDIR=$(find_system_libgldir)
SYSTEM_I965_DRIVERDIR=$(find_i965_driverdir)
NIXSTORE_LIBPCIACCESS_DIR=$(find_nixstore_dir_for libpciaccess.so)

exit


rsync -aszvi $SYSTEM_MESA_LIBGLDIR/libGL.* $OSNL_MESADIR
OSNL_LIBGL_SO_FILE=$(find_regular_file libGL.so $OSNL_MESADIR)
patchelf --set-rpath $OSNL_RPATHS $OSNL_LIBGL_SO_FILE

rsync -aszvi $SYSTEM_I965_DRIVERDIR/i965* $OSNL_DRIDIR
OSNL_I965_DRI_SO_FILE=$(find_regular_file i965_dri.so $OSNL_DRIDIR)
patchelf --set-rpath $OSNL_RPATHS $OSNL_I965_DRI_SO_FILE

rsync -aszvi $NIXSTORE_LIBPCIACCESS_DIR $OSNL_MESADIR
NIXSTORE_LIBPCIACCESS_SO_FILE=$(find_nixstore_dir libpciaccess.so.0)

exit

set +x
set +e

echo nix shell starting, please wait...
echo and use LD_LIBRARY_PATH=$OSNL_MESADIR:$OSNL_DRIDIR ./openscad

# prevent nix-shell from refusing to run b/c of existing __nix_qt__
if [ -d ./__nix_qt5__ ]; then
  rm -rf ./__nix_qt5__
fi

# auto-installs listed packages in nix store
nix-shell -p pkgconfig gcc gnumake \
   opencsg cgal gmp mpfr eigen \
   boost flex bison gettext \
   glib libxml2 libzip harfbuzz freetype fontconfig \
   glew xorg.libX11 xorg_sys_opengl \
   qt5.full qt5.qtbase libsForQt5.qscintilla \
   patchelf \
   libgcrypt libdrm libgpgerror xorg.libpciaccess
#   qt48Full qscintilla

# tested qmake build on
# ubuntu 16.04  amd64 qemu
# ubuntu 14.04  amd64 qemu
# ubuntu 12.04  amd64 qemu
# fedora 24     amd64 qemu

