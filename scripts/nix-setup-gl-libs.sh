# This is a helper script for using OpenGL(TM) drivers when OpenSCAD is
# built under the Nix packaging system.
#
# As of 2017 Nix did not include simple GL setup, so this script
# is a workaround.
#
# To use:
#
#  don't. It is normally called from scripts/nixshell-run.sh
#
# To test: (Keep in mind things like ldd, patchelf, differ when testing)
#          (Because nix has its own version of many of these items)
#
#  /openscad/bin$ IN_NIX_SHELL=1 ../scripts/nix-setup-gl-libs.sh ./testgldir
#
# To test with software rendering:
#
#  /openscad/bin$ LIBGL_ALWAYS_SOFTWARE=1 IN_NIX_SHELL=1 ../scripts/nix-setup-gl-libs.sh ./testdir
#
# Theory:
#
# The main thing we need is for Nix's libGL.so to call our system proper
# DRI graphics driver. Distros typically ship with opensource drivers
# created by the Mesa project, with names like i965_dri.so,
# radeon_dri.so, etc, usually deep under /usr/lib or /lib.
#
# To determine the proper DRI driver without root access is
# extraordinarily complex, so we use Mesa to find it for us, by running
# LIBGL_DEBUG=verbose glxinfo and looking at which driver it ran open() on.
#
# Then we copy the driver, and all it's dependency .so files, to a
# subdir, called __oscd_nix_gl__. We patchelf the rpath of this copy of
# the driver, and the copies of its dependencies, to point to this same
# subdir, so they dont need LD_LIBRARY_PATH to find their deps at runtime.
#
# Lastly, we take advantage of libGL.so feature called LIBGL_DRIVERS_DIR
# so that we can tell Nix's version of libGL.so where to find the special
# copy of the DRI driver we just created.
#
# Now since Nix's libGL.so will load our special copy of the DRI driver,
# which will in turn load the special copies of its dependency libraries
# from it's rpath, which is our __oscd_nix_gl__ dir. Therefore it wont
# interefer with Nix.
#
# In theory
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
  log=$1
  $prefix glxinfo &> $log &
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
    echo this script is usually run from openscad/scripts/nixshell-run.sh
    echo if you are working on this script itself, run like so:
    echo IN_NIX_SHELL=1 $0 /tmp/nixsetupgl
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
  testlog=$1/oscd-glxinfo-test.txt
  if [ -e $testlog ]; then
    rm $testlog
  fi
  run_glxinfo $testlog
  if [ ! "`cat $testlog`" ]; then
    echo glxinfo appears to be broken. please run under an X11 session
    echo where glxinfo runs properly.
    exit
  fi
  if [ "`cat $testlog | head -1 | grep -i error`" ]; then
    echo glxinfo gave an error. please run under an X11 session
    echo where glxinfo runs properly.
    exit
  fi
  if [ ! "`command -v dirname`" ]; then
    echo sorry, this script, $*, needs dirname. exiting.
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
  logfile=$1/oscd-glxinfo-debug.txt
  run_glxinfo $logfile
  LIBGL_DEBUG=$save_libgldebug
  if [ ! "`cat $logfile | head -1 | awk ' { print $1 } '`" ]; then
    echo glxinfo appears to have failed to run properly. logfile empty.
    echo please try running under an X environment where glxinfo works properly.
    exit
  fi
  drilines1=`cat $logfile | grep -i ^libGL.*opendriver | tail -1`
  drifilepath=`echo $drilines1 | awk ' { print $4 } '`
  echo $drifilepath
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
    ln -s $target_deref_path $target_path
    cp -v $original_path $target_deref_path
  else
    cp -v $original_path $target_path
  fi

  saved_permissions=`stat -c%a $target_deref_path`
  chmod u+w $target_deref_path
  patchelf --set-rpath $OSCD_NIXGL_DIR $target_deref_path
  chmod $saved_permissions $target_deref_path
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

SYS_DRI_SO_FILEPATH=$(find_driver_used_by_glxinfo $OSCD_NIXGL_DIR)
install_under_specialdir $SYS_DRI_SO_FILEPATH $OSCD_NIXGL_DIR
driverlist=$1/oscd-gldriver-deplist.txt
if [ -e $driverlist ]; then rm $driverlist; fi
NEW_DRI_SO_FILEPATH=$OSCD_NIXGL_DIR/`basename $SYS_DRI_SO_FILEPATH`
driver_dep_libs=$(find_shlibs $NEW_DRI_SO_FILEPATH $OSCD_NIXGL_DIR)
for filenm in $driver_dep_libs ; do
  echo $filenm >> $driverlist
done

for driver_deplib in `cat $driverlist | sort` ; do
  install_under_specialdir $driver_deplib $OSCD_NIXGL_DIR
done

set +x
set +e


