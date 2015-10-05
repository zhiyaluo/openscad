#
# This script contains functions for building various libraries
# used by OpenSCAD.
# It's supposed to be included from the system specific scripts.
#
# scripts/uni-build-dependencies.sh - generic linux/bsd
# scripts/macosx-build-             - mac osx options
# scripts/mingw-x-build-            - not used, MXE handles all dependencies.

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
  gzip -cd "freetype-$version.tar.gz" | tar xf -
  cd "freetype-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR" $extra_config_flags
  make -j"$NUMCPU"
  make install
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
  gzip -cd "libxml2-$version.tar.gz" | tar xf - 
  cd "libxml2-$version"
  if [ "`uname | grep SunOS`" ]; then
    OTHERFLAGS=--with-zlib=/opt/csw
  fi
  echo ./configure --disable-silent-rules --prefix="$DEPLOYDIR" --without-ftp --without-http --without-python $OTHERFLAGS
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR" --without-ftp --without-http --without-python $OTHERFLAGS
  make -j$NUMCPU
  make install
}

build_fontconfig()
{
  version=$1
  extra_config_flags="$2"

  if [ -e $DEPLOYDIR/lib/libfontconfig.so ]; then
    echo "fontconfig already installed. not building"
    return
  fi

  echo "Building fontconfig $version..."
  cd "$BASEDIR"/src
  rm -rf "fontconfig-$version"
  if [ ! -f "fontconfig-$version.tar.gz" ]; then
    curl --insecure -LO "http://www.freedesktop.org/software/fontconfig/release/fontconfig-$version.tar.gz"
  fi
  gzip -cd  "fontconfig-$version.tar.gz" | tar xf -
  cd "fontconfig-$version"
  export PKG_CONFIG_PATH="$DEPLOYDIR/lib/pkgconfig"
  ./configure --disable-silent-rules --prefix=/ --enable-libxml2 --disable-docs $extra_config_flags
  unset PKG_CONFIG_PATH
  DESTDIR="$DEPLOYDIR" make -j$NUMCPU
  DESTDIR="$DEPLOYDIR" make install
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
  gzip -cd "libffi-$version.tar.gz" | tar xf -
  cd "libffi-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  make -j$NUMCPU
  make install
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
  gzip -cd "gettext-$version.tar.gz" | tar xf -
  cd "gettext-$version"

  ./configure --disable-silent-rules --prefix="$DEPLOYDIR" --disable-java --disable-native-java
  make -j$NUMCPU
  make install
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
  xz -cd "glib-$version.tar.xz" | tar xf -
  cd "glib-$version"

  if [ "`uname | grep SunOS`" ]; then
    OTHERFLAGS=--disable-dtrace
    CFLAGS=-D_GNU_SOURCE
  fi

  export PKG_CONFIG_PATH="$DEPLOYDIR/lib/pkgconfig"
  ./configure --disable-silent-rules --disable-gtk-doc --disable-man --prefix="$DEPLOYDIR" CFLAGS="-I$DEPLOYDIR/include" LDFLAGS="-L$DEPLOYDIR/lib" $OTHERFLAGS 
  unset PKG_CONFIG_PATH
  make -j$NUMCPU
  make install
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
  gzip -cd  "ragel-$version.tar.gz" | tar xf -
  cd "ragel-$version"
  sed -e "s/setiosflags(ios::right)/std::&/g" ragel/javacodegen.cpp > ragel/javacodegen.cpp.new && mv ragel/javacodegen.cpp.new ragel/javacodegen.cpp
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  make -j$NUMCPU
  make install
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
  gzip -cd "harfbuzz-$version.tar.gz" | tar -xf -
  cd "harfbuzz-$version"
  PKG_CONFIG_PATH="$DEPLOYDIR/lib/pkgconfig"
  export PKG_CONFIG_PATH
  # disable doc directories as they make problems on Mac OS Build
  sed -e "s/SUBDIRS = src util test docs/SUBDIRS = src util test/g" Makefile.am > Makefile.am.bak && mv Makefile.am.bak Makefile.am
  sed -e "s/^docs.*$//" configure.ac > configure.ac.bak && mv configure.ac.bak configure.ac
  ./autogen.sh --prefix="$DEPLOYDIR" --disable-silent-rules --with-freetype=yes --with-gobject=no --with-cairo=no --with-icu=no $extra_config_flags
  unset PKG_CONFIG_PATH
  make -j$NUMCPU
  make install
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
  gzip -cd "binutils-$version.tar.gz" | tar xf -
  cd "binutils-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  # more reliable to non-paralell build basic utils like binutils
  make
  make install
}


build_coreutils()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/ls ]; then
    echo "coreutils already installed. not building"
    return
  fi

  echo "Building coreutils $version..."
  cd "$BASEDIR"/src
  rm -rf "coreutils-$version"
  if [ ! -f "coreutils-$version.tar.xz" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/coreutils/coreutils-$version.tar.xz
  fi
  xz -cd "coreutils-$version.tar.xz" | tar xf -
  cd "coreutils-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  # more reliable to non-paralell build basic utils like coreutils
  make
  make install
}


build_zlib()
{
  version=$1

  if [ -e $DEPLOYDIR/include/zlib.h ]; then
    echo "zlib already installed. not building"
    return
  fi

  echo "Building zlib $version..."
  cd "$BASEDIR"/src
  rm -rf "zlib-$version"
  if [ ! -f "zlib-$version.tar.gz" ]; then
    curl --insecure -LO http://zlib.net/zlib-$version.tar.gz
  fi
  gzip -cd "zlib-$version.tar.gz" | tar xf -
  cd "zlib-$version"
  ./configure --prefix="$DEPLOYDIR"
  # more reliable to non-paralell build basic utils like zlib
  make
  make install
}



build_tar()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/tar ]; then
    echo "tar already installed. not building"
    return
  fi

  echo "Building tar $version..."
  cd "$BASEDIR"/src
  rm -rf "tar-$version"
  if [ ! -f "tar-$version.shar" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/tar/tar-$version.shar.gz
  fi
  gzip -d "tar-$version.shar.gz"
  bash ./tar-$version.shar
  cd "tar-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  # more reliable to non-paralell build basic utils like tar
  #tricky.. installed make might not work
  make 
  make install
}

build_make()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/make ]; then
    echo "make already installed. not building"
    return
  fi

  echo "Building make $version..."
  cd "$BASEDIR"/src
  rm -rf "make-$version"
  if [ ! -f "make-$version.tar.gz" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/make/make-$version.tar.gz
  fi
  gzip -cd "make-$version.tar.gz" | tar xf -
  cd "make-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  #tricky.. installed make might not work
  # more reliable to non-paralell build basic utils like make
  make
  make install
}


build_automake()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/aclocal ]; then
    echo "automake already installed. not building"
    return
  fi

  echo "Building automake $version..."
  cd "$BASEDIR"/src
  rm -rf "automake-$version"
  if [ ! -f "automake-$version.tar.gz" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/automake/automake-$version.tar.gz
  fi
  gzip -cd "automake-$version.tar.gz" | tar xf -
  cd "automake-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  #tricky.. installed automake might not work
  # more reliable to non-paralell build basic utils like automake
  make
  make install
}


build_autoconf()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/autoreconf ]; then
    echo "autoconf already installed. not building"
    return
  fi

  echo "Building autoconf $version..."
  cd "$BASEDIR"/src
  rm -rf "autoconf-$version"
  if [ ! -f "autoconf-$version.tar.gz" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/autoconf/autoconf-$version.tar.gz
  fi
  gzip -cd "autoconf-$version.tar.gz" | tar xf -
  cd "autoconf-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  #tricky.. installed autoconf might not work
  # more reliable to non-paralell build basic utils like autoconf
  make
  make install
}


build_libtool()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/libtool ]; then
    echo "libtool already installed. not building"
    return
  fi

  echo "Building libtool $version..."
  cd "$BASEDIR"/src
  rm -rf "libtool-$version"
  if [ ! -f "libtool-$version.tar.gz" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/libtool/libtool-$version.tar.gz
  fi
  gzip -cd "libtool-$version.tar.gz" | tar xf -
  cd "libtool-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  #tricky.. installed libtool might not work
  # more reliable to non-paralell build basic utils like libtool
  make
  make install
}


build_bison()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/bison ]; then
    echo "bison already installed. not building"
    return
  fi

  echo "Building bison $version..."
  cd "$BASEDIR"/src
  rm -rf "bison-$version"
  if [ ! -f "bison-$version.tar.gz" ]; then
    curl --insecure -LO http://ftp.gnu.org/gnu/bison/bison-$version.tar.gz
  fi
  gzip -cd "bison-$version.tar.gz" | tar xf -
  cd "bison-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  make -j$NUMCPU
  make install
}



build_flex()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/flex ]; then
    echo "flex already installed. not building"
    return
  fi

  echo "Building flex $version..."
  cd "$BASEDIR"/src
  rm -rf "flex-$version"
  if [ ! -f "flex-$version.tar.gz" ]; then
    curl --insecure -LO http://downloads.sourceforge.net/project/flex/flex-$version.tar.xz
  fi
  xz -cd "flex-$version.tar.xz" | tar xf -
  cd "flex-$version"
  ./configure --disable-silent-rules --prefix="$DEPLOYDIR"
  make -j$NUMCPU
  make install
}


build_git()
{
  version=$1

  if [ -e $DEPLOYDIR/bin/git ]; then
    echo "git already installed. not building"
    return
  fi

  echo "Building git $version..."
  cd "$BASEDIR"/src
  rm -rf "git-$version"
  if [ ! -f "git-$version.tar.xz" ]; then
    curl --insecure -LO https://www.kernel.org/pub/software/scm/git/git-$version.tar.xz
  fi
  xz -cd "git-$version.tar.xz" | tar xf -
  cd "git-$version"
  LDFLAGS=-lintl ./configure --prefix="$DEPLOYDIR" --with-sane-tool-path=$DEPLOYDIR/bin
  LDFLAGS=-lintl make V=1
  make V=1 install
}


build_glproto()
{
  if [ -e $DEPLOYDIR/lib/pkgconfig/glproto.pc ]; then
    echo "glproto already installed. not building"
    return
  fi
  cd "$BASEDIR"/src
  rm -rf ./glproto
  git clone git://anongit.freedesktop.org/xorg/proto/glproto
  cd glproto
  ./autogen.sh --prefix=$DEPLOYDIR --disable-silent-rules
  make VERBOSE=1
  make install
}

build_osmesa()
{
  build_glproto

  version=$1

  if [ -e $DEPLOYDIR/lib/libOSMesa.so ]; then
    echo "OSMesa already installed. not building"
    return
  fi

  echo "Building OSMesa $version..."
  cd "$BASEDIR"/src
  rm -rf "mesa-$version"
  if [ ! -f "mesa-$version.tar.xz" ]; then
    curl --insecure -LO ftp://ftp.freedesktop.org/pub/mesa/11.0.2/mesa-$version.tar.xz
  fi
  xz -cd "mesa-$version.tar.xz" | tar xf -
  cd "mesa-$version"
  #./configure --prefix=$DEPLOYDIR \
  # --disable-silent-rules --enable-osmesa --disable-driglx-direct  \
  # --disable-dri --disable-dri3 --disable-egl --with-gallium-drivers=swrast \
  # --with-dri-drivers=swrast --enable-shared
  if [ "`uname | grep SunOS`" ]; then
    # #define _XOPEN_SOURCE 600 // Solaris 
    # https://github.com/cesanta/mongoose/issues/21
    sed s/"DEFINES -DSVR4"/"DEFINES -DSVR4 -D_XOPEN_SOURCE=600 -Drestrict= -DNULL=0"/ configure > ./configure.tmp
    mv ./configure.tmp ./configure
  fi
  chmod u+x ./configure
  ./configure --prefix=$DEPLOYDIR \
   --disable-silent-rules --enable-osmesa --disable-driglx-direct  \
   --disable-dri --disable-dri3 --disable-egl --with-gallium-drivers=swrast \
   --enable-shared --disable-glx
  make VERBOSE=1	
  make install
}

