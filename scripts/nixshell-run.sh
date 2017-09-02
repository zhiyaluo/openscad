# This starts up a nix-shell with a build environment that includes
# dependencies necessary to build OpenSCAD. The Nix system must be
# installed for this to work. For more info see http://nixos.org

# To add a package to the list below:
# -To find a package name, run nix-env -qaP. For example to find qscintilla:
#  nix-env -qaP | grep scintilla
# -The 'nix package' will be on the left, the package details on the right.

echo Nix shell starting, please wait...

if [ $IN_NIX_SHELL ]; then
  echo already running inside nix-shell, please exit before running
  echo this script.
  exit
fi

if [ ! -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  echo i cant find ~/.nix-profile/etc/profile.d/nix.sh
  echo please install the nix package manager, see http://nixos.org
  exit
fi

source ~/.nix-profile/etc/profile.d/nix.sh

# prevent nix-shell from refusing to run because of existing __nix_qt__
if [ -d ./__nix_qt5__ ]; then
  rm -rf ./__nix_qt5__
fi

thisscript=$0
scriptdir=`dirname $0`
glsetup=$scriptdir/nix-setup-gl-libs.sh
DRI_DIR=$PWD/__oscd_nix_gl__

# auto-installs listed packages in nix store
nix-shell -p pkgconfig gcc gnumake \
   opencsg cgal gmp mpfr eigen \
   boost flex bison gettext \
   glib libxml2 libzip harfbuzz freetype fontconfig \
   glew xorg.libX11 xorg_sys_opengl \
   qt5.full qt5.qtbase libsForQt5.qscintilla \
   llvm \
   --command "$glsetup $DRI_DIR;export LIBGL_DRIVERS_DIR=$DRI_DIR;return"
#   qt48Full qscintilla

# tested qmake build on
# ubuntu 16.04  amd64 qemu
# ubuntu 14.04  amd64 qemu
# ubuntu 12.04  amd64 qemu
# fedora 24     amd64 qemu

