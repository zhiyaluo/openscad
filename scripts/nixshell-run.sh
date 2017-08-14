# This starts up a nix-shell with a build environment that includes
# dependencies necessary to build OpenSCAD. The Nix system must be
# installed for this to work. For more info see http://nixos.org

# Addig packages:
# to find a package name, run nix-env -qaP. For example to find qscintilla:
# nix-env -qaP | grep scintilla
# the 'nix package' will be on the left, the package details on the right.

nix-shell -p pkgconfig gcc gnumake \
   opencsg cgal gmp mpfr eigen \
   boost flex bison gettext \
   glib libxml2 libzip harfbuzz freetype fontconfig \
   glew xorg.libX11 xorg_sys_opengl \
   qt5.full qt5.qtbase libsForQt5.qscintilla
#   qt48Full qscintilla


