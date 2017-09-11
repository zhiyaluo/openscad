# This is a kludge to enable running OpenGL(TM) programs under the Nix
# packaging system on Linux platforms. It works by copying system DRI
# drivers and dependencies into a subdirectory,  modifying the dynamic
# linking/loading rpath of these .so files with patchelf,  then passing
# LIBGL_DRIVER_DIR to Nix's libGL.so so it will dlopen() our special copies
# of these drivers.
#
# To use:
#
#   Don't. This script is normally called from scripts/nixshell-run.sh
#
# To test: (Keep in mind things like ldd, patchelf, differ when testing)
#          (Because nix has its own version of many of these items)
#
#   First argument: directory to store modified GL driver .so files + deps
#   Second argument: path to system's ldd program (usually /usr/bin/ldd)
#
#  /openscad/bin$ IN_NIX_SHELL=1 ../scripts/nix-setup-gl-libs.sh ./testgldir /usr/bin/ldd
#
# To test with software rendering:
#
#  /openscad/bin$ export LIBGL_ALWAYS_SOFTWARE=1
#  /openscad/bin$ # run the same steps.. it will find swrast_dri.so and
#                 # use that as it's dri driver in place of a hardware driver
#
# Theory:
#
# We need OpenSCAD to run using Nix packages, but Nix doesn't come with DRI
# GL graphics drivers. There is no simple way to tell Nix's libGL.so how
# to load these drivers, since Nix uses both a specially modified linker and
# dynamic object loader (ld, ld-linux.so) that are different than what
# the operating system itself uses. Nix by default looks under the /run
# directory in /run/opengl-drivers but that is of little use to us since
# that path requires root access and doesnt always persist across reboots.
# The DRI .so driver files depend on many other .so libraries that Nix's
# loader cannot easily find or work with. For example the usual trick
# of setting LD_LIBRARY_PATH trick doesn't work very well.
#
# Therefore, we find the DRI drivers ourselves, copy them to a
# subfolder, find their dependency .so files, copy them as well to the
# same subfolder, patchelf all their rpaths, and tell Nix libGL to use
# our copy of the DRI driver. Then Nix libGL.so will dlopen() our copy of the
# driver, and its INTERP ELF loader will use it's rpath to load our copies of
# dependencies, which will in turn use their rpaths to load our copies of their
# dependencies, recursing down the dependency tree until all DRI
# dependency .so files are loaded. Hopefully this way the DRI driver
# dependencies wont conflict with Nix's.
#
# See Also
# https://github.com/NixOS/nixpkgs/issues/9415#issuecomment-170661702
# https://grahamwideman.wordpress.com/2009/02/09/the-linux-loader-and-how-it-finds-libraries/
# http://www.airs.com/blog/archives/38
# http://www.airs.com/blog/archives/39
# http://www.airs.com/blog/archives/ (thru 50)
# https://anonscm.debian.org/git/pkg-xorg/lib/mesa.git/tree/docs/libGL.txt
# https://anonscm.debian.org/git/pkg-xorg/lib/mesa.git/tree/src/loader/
# https://github.com/deepfire/nix-install-vendor-gl
# https://nixos.org/patchelf.html
# https://en.wikipedia.org/wiki/Direct_Rendering_Manager
# rpath, mmap, strace, shared libraries, linkers, loaders
# https://unix.stackexchange.com/questions/97676/how-to-find-the-driver-module-associated-with-a-device-on-linux
# https://stackoverflow.com/questions/5103443/how-to-check-what-shared-libraries-are-loaded-at-run-time-for-a-given-process
# https://superuser.com/questions/1144758/overwrite-default-lib64-ld-linux-x86-64-so-2-to-call-executables
# https://stackoverflow.com/a/3450447

# glxinfo can hang, so we need to run it a special way
run_glxinfo() {
  prefix=$2" "$3
  logfile=$1
  $prefix glxinfo &> $logfile &
  glxinfopid=$!
  sleep 1
  sleep 1
  set +e
  if [ "`ps cax | grep $glxinfopid | grep glxinfo`" ]; then
    kill $glxinfopid
  fi
  set -e
}

verify_script_deps() {
  if [ -e /run/opengl-drivers ]; then
    echo sorry, your system appears to contain /run/opengl-drivers.
    echo this script is not intended for systems using that directory.
    echo if you wish to use this script, please backup the contents
    echo of /run/opengl-drivers and then remove it from your system. thank you
    exit
  fi
  if [ ! $IN_NIX_SHELL ]; then
    echo sorry, this needs to be run from within nix-shell environment. exiting.
    exit
  fi
  if [ ! $1 ]; then
    echo please read top of $0 if you want to use this script directly.
    exit
  fi
  if [ ! $2 ]; then
    echo please read top of $0 if you want to use this script directly.
    exit
  fi
  if [ ! "`command -v patchelf`" ]; then
    echo sorry, this script, $0, needs patchelf in your PATH. exiting.
    exit
  fi
  if [ ! "`command -v readlink`" ]; then
    echo sorry, this script, $0, needs readlink in your PATH. exiting.
    exit
  fi
  if [ ! "`command -v glxinfo`" ]; then
    echo sorry, this script, $0, needs System glxinfo in your PATH. exiting.
    exit
  fi
  if [ "`which glxinfo | grep nix.store`" ]; then
    echo sorry, this script, $0 needs system glxinfo in your PATH. but
    echo it appears your glxinfo is from Nix. please use a clean shell.
    exit
  fi
  if [ ! "`command -v dirname`" ]; then
    echo sorry, this script, $*, needs dirname command in your PATH. exiting.
    exit
  fi
  if [ ! "`command -v basename`" ]; then
    echo sorry, this script, $0, needs the basename command in your PATH. exiting.
    exit
  fi
  if [ ! "`command -v strace`" ]; then
    echo sorry, this script, $0, needs the strace command in your PATH. exiting.
    exit
  fi
  if [ ! "`command -v $LDD_FULLEXEC`" ]; then
    echo LDD_FULLEXEC was $LDD_FULLEXEC
    echo sorry, this script, $0, needs ldd passed as second argument. exiting.
    exit
  fi
}

log_executables() {
  gllog=$1
  echo "executables:  "                        >> $gllog
  echo " glxinfo      "`which glxinfo`         >> $gllog
  echo " ldd          "$LDD_FULLEXEC           >> $gllog
  echo " strace       "`which strace`          >> $gllog
  echo " stat         "`which stat`            >> $gllog
  echo " chmod        "`which chmod`           >> $gllog
  echo " readlink     "`which readlink`        >> $gllog
  echo " dirname      "`which dirname`         >> $gllog
  echo " basename     "`which basename`        >> $gllog
  echo " patchelf     "`which patchelf`        >> $gllog
  echo " cp           "`which cp`              >> $gllog
  echo " ln           "`which ln`              >> $gllog
  echo " [            "`which [`               >> $gllog
  echo "" >> $gllog
}

find_driver_used_by_glxinfo() {
  # this attempts to parse debug output of glxinfo with the LIBGL_DEBUG=verbose
  # environment variable, in order to find which DRI driver file it loads.
  # Underneath, glxinfo is using Mesa's extremely complicated chip detection
  # code, much of it under Mesa's "loader" subsystem.
  # Here is example output for Ubuntu 16 linux system using Intel(tm) 3d chip:
  # libGL: OpenDriver: trying /usr/lib/x86_64-linux-gnu/dri/i965_dri.so

  save_libgldebug=$LIBGL_DEBUG
  LIBGL_DEBUG=verbose
  export LIBGL_DEBUG
  glxinfo_debug_log=$1/kludgegl-glxinfo-debug.txt
  echo "------------" >> $glxinfo_debug_log
  run_glxinfo $glxinfo_debug_log
  LIBGL_DEBUG=$save_libgldebug

  if [ ! -e $glxinfo_debug_log ]; then
    echo glxinfo produced no logfile. please run under an X11 session
    echo where glxinfo runs properly.
    exit
  fi
  if [ ! "`cat $glxinfo_debug_log | head -1 | awk ' { print $1 } '`" ]; then
    echo glxinfo log was empty.
    echo please try running under an X environment where glxinfo works properly.
    exit
  fi
  if [ "`cat $glxinfo_debug_log | head -1 | grep -i error`" ]; then
    echo glxinfo gave an error. please run under an X11 session
    echo where glxinfo runs properly.
    exit
  fi
  drilines1=`cat $logfile | grep -i ^libGL.*opendriver | tail -1`
  drifilepath=`echo $drilines1 | awk ' { print $4 } '`
  echo $drifilepath
}

find_libudev_used_by_glxinfo() {
  glxi_udevlog=$1/kludgegl-glxinfo-libudev.txt
  run_glxinfo $glxi_udevlog strace -f
  udevpath=`cat $glxi_udevlog | grep "open.*libudev.so.*5" | tail -1 | sed s/\"/\ /g | awk ' { print $2 } '`
  echo $udevpath
}

find_shlibs() {
  start_libfile=$1
  ldd_logfile=$2/kludgegl-ldd-log.txt
  saved_permissions=`stat -c%a $start_libfile`
  chmod u+x $start_libfile
  echo $LDD_FULLEXEC > $ldd_logfile
  $LDD_FULLEXEC $start_libfile >> $ldd_logfile
  shlibs=`cat $ldd_logfile | grep "=>" | awk ' { print $3 } ' `
  chmod $saved_permissions $start_libfile
  fs_result=
  for filenm in `echo $shlibs`; do
    if [ -e $filenm ]; then
      fs_result=$fs_result" "$filenm
    fi
  done
  echo $fs_result
}

install_under_specialdir() {
  original_path=$1
  target_dir=$2
  target_fname=`basename $original_path`
  target_path=$target_dir/$target_fname
  if [ ! -d $target_dir ]; then
    mkdir -p $target_dir
  fi

  original_deref_path=`readlink -f $original_path`
  target_deref_fname=`basename $original_deref_path`
  target_deref_path=$target_dir/$target_deref_fname
  if [ -L $original_path ]; then
    if [ ! -e $target_path ]; then
      ln -s $target_deref_fname $target_path
    fi
    if [ ! -e $target_deref_path ]; then
      cp $original_path $target_deref_path
    fi
  else
    if [ ! -e $target_path ]; then
      cp $original_path $target_path
    fi
  fi

  saved_permissions=`stat -c%a $target_deref_path`
  chmod u+w $target_deref_path
  patchelf_log=$NIX_KLUDGE_GL_DIR/kludgegl-patchelf-log.txt
  echo $target_deref_path >> $patchelf_log
  set +e
  patchelf --set-rpath $NIX_KLUDGE_GL_DIR $target_deref_path 2>> $patchelf_log 1>>$patchelf_log
  set -e
  chmod $saved_permissions $target_deref_path
}

install_so_file_and_deps() {
  SO_FILEPATH=$1
  DEST_DIR=$2
  DEPLIST_LOGFILE=$3
  install_under_specialdir $SO_FILEPATH $DEST_DIR
  NEW_SO_FILEPATH=$DEST_DIR/`basename $SO_FILEPATH`

  dep_libs=$(find_shlibs $NEW_SO_FILEPATH $DEST_DIR)
  echo "" > $DEPLIST_LOGFILE
  for filenm in $dep_libs ; do
    echo $filenm >> $DEPLIST_LOGFILE
  done
  for deplib in `cat $DEPLIST_LOGFILE | sort` ; do
    install_under_specialdir $deplib $DEST_DIR
  done
}


if [ $SUPERDEBUG_NGL ]; then
  set -e
  set -x
fi

# export DISPLAY=:0 # for testing obscure systems

NIX_KLUDGE_GL_DIR=$1
LDD_FULLEXEC=$2

verify_script_deps $*

NIX_KLUDGE_GL_DIR=`readlink -f $NIX_KLUDGE_GL_DIR`
LDD_FULLEXEC=`readlink -f $LDD_FULLEXEC`

if [ -d $NIX_KLUDGE_GL_DIR ]; then
  # prevent disasters
  if [ "`echo $NIX_KLUDGE_GL_DIR| grep $PWD`" ]; then
    rm -f $NIX_KLUDGE_GL_DIR/*
    rmdir $NIX_KLUDGE_GL_DIR
  else
    echo please use a target directory that is under present directory $PWD
    exit
  fi
fi

mkdir -p $NIX_KLUDGE_GL_DIR

gllog=$NIX_KLUDGE_GL_DIR/kludgegl-setup-info.txt
log_executables $gllog

echo "finding and copying DRI driver .so file + dependencies"
SYS_DRI_SO_FILEPATH=$(find_driver_used_by_glxinfo $NIX_KLUDGE_GL_DIR)
DEPLIST=$1/kludgegl-driver-deplist.txt
install_so_file_and_deps $SYS_DRI_SO_FILEPATH $NIX_KLUDGE_GL_DIR $DEPLIST

echo "finding and copying swrast DRI driver .so file + dependencies"
if [ ! $LIBGL_ALWAYS_SOFTWARE ]; then
  LIBGL_ALWAYS_SOFTWARE=1
  export LIBGL_ALWAYS_SOFTWARE
  SYS_SWRAST_DRI_SO_FILEPATH=$(find_driver_used_by_glxinfo $NIX_KLUDGE_GL_DIR)
  DEPLIST=$1/kludgegl-driver-swrast-deplist.txt
  install_so_file_and_deps $SYS_SWRAST_DRI_SO_FILEPATH $NIX_KLUDGE_GL_DIR $DEPLIST
  LIBGL_ALWAYS_SOFTWARE=
  export LIBGL_ALWAYS_SOFTWARE
fi

echo "if necessary, copying libudev (for older versions of Mesa libGL.so)"
SYS_LIBUDEV_FILEPATH=$(find_libudev_used_by_glxinfo $NIX_KLUDGE_GL_DIR)
if [ $SYS_LIBUDEV_FILEPATH ]; then
  DEPLIST=$1/kludgegl-libudev-deplist.txt
  install_so_file_and_deps $SYS_LIBUDEV_FILEPATH $NIX_KLUDGE_GL_DIR $DEPLIST
fi

echo "Completing log" $gllog

echo "System SWRAST DRI driver: "$SYS_SWRAST_DRI_SO_FILEPATH >> $gllog
echo "System DRI driver:   "$SYS_DRI_SO_FILEPATH    >> $gllog
echo "rpaths of .so in $NIX_KLUDGE_GL_DIR:"   >> $gllog
for file in $NIX_KLUDGE_GL_DIR/*so*; do
  if [ ! -L $file ]; then
    echo "" >> $gllog
    echo `basename $file`":" >> $gllog
    patchelf --print-rpath $file 2>&1 | tee >> $gllog
  fi
done


if [ $SUPERDEBUG_NGL ]; then
  set +x
  set +e
fi


