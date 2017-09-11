# This starts up a Nix-shell with a build environment that includes
# dependencies necessary to build OpenSCAD. The Nix package system must be
# installed for this to work. See ../README.md and http://nixos.org/nix

# This also includes a custom kludge to workaround Nix not including Mesa's DRI
# drivers for OpenGL(TM) graphics. See nix-setup-gl-libs.sh for details

# To add a specific dependency package to the list below:
# -Start a nix environment ( source $HOME/.nix-profile/etc/profile.d/nix.sh )
# -Find the package name with nix-env + grep, for example to find qscintilla:
#  nix-env -qaP | grep scintilla  # this may take a few minutes
# -The nix package name will be on the left, the package details on the right.
# nixpkgs.libsForQt56.qscintilla                     qscintilla-qt5-2.9.4
# nixpkgs.libsForQt5.qscintilla                      qscintilla-qt5-2.9.4

if [ $SUPERDEBUG_NGL ]; then
  set -x
fi

if [ $IN_NIX_SHELL ]; then
  echo already running inside Nix-shell, please exit before running this script
  exit
fi

if [ $LIBGL_DRIVERS_DIR ]; then
  echo LIBGL_DRIVERS_DIR environment variable already set. please run this
  echo script only from a clean shell.
  exit
fi

echo Nix shell for OpenSCAD starting, please wait...

if [ ! "`command -v ldd`" ]; then
  echo sorry, this script requires the ldd command to be installed
fi

if [ ! -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  echo i cant find ~/.nix-profile/etc/profile.d/nix.sh
  echo please install the nix package manager, see http://nixos.org
  exit
fi

source ~/.nix-profile/etc/profile.d/nix.sh

# prevent nix-shell from refusing to run because of existing __nix_qt__
# which nix itself creates every time nix shell is run
if [ -d ./__nix_qt5__ ]; then
  rm -rf ./__nix_qt5__
fi

thisscript=$0
scriptdir=`dirname $0`
glsetup=$scriptdir/nix-setup-gl-libs.sh
DRI_DIR=$PWD/__nix_kludge_gl__
LDD_EXEC=`which ldd`
export DRI_DIR
export LDD_EXEC

# this will auto-install nix packages, several gigabytes worth!
nix-shell -p pkgconfig gcc gnumake \
   opencsg cgal gmp mpfr eigen \
   boost flex bison gettext \
   glib libxml2 libzip harfbuzz freetype fontconfig \
   glew xorg.libX11 xorg_sys_opengl mesa \
   qt5.full qt5.qtbase libsForQt5.qscintilla \
   llvm patchelf strace \
   --command "$glsetup $DRI_DIR $LDD_EXEC; export LIBGL_DRIVERS_DIR=$DRI_DIR; return"

# $glsetup = the script to set up special GL libraries, see nix-setup-gl-libs.sh
# DRI_DIR = location where we will keep our custom patchelf-rpath GL DRI drivers
# LDD_EXEC = system's ldd (/usr/bin/ldd), to find the system DRI driver deps
# LIBGL_DRIVERS_DIR = env. var. for Nix's libGL.so, used to dlopen() DRI drivers
#
# Note that LIBGL_DRIVERS_DIR needs to be set after calling $glsetup,
# because it needs to call glxinfo from the system context not Nix context

if [ $SUPERDEBUG_NGL ]; then
  set +x
fi
