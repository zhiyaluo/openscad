# This starts up a Nix-shell with a build environment that includes
# dependencies necessary to build OpenSCAD. The Nix package system must be
# installed for this to work. See ../README.md and http://nixos.org/nix

# To add a package to the list below:
# -Start a nix environment ( source $HOME/.nix-profile/etc/profile.d/nix.sh )
# -To find a package name, run nix-env -qaP. For example to find qscintilla:
#  nix-env -qaP | grep scintilla  # this may take a few minutes
# -The 'nix packages' will be on the left, the package details on the right.
# nixpkgs.libsForQt56.qscintilla                     qscintilla-qt5-2.9.4
# nixpkgs.libsForQt5.qscintilla                      qscintilla-qt5-2.9.4

if [ $IN_NIX_SHELL ]; then
  echo already running inside Nix-shell, please exit before running
  echo this script.
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
DRI_DIR=$PWD/__oscd_nix_gl__
LDD_EXEC=`which ldd`

# this will auto-install nix packages, several gigabytes worth!
nix-shell -p pkgconfig gcc gnumake \
   opencsg cgal gmp mpfr eigen \
   boost flex bison gettext \
   glib libxml2 libzip harfbuzz freetype fontconfig \
   glew xorg.libX11 xorg_sys_opengl mesa mesa_drivers \
   qt5.full qt5.qtbase libsForQt5.qscintilla \
   llvm patchelf \
   --command "$glsetup $DRI_DIR $LDD_EXEC; export LIBGL_DRIVERS_DIR=$DRI_DIR; return"

# $glsetup = the script to set up special GL libraries, see nix-setup-gl-libs.sh
# DRI_DIR = location where we will keep our custom patchelf-rpath GL DRI drivers
# LDD_EXEC = system's ldd, we need this to find the system DRI driver + deps
# LIBGL_DRIVERS_DIR = special environment variable for MESA, points to our DRI drivers
# Note that LIBGL_DRIVERS_DIR needs to be set after calling $glsetup,
# because if you call it before, glsetup's glxinfo cant find system drivers
