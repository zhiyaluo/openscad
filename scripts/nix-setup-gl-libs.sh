# This is a helper script for using OpenGL(TM) drivers when OpenSCAD is
# built under the Nix packaging system.
#
# As of 2017 Nix did not include simple GL setup, so this script
# is a workaround.
#
# To use:
#
#  Don't. This script is normally called from scripts/nixshell-run.sh
#
# To test: (Keep in mind things like ldd, patchelf, differ when testing)
#          (Because nix has its own version of many of these items)
#
#  /openscad/bin$ IN_NIX_SHELL=1 ../scripts/nix-setup-gl-libs.sh ./testgldir /usr/bin/ldd
#
# To test with software rendering:
#
#  /openscad/bin$ LIBGL_ALWAYS_SOFTWARE=1 IN_NIX_SHELL=1 ../scripts/nix-setup-gl-libs.sh ./testdir /usr/bin/ldd
#
# Theory:
#
# We need OpenSCAD to build against Nix, but Nix doesn't come with DRI
# GL graphics drivers. There is no simple way to tell Nixs libGL.so how
# to load these drivers, since Nix uses a specially modified program
# linker and dynamic object loader (ld-linux.so) than the system itself.
# The DRI files depend on many .so libraries that Nix's loader cannot easily
# find or work with.
#
# Therefore, we find the DRI drivers ourselves, copy them to a subfolder,
# find their dependency .so files, copy them as well to the same subfolder,
# patchelf all their rpaths, and tell Nix libGL to use our special copies.
# Then Nix libGL.so will dlopen() our special copies of the drivers,
# and hopefully their dependencies wont conflict with Nix's.
#
# See Also
# https://github.com/NixOS/nixpkgs/issues/9415#issuecomment-170661702
# https://grahamwideman.wordpress.com/2009/02/09/the-linux-loader-and-how-it-finds-libraries/
# http://www.airs.com/blog/archives/38
# http://www.airs.com/blog/archives/39
# http://www.airs.com/blog/archives/ (up to 50)
# https://anonscm.debian.org/git/pkg-xorg/lib/mesa.git/tree/docs/libGL.txt
# https://anonscm.debian.org/git/pkg-xorg/lib/mesa.git/tree/src/loader/
# https://github.com/deepfire/nix-install-vendor-gl
# https://nixos.org/patchelf.html
# https://en.wikipedia.org/wiki/Direct_Rendering_Manager
# rpath, mmap, strace, shared libraries, linkers, loaders
# https://unix.stackexchange.com/questions/97676/how-to-find-the-driver-module-associated-with-a-device-on-linux
# https://stackoverflow.com/questions/5103443/how-to-check-what-shared-libraries-are-loaded-at-run-time-for-a-given-process
# sudo cat /proc/$Xserverprocessid/maps | grep dri
# sudo lsof -p $Xserverprocessid | grep dri
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
  kill $glxinfopid
  set -e
}

verify_script_deps() {
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
  if [ ! "`command -v glxinfo`" ]; then
    echo sorry, this script, $0, needs glxinfo in your PATH. exiting.
    exit
  fi
  if [ "`which glxinfo | grep nix.store`" ]; then
    echo sorry, this script, $0, needs system glxinfo in your PATH. but
    echo it appears your glxinfo is from Nix. please use a clean shell.
    exit
  fi
  if [ ! -d $1 ]; then
    mkdir -p $1
  fi
  if [ ! "`command -v dirname`" ]; then
    echo sorry, this script, $*, needs dirname command. exiting.
    exit
  fi
  if [ ! "`command -v basename`" ]; then
    echo sorry, this script, $*, needs the basename command. exiting.
    exit
  fi
  if [ ! "`command -v strace`" ]; then
    echo sorry, this script, $*, needs the strace command. exiting.
    exit
  fi
  if [ ! "`command -v $LDD_FULLEXEC`" ]; then
    echo sorry, this script, $*, needs ldd. exiting.
    exit
  fi
}

find_driver_used_by_glxinfo() {
  # this attempts to parse the last line of glxinfo OpenDriver search output.
  # example for system using Intel(tm) 3d graphics chip:
  # libGL: OpenDriver: trying /usr/lib/x86_64-linux-gnu/dri/i965_dri.so

  save_libgldebug=$LIBGL_DEBUG
  LIBGL_DEBUG=verbose
  export LIBGL_DEBUG
  glxinfo_debug_log=$1/oscd-glxinfo-debug.txt
  if [ -e $glxinfo_debug_log ]; then
    rm $glxinfo_debug_log
  fi
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
  glxi_udevlog=$1/oscd-glxinfo-libudev.txt
  run_glxinfo $glxi_udevlog strace -f
  udevpath=`cat $glxi_udevlog | grep "open.*libudev.so.*5" | tail -1 | sed s/\"/\ /g | awk ' { print $2 } '`
  echo $udevpath
}

find_shlibs() {
  find_shlib=$1
  ldd_logfile=$2/oscd-ldd-log.txt
  saved_permissions=`stat -c%a $find_shlib`
  chmod u+x $find_shlib
  echo $LDD_FULLEXEC > $ldd_logfile
  $LDD_FULLEXEC $find_shlib >> $ldd_logfile
  shlibs=`cat $ldd_logfile | grep "=>" | grep -v "vdso.so" | awk ' { print $3 } ' `
  chmod $saved_permissions $find_shlib
  echo $shlibs
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
      ln -s $target_deref_path $target_path
    fi
    if [ ! -e $target_deref_path ]; then
      cp -v $original_path $target_deref_path
    fi
  else
    if [ ! -e $target_path ]; then
      cp -v $original_path $target_path
    fi
  fi

  saved_permissions=`stat -c%a $target_deref_path`
  chmod u+w $target_deref_path
  patchelf --set-rpath $OSCD_NIXGL_DIR $target_deref_path
  chmod $saved_permissions $target_deref_path
}

install_so_file_and_deps() {
  SO_FILEPATH=$1
  DEST_DIR=$2
  DEPLIST_FILE=$3
  install_under_specialdir $SO_FILEPATH $DEST_DIR
  NEW_SO_FILEPATH=$DEST_DIR/`basename $SO_FILEPATH`

  dep_libs=$(find_shlibs $NEW_SO_FILEPATH $DEST_DIR)
  echo "" > $DEPLIST_FILE
  for filenm in $dep_libs ; do
    echo $filenm >> $DEPLIST_FILE
  done
  for deplib in `cat $DEPLIST_FILE | sort` ; do
    install_under_specialdir $deplib $DEST_DIR
  done
}



set -e
set -x

# export DISPLAY=:0 # for testing obscure systems

#OSCD_NIXGL_DIR=/run/opengl-driver/lib/dri # Nix's version of the world
#OSCD_NIXGL_DIR=$PWD/__oscd_nix_gl__/dri   # as called by nixshell-run.sh
OSCD_NIXGL_DIR=`readlink -f $1`
LDD_FULLEXEC=`readlink -f $2`

if [ -d $OSCD_NIXGL_DIR ]; then
  # prevent disasters
  if [ "`echo $OSCD_NIXGL_DIR| grep $PWD`" ]; then
    rm -f $OSCD_NIXGL_DIR/*
    rmdir $OSCD_NIXGL_DIR
  else
    echo please use an openscad_nixgl_dir under present directory $PWD
    exit
  fi
fi

verify_script_deps $*

gllog=$OSCD_NIXGL_DIR/oscd-gl-setup-info.txt
echo "" > $gllog

SYS_DRI_SO_FILEPATH=$(find_driver_used_by_glxinfo $OSCD_NIXGL_DIR)
DEPLIST=$1/oscd-driver-deplist.txt
install_so_file_and_deps $SYS_DRI_SO_FILEPATH $OSCD_NIXGL_DIR $DEPLIST

# older versions of Mesa depend on dlopen(libudev) to find the DRI driver.
SYS_LIBUDEV_FILEPATH=$(find_libudev_used_by_glxinfo $OSCD_NIXGL_DIR)
if [ $SYS_LIBUDEV_FILEPATH ]; then
  DEPLIST=$1/oscd-libudev-deplist.txt
  install_so_file_and_deps $SYS_LIBUDEV_FILEPATH $OSCD_NIXGL_DIR $DEPLIST
fi

echo "DRI driver "$SYS_DRI_SO_FILEPATH  >> $gllog
echo "glxinfo    "`which glxinfo`       >> $gllog
echo "ldd        "$LDD_FULLEXEC         >> $gllog
echo "rpaths of .so in $OSCD_NIXGL_DIR" >> $gllog
for file in $OSCD_NIXGL_DIR/*so*; do
  if [ ! -L $file ]; then
    echo " "`basename $file` `patchelf --print-rpath $file` >> $gllog
  fi
done
set +x
set +e


