#
# This script contains functions for building various libraries
# used by OpenSCAD.
# It's supposed to be included from the system specific scripts.
#
# scripts/uni-build-dependencies.sh - generic linux/bsd
# scripts/macosx-build-             - mac osx options
# scripts/mingw-x-build-            - not used, MXE handles all dependencies.

# on some systems the scripts/setenv script can provide 
# better tar and make
if [ ! $TARCMD ]; then
  TARCMD=tar
fi
if [ ! $TARCMD ]; then
  MAKECMD=make
fi

build_freetype()
{
  version="$1"
  extra_config_flags="$2"

  if [ -e "$DEPLOYDIR/include/freetype2" ]; then
    echo "freetype already installed. not building"
    return
  fi

  echo "Building freetype $version..."
  cd "$BASEDIR"/src
  rm -rf "freetype-$version"
  if [ ! -f "freetype-$version.tar.gz" ]; then
    curl --insecure -LO "http://download.savannah.gnu.org/releases/freetype/freetype-$version.tar.gz"
  fi
  gzip -cd "freetype-$version.tar.gz" | $TARCMD xf -
  cd "freetype-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR" $extra_config_flags
  $MAKECMD -j"$NUMCPU"
  $MAKECMD install
}
 
build_libxml2()
{
  version="$1"

  if [ -e $DEPLOYDIR/include/libxml2 ]; then
    echo "libxml2 already installed. not building"
    return
  fi

  echo "Building libxml2 $version..."
  cd "$BASEDIR"/src
  rm -rf "libxml2-$version"
  if [ ! -f "libxml2-$version.tar.gz" ]; then
    curl --insecure -LO "ftp://xmlsoft.org/libxml2/libxml2-$version.tar.gz"
  fi
  gzip -cd "libxml2-$version.tar.gz" | $TARCMD xf - 
  cd "libxml2-$version"
  if [ "`uname | grep SunOS`" ]; then
    OTHERFLAGS='--with-zlib=/opt/csw'
  fi
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR" --without-ftp --without-http --without-python $OTHERFLAGS
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_fontconfig()
{
  version=$1
  extra_config_flags="$2"

  if [ -e $DEPLOYDIR/include/fontconfig ]; then
    echo "fontconfig already installed. not building"
    return
  fi

  echo "Building fontconfig $version..."
  cd "$BASEDIR"/src
  rm -rf "fontconfig-$version"
  if [ ! -f "fontconfig-$version.tar.gz" ]; then
    curl --insecure -LO "http://www.freedesktop.org/software/fontconfig/release/fontconfig-$version.tar.gz"
  fi
  gzip -cd  "fontconfig-$version.tar.gz" | $TARCMD xf -
  cd "fontconfig-$version"
  export PKG_CONFIG_PATH="$DEPLOYDIR/lib/pkgconfig"
  ./configure --disable-silent-rules --prefix=/ --enable-libxml2 --disable-docs $extra_config_flags
  unset PKG_CONFIG_PATH
  DESTDIR="$DEPLOYDIR" $MAKECMD -j$NUMCPU
  DESTDIR="$DEPLOYDIR" $MAKECMD install
}

build_libffi()
{
  version="$1"

  if [ -e "$DEPLOYDIR/lib/libffi.a" ]; then
    echo "libffi already installed. not building"
    return
  fi

  echo "Building libffi $version..."
  cd "$BASEDIR"/src
  rm -rf "libffi-$version"
  if [ ! -f "libffi-$version.tar.gz" ]; then
    curl --insecure -LO "ftp://sourceware.org/pub/libffi/libffi-$version.tar.gz"
  fi
  gzip -cd "libffi-$version.tar.gz" | $TARCMD xf -
  cd "libffi-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_gettext()
{
  version="$1"

  if [ -f "$DEPLOYDIR"/lib/libgettextpo.a ]; then
    echo "gettext already installed. not building"
    return
  fi

  echo "Building gettext $version..."
  cd "$BASEDIR"/src
  rm -rf "gettext-$version"
  if [ ! -f "gettext-$version.tar.gz" ]; then
    curl --insecure -LO "http://ftpmirror.gnu.org/gettext/gettext-$version.tar.gz"
  fi
  gzip -cd "gettext-$version.tar.gz" | $TARCMD xf -
  cd "gettext-$version"

  ./configure --disable-silent-rules --prefix="$DEPLOYDIR" --disable-java --disable-native-java
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_glib2()
{
  version="$1"
  if [ -f "$DEPLOYDIR/include/glib-2.0/glib.h" ]; then
    echo "glib2 already installed. not building"
    return
  fi

  echo "Building glib2 $version..."

  cd "$BASEDIR"/src
  rm -rf "glib-$version"
  maj_min_version="${version%.*}" #Drop micro
  if [ ! -f "glib-$version.tar.xz" ]; then
    curl --insecure -LO "http://ftp.gnome.org/pub/gnome/sources/glib/$maj_min_version/glib-$version.tar.xz"
  fi
  xz -cd "glib-$version.tar.xz" | $TARCMD xf -
  cd "glib-$version"

  if [ "`uname | grep SunOS`" ]; then
    OTHERFLAGS=--disable-dtrace
    CFLAGS=-D_GNU_SOURCE
  fi

  export PKG_CONFIG_PATH="$DEPLOYDIR/lib/pkgconfig"
  ./configure --disable-silent-rules --disable-gtk-doc --disable-man --prefix="$DEPLOYDIR" CFLAGS="-I$DEPLOYDIR/include" LDFLAGS="-L$DEPLOYDIR/lib" $OTHERFLAGS 
  unset PKG_CONFIG_PATH
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_ragel()
{
  version=$1

  if [ -f $DEPLOYDIR/bin/ragel ]; then
    echo "ragel already installed. not building"
    return
  fi

  echo "Building ragel $version..."
  cd "$BASEDIR"/src
  rm -rf "ragel-$version"
  if [ ! -f "ragel-$version.tar.gz" ]; then
    curl --insecure -LO "http://www.colm.net/files/ragel/ragel-$version.tar.gz"
  fi
  gzip -cd  "ragel-$version.tar.gz" | $TARCMD xf -
  cd "ragel-$version"
  sed -e "s/setiosflags(ios::right)/std::&/g" ragel/javacodegen.cpp > ragel/javacodegen.cpp.new && mv ragel/javacodegen.cpp.new ragel/javacodegen.cpp
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_harfbuzz()
{
  version=$1
  extra_config_flags="$2"

  if [ -e $DEPLOYDIR/include/harfbuzz ]; then
    echo "harfbuzz already installed. not building"
    return
  fi

  echo "Building harfbuzz $version..."
  cd "$BASEDIR"/src
  rm -rf "harfbuzz-$version"
  if [ ! -f "harfbuzz-$version.tar.gz" ]; then
    curl --insecure -LO "http://cgit.freedesktop.org/harfbuzz/snapshot/harfbuzz-$version.tar.gz"
  fi
  gzip -cd "harfbuzz-$version.tar.gz" | $TARCMD-xf -
  cd "harfbuzz-$version"
  # disable doc directories as they make problems on Mac OS Build
  sed -e "s/SUBDIRS = src util test docs/SUBDIRS = src util test/g" Makefile.am > Makefile.am.bak && mv Makefile.am.bak Makefile.am
  sed -e "s/^docs.*$//" configure.ac > configure.ac.bak && mv configure.ac.bak configure.ac
  ./autogen.sh --prefix="$DEPLOYDIR" --with-freetype=yes --with-gobject=no --with-cairo=no --with-icu=no $extra_config_flags
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_binutils()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/ar ]; then
    echo "binutils already installed. not building"
    return
  fi

  echo "Building binutils $version..."
  cd "$BASEDIR"/src
  rm -rf "binutils-$version"
  if [ ! -f "binutils-$version.tar.gz" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/binutils/binutils-$version.tar.gz
  fi
  gzip -cd "binutils-$version.tar.gz" | $TARCMD xf -
  cd "binutils-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

