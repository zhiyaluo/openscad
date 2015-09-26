# uni-build-dependencies by don bright 2012. copyright assigned to
# Marius Kintel and Clifford Wolf, 2012. released under the GPL 2, or
# later, as described in the file named 'COPYING' in OpenSCAD's project root.

# This script builds most dependencies, both libraries and binary tools,
# of OpenSCAD for Linux/BSD. It is based on macosx-build-dependencies.sh
#
# By default it builds under $HOME/openscad_deps. You can alter this by
# setting the BASEDIR environment variable or with the 'out of tree'
# feature
#
# Usage:
#   cd openscad
#   . ./scripts/setenv-unibuild.sh
#   ./scripts/uni-build-dependencies.sh
#
# Out-of-tree usage:
#
#   cd somepath
#   . /path/to/openscad/scripts/setenv-unibuild.sh
#   /path/to/openscad/scripts/uni-build-dependencies.sh
#
# Prerequisites:
# - wget or curl
# - OpenGL (GL/gl.h)
# - GLU (GL/glu.h)
# - gcc
# - Qt4
#
# If your system lacks qt4, build like this:
#
#   ./scripts/uni-build-dependencies.sh qt4
#   . ./scripts/setenv-unibuild.sh #(Rerun to re-detect qt4)
#
# If your system lacks glu, gettext, or glib2, you can build them as well:
#
#   ./scripts/uni-build-dependencies.sh glu
#   ./scripts/uni-build-dependencies.sh glib2
#   ./scripts/uni-build-dependencies.sh gettext
#
# If you want to try Clang compiler (experimental, only works on linux):
#
#   . ./scripts/setenv-unibuild.sh clang
#
# If you want to try Qt5 (experimental)
#
#   . ./scripts/setenv-unibuild.sh qt5
#

printUsage()
{
  echo "Usage: $0"
  echo
}

check_env()
{
  SLEEP=0
  if [ x != x"$CFLAGS" ]
  then
    echo "*** WARNING: You have CFLAGS set to '$CFLAGS'"
    SLEEP=2
  fi
  if [ x != x"$CXXFLAGS" ]
  then
    echo "*** WARNING: You have CXXFLAGS set to '$CXXFLAGS'"
    SLEEP=2
  fi
  if [ x != x"$LDFLAGS" ]
  then
    echo "*** WARNING: You have LDFLAGS set to '$LDFLAGS'"
    SLEEP=2
  fi
  [ $SLEEP -gt 0 ] && sleep $SLEEP || true
}

detect_glu()
{
  detect_glu_result=
  if [ -e $DEPLOYDIR/include/GL/glu.h ]; then
    detect_glu_include=$DEPLOYDIR/include
    detect_glu_result=1;
  fi
  if [ -e /usr/include/GL/glu.h ]; then
    detect_glu_include=/usr/include
    detect_glu_result=1;
  fi
  if [ -e /usr/local/include/GL/glu.h ]; then
    detect_glu_include=/usr/local/include
    detect_glu_result=1;
  fi
  if [ -e /usr/pkg/X11R7/include/GL/glu.h ]; then
    detect_glu_include=/usr/pkg/X11R7/include
    detect_glu_result=1;
  fi
  return
}

build_glu()
{
  version=$1
  if [ -e $DEPLOYDIR/lib/libGLU.so ]; then
    echo "GLU already installed. not building"
    return
  fi
  echo "Building GLU" $version "..."
  cd $BASEDIR/src
  rm -rf glu-$version
  if [ ! -f glu-$version.tar.gz ]; then
    echo downloading
    curl -O http://cgit.freedesktop.org/mesa/glu/snapshot/glu-$version.tar.gz
  fi
  gzip -cd glu-$version.tar.gz | $TARCMD xf -
  cd glu-$version
  ./autogen.sh --prefix=$DEPLOYDIR
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_qt4()
{
  version=$1
  if [ -e $DEPLOYDIR/include/Qt ]; then
    echo "qt already installed. not building"
    return
  fi
  echo "Building Qt" $version "..."
  cd $BASEDIR/src
  rm -rf ./qt-everywhere-opensource-src-$version
  if [ ! -f qt-everywhere-opensource-src-$version.tar.gz ]; then
    echo downloading
    curl -O http://releases.qt-project.org/qt4/source/qt-everywhere-opensource-src-$version.tar.gz
  fi
  gzip -cd qt-everywhere-opensource-src-$version.tar.gz | $TARCMD xf -
  cd qt-everywhere-opensource-src-$version
  ./configure -prefix $DEPLOYDIR -opensource -confirm-license -fast -no-qt3support -no-svg -no-phonon -no-audio-backend -no-multimedia -no-javascript-jit -no-script -no-scripttools -no-declarative -no-xmlpatterns -nomake demos -nomake examples -nomake docs -nomake translations -no-webkit
  $MAKECMD -j$NUMCPU
  $MAKECMD install
  QTDIR=$DEPLOYDIR
  export QTDIR
  echo "----------"
  echo " Please set QTDIR to $DEPLOYDIR ( or run '. scripts/setenv-unibuild.sh' )"
  echo "----------"
}

build_qt5()
{
  version=$1

  if [ -f $DEPLOYDIR/lib/libQt5Core.a ]; then
    echo "Qt5 already installed. not building"
    return
  fi

  echo "Building Qt" $version "..."
  cd $BASEDIR/src
  rm -rf ./qt-everywhere-opensource-src-$version
  v=`echo "$version" | sed -e 's/\.[0-9]$//'`
  if [ ! -f qt-everywhere-opensource-src-$version.tar.gz ]; then
     echo downloading
     curl -O -L http://download.qt-project.org/official_releases/qt/$v/$version/single/qt-everywhere-opensource-src-$version.tar.gz
  fi
  gzip -cd qt-everywhere-opensource-src-$version.tar.gz | $TARCMD xf -
  cd qt-everywhere-opensource-src-$version
  ./configure -prefix $DEPLOYDIR -release -static -opensource -confirm-license \
                -nomake examples -nomake tests \
                -qt-xcb -no-c++11 -no-glib -no-harfbuzz -no-sql-db2 -no-sql-ibase -no-sql-mysql -no-sql-oci -no-sql-odbc \
                -no-sql-psql -no-sql-sqlite2 -no-sql-tds -no-cups -no-qml-debug \
                -skip activeqt -skip connectivity -skip declarative -skip doc \
                -skip enginio -skip graphicaleffects -skip location -skip multimedia \
                -skip quick1 -skip quickcontrols -skip script -skip sensors -skip serialport \
                -skip svg -skip webkit -skip webkit-examples -skip websockets -skip xmlpatterns
  $MAKECMD -j"$NUMCPU" install
}

build_qt5scintilla2()
{
  version=$1

  if [ -d $DEPLOYDIR/lib/libqt5scintilla2.a ]; then
    echo "Qt5Scintilla2 already installed. not building"
    return
  fi

  echo "Building Qt5Scintilla2" $version "..."
  cd $BASEDIR/src
  #rm -rf QScintilla-gpl-$version.tar.gz
  if [ ! -f QScintilla-gpl-$version.tar.gz ]; then
     echo downloading
     curl -L -o "QScintilla-gpl-$version.tar.gz" "http://downloads.sourceforge.net/project/pyqt/QScintilla2/QScintilla-$version/QScintilla-gpl-$version.tar.gz?use_mirror=switch"
  fi
  gzip -cd QScintilla-gpl-$version.tar.gz | $TARCMD xf -
  cd QScintilla-gpl-$version/Qt4Qt5/
  qmake CONFIG+=staticlib
  $MAKECMD -j"$NUMCPU" install
}

build_bison()
{
  version=$1
  echo "Building bison" $version
  cd $BASEDIR/src
  rm -rf ./bison-$version
  if [ ! -f bison-$version.tar.gz ]; then
    echo downloading
    curl --insecure -O http://ftp.gnu.org/gnu/bison/bison-$version.tar.gz
  fi
  gzip -cd bison-$version.tar.gz | $TARCMD xf -
  cd bison-$version
  ./configure --prefix=$DEPLOYDIR
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_git()
{
  version=$1
  echo "Building git" $version "..."
  cd $BASEDIR/src
  rm -rf ./git-$version
  if [ ! -f git-$version.tar.gz ]; then
    echo downloading
    curl --insecure -O http://git-core.googlecode.com/files/git-$version.tar.gz
  fi
  gzip -cd git-$version.tar.gz | $TARCMD xf -
  cd git-$version
  ./configure --prefix=$DEPLOYDIR
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_cmake()
{
  version=$2
  versionshort=$1
  echo "Building cmake (" $versionshort ")" $version "..."
  cd $BASEDIR/src
  rm -rf ./cmake-$version
  if [ ! -f cmake-$version.tar.gz ]; then
    echo downloading
    curl --insecure -O http://www.cmake.org/files/v$versionshort/cmake-$version.tar.gz
  fi
  gzip -cd cmake-$version.tar.gz | $TARCMD xf -
  cd cmake-$version
  mkdir build
  cd build
  ../configure --prefix=$DEPLOYDIR
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_curl()
{
  version=$1
  echo "Building curl" $version "..."
  cd $BASEDIR/src
  rm -rf ./curl-$version
  if [ ! -f curl-$version.tar.bz2 ]; then
    echo downloading
    wget http://curl.haxx.se/download/curl-$version.tar.bz2
  fi
  bzip2 -cd curl-$version.tar.bz2 | $TARCMD xf -
  cd curl-$version
  mkdir build
  cd build
  ../configure --prefix=$DEPLOYDIR
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_gmp()
{
  version=$1
  if [ -e $DEPLOYDIR/include/gmp.h ]; then
    echo "gmp already installed. not building"
    return
  fi
  echo "Building gmp" $version "..."
  cd $BASEDIR/src
  rm -rf ./gmp-$version
  if [ ! -f gmp-$version.tar.bz2 ]; then
    echo downloading
    curl --insecure -O https://gmplib.org/download/gmp/gmp-$version.tar.bz2
  fi
  bzip2 -cd gmp-$version.tar.bz2 | $TARCMD xf -
  cd gmp-$version
  mkdir build
  cd build
  ../configure --prefix=$DEPLOYDIR --enable-cxx
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_mpfr()
{
  version=$1
  if [ -e $DEPLOYDIR/include/mpfr.h ]; then
    echo "mpfr already installed. not building"
    return
  fi
  echo "Building mpfr" $version "..."
  cd $BASEDIR/src
  rm -rf ./mpfr-$version
  if [ ! -f mpfr-$version.tar.bz2 ]; then
    echo downloading
    curl --insecure -O http://www.mpfr.org/mpfr-$version/mpfr-$version.tar.bz2
  fi
  bzip2 -cd mpfr-$version.tar.bz2 | $TARCMD xf -
  cd mpfr-$version
  mkdir build
  cd build
  ../configure --prefix=$DEPLOYDIR --with-gmp=$DEPLOYDIR
  $MAKECMD -j$NUMCPU
  $MAKECMD install
  cd ..
}

build_boost()
{
  if [ -e $DEPLOYDIR/include/boost ]; then
    echo "boost already installed. not building"
    return
  fi
  version=$1
  bversion=`echo $version | tr "." "_"`
  echo "Building boost" $version "..."
  cd $BASEDIR/src
  rm -rf ./boost_$bversion
  if [ ! -f boost_$bversion.tar.bz2 ]; then
    echo downloading
    curl --insecure -LO http://downloads.sourceforge.net/project/boost/boost/$version/boost_$bversion.tar.bz2
  fi
  if [ ! $? -eq 0 ]; then
    echo download failed. 
    exit 1
  fi
  bzip2 -cd boost_$bversion.tar.bz2 | $TARCMD xf -
  cd boost_$bversion
  if [ "`gcc --version|grep 4.7`" ]; then
    if [ "`echo $version | grep 1.47`" ]; then
      echo gcc 4.7 incompatible with boost 1.47. edit boost version in $0
      exit
    fi
  fi

  # sparc cpu needs the m64/m32 thing
  if [ "`echo $CC | grep m64`" ]; then
    BJAMOPTIONS='cxxflags=-m64 linkflags=-m64 -d+2'
  else
    BJAMOPTIONS='-d+2'
  fi

  # We only need certain portions of boost
  if [ -e ./bootstrap.sh ]; then
    BSTRAPBIN=./bootstrap.sh
  else
    BSTRAPBIN=./configure
  fi
  $BSTRAPBIN --prefix=$DEPLOYDIR --with-libraries=thread,program_options,filesystem,system,regex

  # Boost build changed over time, make -> bjam -> b2
  if [ -e ./b2 ]; then
    BJAMBIN=./b2
  elif [ -e ./bjam ]; then
    BJAMBIN=./bjam
  elif [ -e ./Makefile ]; then
    BJAMBIN=$MAKECMD
  fi
  if [ $CXX ]; then
    if [ $CXX = "clang++" ]; then
      $BJAMBIN -j$NUMCPU toolset=clang
    fi
  else
    $BJAMBIN -j$NUMCPU
  fi
  if [ $? = 0 ]; then
    $BJAMBIN $BJAMOPTIONS install
  else
    echo boost build failed
    exit 1
  fi
  if [ "`ls $DEPLOYDIR/include/ | grep boost.[0-9]`" ]; then
    if [ ! -e $DEPLOYDIR/include/boost ]; then
      echo "boost is old, make a symlink to $DEPLOYDIR/include/boost & rerun"
      exit 1
    fi
  fi
}

build_cgal()
{
  if [ -e $DEPLOYDIR/include/CGAL/version.h ]; then
    echo "CGAL already installed. not building"
    return
  fi
  version=$1
  echo "Building CGAL" $version "..."
  cd $BASEDIR/src
  rm -rf ./CGAL-$version
  ver4_4="curl --insecure -O https://gforge.inria.fr/frs/download.php/file/33524/CGAL-4.4.tar.bz2"
  ver4_2="curl --insecure -O https://gforge.inria.fr/frs/download.php/32360/CGAL-4.2.tar.bz2"
  ver4_1="curl --insecure -O https://gforge.inria.fr/frs/download.php/31640/CGAL-4.1.tar.bz2"
  ver4_0_2="curl --insecure -O https://gforge.inria.fr/frs/download.php/31174/CGAL-4.0.2.tar.bz2"
  ver4_0="curl --insecure -O https://gforge.inria.fr/frs/download.php/30387/CGAL-4.0.tar.gz"
  ver3_9="curl --insecure -O https://gforge.inria.fr/frs/download.php/29125/CGAL-3.9.tar.gz"
  ver3_8="curl --insecure -O https://gforge.inria.fr/frs/download.php/28500/CGAL-3.8.tar.gz"
  ver3_7="curl --insecure -O https://gforge.inria.fr/frs/download.php/27641/CGAL-3.7.tar.gz"
  vernull="echo already downloaded..skipping"
  download_cmd=ver`echo $version | sed s/"\."/"_"/ | sed s/"\."/"_"/`

  if [ -e CGAL-$version.tar.gz ]; then
    download_cmd=vernull;
  fi
  if [ -e CGAL-$version.tar.bz2 ]; then
    download_cmd=vernull;
  fi

  eval echo "$"$download_cmd
  `eval echo "$"$download_cmd`

  zipper=gzip
  suffix=gz
  if [ -e CGAL-$version.tar.bz2 ]; then
    zipper=bzip2
    suffix=bz2
  fi

  $zipper -cd CGAL-$version.tar.$suffix | $TARCMD xf -
  cd CGAL-$version

  # older cmakes have buggy FindBoost that can result in
  # finding the system libraries but OPENSCAD_LIBRARIES include paths
  FINDBOOST_CMAKE=$OPENSCAD_SCRIPTDIR/../tests/FindBoost.cmake
  cp $FINDBOOST_CMAKE ./cmake/modules/

  if [ "`uname | grep SunOS`" ]; then
    # workaround create_subdirectory cmake bug
    cat src/CMakeLists.txt | sed s/"\\/\\/CMakeLists.txt"/"\\/CMakeLists.txt"/  > .tmp 
    cat .tmp > src/CMakeLists.txt
  fi

  mkdir bin
  cd bin
  rm -rf ./*
  if [ "`uname -a| grep ppc64`" ]; then
    CGAL_BUILDTYPE="Release" # avoid assertion violation
  else
    CGAL_BUILDTYPE="Debug"
  fi

  if [ "`echo $CC | grep ..m64 `" ]; then
    COMPILER='-DCMAKE_CXX_FLAGS=-m64 -DCMAKE_C_FLAGS=-m64'
  fi

  BUILD=`echo -DCMAKE_BUILD_TYPE=$CGAL_BUILDTYPE -Wno-dev `
  PREFIX=`echo -DCMAKE_INSTALL_PREFIX=$DEPLOYDIR `
  CGALEXTRAS=`echo -DWITH_CGAL_Qt3=OFF -DWITH_CGAL_Qt4=OFF -DWITH_CGAL_ImageIO=OFF -DWITH_examples=OFF -DWITH_demos=OFF `
  GMPMPFRBOOST=`echo -DGMP_INCLUDE_DIR=$DEPLOYDIR/include -DGMP_LIBRARIES=$DEPLOYDIR/lib/libgmp.so -DGMPXX_LIBRARIES=$DEPLOYDIR/lib/libgmpxx.so -DGMPXX_INCLUDE_DIR=$DEPLOYDIR/include -DMPFR_INCLUDE_DIR=$DEPLOYDIR/include -DMPFR_LIBRARIES=$DEPLOYDIR/lib/libmpfr.so $CGALEXTRAS -DBOOST_LIBRARYDIR=$DEPLOYDIR/lib -DBOOST_INCLUDEDIR=$DEPLOYDIR/include -DBoost_NO_SYSTEM_PATHS=1 `
  DEBUGBOOSTFIND=0 # for debugging FindBoost.cmake (not for debugging boost)
  Boost_NO_SYSTEM_PATHS=1

  if [ "`echo $2 | grep use-sys-libs`" ]; then
    echo cmake $PREFIX $CGALEXTRAS $BUILD -DBoost_DEBUG=$DEBUGBOOSTFIND $COMPILER ..
    cmake $PREFIX $CGALEXTRAS $BUILD -DBoost_DEBUG=$DEBUGBOOSTFIND $COMPILER ..
  else
    echo cmake $PREFIX $CGALEXTRAS $BUILD $GMPMPFRBOOST -DBoost_DEBUG=$DEBUGBOOSTFIND $COMPILER ..
    cmake $PREFIX $CGALEXTRAS $BUILD $GMPMPFRBOOST -DBoost_DEBUG=$DEBUGBOOSTFIND $COMPILER ..
  fi
  $MAKECMD -j$NUMCPU VERBOSE=1
  $MAKECMD install
}

check_glew()
{
  check_glew_result=
  if [ -e $DEPLOYDIR/lib64/libGLEW.so ]; then
    check_glew_result=1
  fi
  if [ -e $DEPLOYDIR/lib/libGLEW.so ]; then
    check_glew_result=1
  fi
}

build_glew()
{
  check_glew
  if [ $check_glew_result ]; then
    echo "glew already installed. not building"
    return
  fi
  version=$1
  echo "Building GLEW" $version "..."
  cd $BASEDIR/src
  rm -rf ./glew-$version
  if [ ! -f glew-$version.tgz ]; then
    echo downloading
    curl --insecure -LO http://downloads.sourceforge.net/project/glew/glew/$version/glew-$version.tgz
  fi
  gzip -cd glew-$version.tgz | $TARCMD xf -
  cd glew-$version
  mkdir -p $DEPLOYDIR/lib/pkgconfig

  # Glew's makefile is not built for Linux Multiarch. We aren't trying
  # to fix everything here, just the test machines OScad normally runs on

  # Fedora 64-bit
  if [ "`uname -m | grep 64`" ]; then
    if [ -e /usr/lib64/libXmu.so.6 ]; then
      sed -ibak s/"\-lXmu"/"\-L\/usr\/lib64\/libXmu.so.6"/ config/Makefile.linux
    fi
  fi

  # debian hurd i386
  if [ "`uname -m | grep 386`" ]; then
    if [ -e /usr/lib/i386-gnu/libXi.so.6 ]; then
      sed -ibak s/"-lXi"/"\-L\/usr\/lib\/i386-gnu\/libXi.so.6"/ config/Makefile.gnu
    fi
  fi

  # custom CC settings, like clang linux
  if [ "`echo $CC`" ]; then
    cat config/Makefile.linux | sed  s/"CC = cc"/"# CC = cc"/ > tmp
    mv tmp config/Makefile.linux
  fi

  if [ "`uname | grep SunOS`" ]; then
    cat config/Makefile.solaris | sed  s/"CC = cc"/"# CC = cc"/ > tmp
    mv tmp config/Makefile.solaris
    cat config/Makefile.solaris | sed  s/"-Kpic"/""/ > tmp
    mv tmp config/Makefile.solaris
    cat config/Makefile.solaris | sed  s/"LD = ld"/"LD = gld "/ > tmp
    mv tmp config/Makefile.solaris
    cat config/Makefile.solaris | sed  s/"-lX11"/"-lX11 -lc"/ > tmp
    mv tmp config/Makefile.solaris
    cat config/Makefile.solaris | sed  s/"POPT ="/"#POPT ="/ > tmp
    mv tmp config/Makefile.solaris
    MAKEFLAGS='INSTALL=ginstall STRIP=gstrip AR=gar'    
  fi

  if [ "`uname | grep BSD`" ]; then
    if [ "`command -v gmake`" ]; then
      echo "building glew with gnu make"
    else
      echo "building glew on BSD requires gmake (gnu make)"
      exit
    fi
  fi

  GLEW_DEST=$DEPLOYDIR $MAKECMD $MAKEFLAGS -j$NUMCPU
  GLEW_DEST=$DEPLOYDIR $MAKECMD $MAKEFLAGS install
  if [ $GLEW_INSTALLED ]; then
    echo glew installed to $DEPLOYDIR
  else
    exit
    echo glew install failed
  fi
}

build_opencsg_makefile()
{
  # called from build_opencsg
  cp Makefile Makefile.bak
  cp src/Makefile src/Makefile.bak

  cat Makefile.bak | sed s/example// | sed s/glew// | sed s/make/$MAKECMD/ > Makefile
  cat src/Makefile.bak | grep -v ^INCPATH | grep -v ^LIBS > src/Makefile.bak2
  echo "INCPATH = -I$BASEDIR/include -I../include -I.. -I$GLU_INCLUDE -I." > src/header
  echo "LIBS = -L$BASEDIR/lib -L/usr/X11R6/lib -lGLU -lGL" >> src/header
  cat src/header src/Makefile.bak2 > src/Makefile
}

build_opencsg()
{
  if [ -e $DEPLOYDIR/lib/libopencsg.so ]; then
    echo "OpenCSG already installed. not building"
    return
  fi
  version=$1
  echo "Building OpenCSG" $version "..."
  cd $BASEDIR/src
  rm -rf ./OpenCSG-$version
  if [ ! -f OpenCSG-$version.tar.gz ]; then
    echo downloading
    curl --insecure -O http://www.opencsg.org/OpenCSG-$version.tar.gz
  fi
  gzip -cd OpenCSG-$version.tar.gz | $TARCMD xf -
  cd OpenCSG-$version

  # modify the .pro file for qmake, then use qmake to
  # manually rebuild the src/Makefile (some systems don't auto-rebuild it)

  cp opencsg.pro opencsg.pro.bak
  cat opencsg.pro.bak | sed s/example// > opencsg.pro

  detect_glu
  GLU_INCLUDE=$detect_glu_include
  if [ ! $detect_glu_result ]; then
    build_glu 9.0.0
  fi
  echo GLU_INCLUDE $GLU_INCLUDE

  if [ "`uname | grep SunOS`" ]; then
    OPENCSG_QMAKE='echo none'
    build_opencsg_makefile
    tmp=$version
    version=$tmp
  elif [ "`command -v qmake-qt4`" ]; then
    OPENCSG_QMAKE=qmake-qt4
  elif [ "`command -v qmake4`" ]; then
    OPENCSG_QMAKE=qmake4
  elif [ "`command -v qmake-qt5`" ]; then
    OPENCSG_QMAKE=qmake-qt5
  elif [ "`command -v qmake5`" ]; then
    OPENCSG_QMAKE=qmake5
  elif [ "`command -v qmake`" ]; then
    OPENCSG_QMAKE=qmake
  else
    echo qmake not found... using standard OpenCSG makefiles
    OPENCSG_QMAKE='echo none'
    build_opencsg_makefile
    tmp=$version
    version=$tmp
  fi

  if [ "` echo $OPENCSG_QMAKE | grep none`" ]; then
    OPENCSG_QMAKE=$OPENCSG_QMAKE' "QMAKE_CXXFLAGS+=-I'$GLU_INCLUDE'"'
  fi
  echo OPENCSG_QMAKE: $OPENCSG_QMAKE

  cd $BASEDIR/src/OpenCSG-$version/src
  $OPENCSG_QMAKE

  cd $BASEDIR/src/OpenCSG-$version
  $OPENCSG_QMAKE

  $MAKECMD

  INSTALLER=install
  if [ "`uname | grep SunOS`" ]; then
   INSTALLER=ginstall
  fi

  ls lib/* include/*
  if [ -e lib/.libs ]; then ls lib/.libs/*; fi # netbsd
  echo "installing to -->" $DEPLOYDIR
  mkdir -p $DEPLOYDIR/lib
  mkdir -p $DEPLOYDIR/include
  $INSTALLER lib/* $DEPLOYDIR/lib
  $INSTALLER include/* $DEPLOYDIR/include
  if [ -e lib/.libs ]; then $INSTALLER lib/.libs/* $DEPLOYDIR/lib; fi #netbsd

  cd $BASEDIR
}

build_eigen()
{
  version=$1
  if [ -e $DEPLOYDIR/include/eigen3 ]; then
    if [ `echo $version | grep 3....` ]; then
      echo "Eigen3 already installed. not building"
      return
    fi
  fi
  echo "Building eigen" $version "..."
  cd $BASEDIR/src
  rm -rf ./eigen-$version
  EIGENDIR="none"
  if [ $version = "3.2.2" ]; then EIGENDIR=eigen-eigen-1306d75b4a21; fi
  if [ $version = "3.1.1" ]; then EIGENDIR=eigen-eigen-43d9075b23ef; fi
  if [ $EIGENDIR = "none" ]; then
    echo Unknown eigen version. Please edit script.
    exit 1
  fi
  rm -rf ./$EIGENDIR
  if [ ! -f eigen-$version.tar.bz2 ]; then
    echo downloading
    curl --insecure -LO http://bitbucket.org/eigen/eigen/get/$version.tar.bz2
    mv $version.tar.bz2 eigen-$version.tar.bz2
  fi
  bzip2 -cd eigen-$version.tar.bz2 | $TARCMD xf -
  ln -s ./$EIGENDIR eigen-$version
  cd eigen-$version
  rm -rf $DEPLOYDIR/include/eigen3
  mkdir $DEPLOYDIR/include
  mv ./Eigen $DEPLOYDIR/include/eigen3
  # Eigen's cmake install-to-prefix is broken. 
  #  mkdir build
  #  cd build
  #  cmake -DCMAKE_INSTALL_PREFIX=$DEPLOYDIR -DEIGEN_TEST_NO_OPENGL=1 
  #  $MAKECMD -j$NUMCPU
  #  $MAKECMD install
}


# glib2 and dependencies

#build_gettext()
#{
#  version=$1
#  ls -l $DEPLOYDIR/include/gettext-po.h
#  if [ -e $DEPLOYDIR/include/gettext-po.h ]; then
#    echo "gettext already installed. not building"
#    return
#  fi
#
#  echo "Building gettext $version..."
#
#  cd "$BASEDIR"/src
#  rm -rf "gettext-$version"
#  if [ ! -f "glib-$version.tar.gz" ]; then
#    curl --insecure -LO "http://ftpmirror.gnu.org/gettext/gettext-$version.tar.gz"
#  fi
#  tar xzf "gettext-$version.tar.gz"
#  cd "gettext-$version"
#
#  ./configure --prefix="$DEPLOYDIR"
#  $MAKECMD -j$NUMCPU
#  $MAKECMD install
#}

build_pkgconfig()
{
  if [ "`command -v pkg-config`" ]; then
    echo "pkg-config already installed. not building"
    return
  fi
  version=$1
  echo "Building pkg-config $version..."

  cd "$BASEDIR"/src
  rm -rf ./pkg-config-$version
  if [ ! -f "pkg-config-$version.tar.gz" ]; then
    echo downloading
    curl --insecure -LO "http://pkgconfig.freedesktop.org/releases/pkg-config-$version.tar.gz"
  fi
  gzip -cd "pkg-config-$version.tar.gz" | $TARCMD xf -
  cd "pkg-config-$version"

  ./configure --prefix="$DEPLOYDIR" --with-internal-glib
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

build_libffi()
{
  if [ -e $DEPLOYDIR/include/ffi.h ]; then
    echo "libffi already installed. not building"
    return
  fi
  version=$1
  echo "Building libffi $version..."

  cd "$BASEDIR"/src
  rm -rf ./libffi-$version
  if [ ! -f "libffi-$version.tar.gz" ]; then
    echo downloading
    curl --insecure -LO "ftp://sourceware.org/pub/libffi/libffi-$version.tar.gz"
    curl --insecure -LO "http://www.linuxfromscratch.org/patches/blfs/svn/libffi-$version-includedir-1.patch"
  fi
  gzip -cd "libffi-$version.tar.gz" | $TARCMD xf -
  cd "libffi-$version"
  if [ ! "`command -v patch`" ]; then
    echo cannot proceed, need 'patch' program
    exit 1
  fi
  patch -Np1 -i ../libffi-3.0.13-includedir-1.patch
  ./configure --prefix="$DEPLOYDIR"
  $MAKECMD -j$NUMCPU
  $MAKECMD install
}

#build_glib2()
#{
#  version="$1"
#  maj_min_version="${version%.*}" #Drop micro#
#
#  if [ -e $DEPLOYDIR/lib/glib-2.0 ]; then
#    echo "glib2 already installed. not building"
#    return
#  fi
#
# echo "Building glib2 $version..."
#  cd "$BASEDIR"/src
#  rm -rf ./"glib-$version"
#  if [ ! -f "glib-$version.tar.xz" ]; then
#    echo downloading
#    curl --insecure -LO "http://ftp.gnome.org/pub/gnome/sources/glib/$maj_min_version/glib-$version.tar.xz"
#  fi
#  tar xJf "glib-$version.tar.xz"
#  cd "glib-$version"

#  ./configure --disable-gtk-doc --disable-man --prefix="$DEPLOYDIR" CFLAGS="-I$DEPLOYDIR/include" LDFLAGS="-L$DEPLOYDIR/lib"
#  $MAKECMD -j$NUMCPU
#  $MAKECMD install
#}

## end of glib2 stuff

# this section allows 'out of tree' builds, as long as the system has
# the 'dirname' command installed

if [ "`command -v dirname`" ]; then
  RUNDIR=`pwd`
  OPENSCAD_SCRIPTDIR=`dirname $0`
  cd $OPENSCAD_SCRIPTDIR
  OPENSCAD_SCRIPTDIR=`pwd`
  cd $RUNDIR
else
  if [ ! -f openscad.pro ]; then
    echo "Must be run from the OpenSCAD source root directory (dont have 'dirname')"
    exit 1
  else
    OPENSCAD_SCRIPTDIR=$PWD
  fi
fi

check_env

# note: many important variables can be set in setenv, like CC, CXX, and TARCMD
# '.' is equivalent to 'source'
. $OPENSCAD_SCRIPTDIR/setenv-unibuild.sh 
. $OPENSCAD_SCRIPTDIR/common-build-dependencies.sh
SRCDIR=$BASEDIR/src

if [ ! $NUMCPU ]; then
  echo "Note: The NUMCPU environment variable can be set for parallel builds"
  NUMCPU=1
fi

if [ ! -d $BASEDIR/bin ]; then
  mkdir -p $BASEDIR/bin
fi

echo "Using basedir:" $BASEDIR
echo "Using deploydir:" $DEPLOYDIR
echo "Using srcdir:" $SRCDIR
echo "Number of CPUs for parallel builds:" $NUMCPU
mkdir -p $SRCDIR $DEPLOYDIR

# this section builds some basic tools, if they are missing or outdated
# they are installed under $BASEDIR/bin which we have added to our PATH

if [ ! "`command -v curl`" ]; then
  build_curl 7.26.0
fi

if [ ! "`command -v bison`" ]; then
  build_bison 2.6.1
fi

if [ "`uname | grep SunOS`" ]; then
  if [ "`cmake --version | grep 'version 2'`" ]; then
    build_cmake 3.3 3.3.2
  elif [ "`cmake --version | grep 'version 3.2'`" ]; then
    build_cmake 3.3 3.3.2
  fi
fi

if [ ! "`command -v cmake`" ]; then
  build_cmake 2.8 2.8.8
elif [ "`cmake --version | grep 'version 2.[1-8][^0-9][1-4] '`" ]; then
  # see README for needed version (this should match 1<minimum)
  build_cmake 2.8 2.8.8
fi

# Singly build certain tools or libraries
if [ $1 ]; then
  if [ $1 = "git" ]; then
    build_git 1.7.10.3
    exit $?
  fi
  if [ $1 = "cmake" ]; then
    build_cmake 3.3 3.3.2
    exit $?
  fi
  if [ $1 = "cgal" ]; then
    build_cgal 4.4 use-sys-libs
    exit $?
  fi
  if [ $1 = "opencsg" ]; then
    build_opencsg 1.3.2
    exit $?
  fi
  if [ $1 = "qt4" ]; then
    # such a huge build, put here by itself
    build_qt4 4.8.4
    exit $?
  fi
  if [ $1 = "qt5" ]; then
    build_qt5 5.3.1
    build_qt5scintilla2 2.8.3
    exit $?
  fi
  if [ $1 = "glu" ]; then
    # Mesa and GLU split in late 2012, so it's not on some systems
    build_glu 9.0.0
    exit $?
  fi
  if [ $1 = "gettext" ]; then
    # such a huge build, put here by itself
    build_gettext 0.18.3.1
    exit $?
  fi
  if [ $1 = "harfbuzz" ]; then
    # debian 7 lacks only harfbuzz
    build_harfbuzz 0.9.23 --with-glib=yes
    exit $?
  fi
  if [ $1 = "glib2" ]; then
    # such a huge build, put here by itself
    build_pkgconfig 0.28
    build_libffi 3.0.13
    #build_gettext 0.18.3.1
    build_glib2 2.38.2
    exit $?
  fi
fi


# todo - cgal 4.02 for gcc<4.7, gcc 4.2 for above

#
# Main build of libraries
# edit version numbers here as needed.
# This is only for libraries most systems won't have new enough versions of.
# For big things like Qt4, see the notes at the head of this file on
# building individual dependencies.
# 
# Some of these are defined in scripts/common-build-dependencies.sh

build_gmp 5.0.5
build_mpfr 3.1.1
build_eigen 3.2.2
build_boost 1.56.0
# NB! For CGAL, also update the actual download URL in the function
build_cgal 4.4
build_glew 1.13.0
exit
build_opencsg 1.3.2
build_gettext 0.18.3.1
build_glib2 2.38.2

exit

# the following are only needed for text()
build_freetype 2.5.0.1 --without-png
build_libxml2 2.9.1
build_fontconfig 2.11.0 --with-add-fonts=/usr/X11R6/lib/X11/fonts,/usr/local/share/fonts
build_ragel 6.9
build_harfbuzz 0.9.23 --with-glib=yes

echo "OpenSCAD dependencies built and installed to " $BASEDIR
