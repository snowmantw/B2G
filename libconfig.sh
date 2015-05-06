#!/bin/bash

prompt_help() {
	echo "Usage: $0 [-cdflnq --shallow --retry <Num>] (device name)"
	echo "Flags are passed through to |./repo sync|."
	echo
	echo Valid devices to configure are:
	echo - galaxy-s2
	echo - galaxy-nexus
	echo - nexus-4
	echo - nexus-4-kk
	echo - nexus-5
	echo - nexus-5-l
	echo - nexus-s
	echo - nexus-s-4g
	echo - flo "(Nexus 7 2013)"
	echo - otoro
	echo - unagi
	echo - inari
	echo - keon
	echo - peak
	echo - leo
	echo - hamachi
	echo - helix
	echo - tarako
	echo - dolphin
	echo - dolphin-512
	echo - pandaboard
	echo - vixen
	echo - flatfish
	echo - flame
	echo - flame-kk
	echo - rpi "(Revision B)"
	echo - shinano
	echo - aries
	echo - emulator
	echo - emulator-jb
	echo - emulator-kk
	echo - emulator-l
	echo - emulator-x86
	echo - emulator-x86-jb
	echo - emulator-x86-kk
	echo - emulator-x86-l
}

prompt_repo_sync_fail() {
  if [ $FLAG_USER_INTERRUPTED == true ]; then
    echo "Repo sync failed: user stopped it"
  else
    echo "Repo sync failed"
  fi
}


# $1: device name
# $2: the customized branch
set_customized_branch() {
  GIT_TEMP_REPO="tmp_manifest_repo"
  GITREPO=$GIT_TEMP_REPO
  rm -rf $GITREPO &&
  git init $GITREPO &&
  cp $2 $GITREPO/$1.xml &&
  cd $GITREPO &&
  git add $1.xml &&
  git commit -m "manifest" &&
  git branch -m $BRANCH &&
  cd ..
}

# $1: device name
write_tmp_config() {
  local DEVICE_NAME=$1
  echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) > .tmp-config
  echo GECKO_OBJDIR=$PWD/objdir-gecko >> .tmp-config
  echo "$DEVICE_NAME" >> .tmp-config
  case "$DEVICE_NAME" in
  "galaxy-s2")
    echo DEVICE=galaxys2 >> .tmp-config &&
    CONFIG_NAME="$DEVICE_NAME"
    ;;

  "galaxy-nexus")
    echo DEVICE=maguro >> .tmp-config &&
    CONFIG_NAME="$DEVICE_NAME"
    ;;

  "nexus-4"|"nexus-4-kk")
    echo DEVICE=mako >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "nexus-5"|"nexus-5-")
    echo DEVICE=hammerhead >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "nexus-s")
    echo DEVICE=crespo >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "nexus-s-4g")
    echo DEVICE=crespo4g >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "otoro"|"unagi"|"keon"|"inari"|"leo"|"hamachi"|"peak"|"helix"|"wasabi"|"flatfish")
    echo DEVICE=$1 >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "flame"|"flame-kk")
    echo PRODUCT_NAME=flame >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "tarako")
    echo DEVICE=sp6821a_gonk >> .tmp-config &&
    echo PRODUCT_NAME=sp6821a_gonk >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "dolphin")
    echo DEVICE=scx15_sp7715ga >> .tmp-config &&
    echo PRODUCT_NAME=scx15_sp7715gaplus >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "dolphin-512")
    echo DEVICE=scx15_sp7715ea >> .tmp-config &&
    echo PRODUCT_NAME=scx15_sp7715eaplus >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "pandaboard")
    echo DEVICE=panda >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "vixen")
    echo DEVICE=vixen >> .tmp-config &&
    echo PRODUCT_NAME=vixen >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;  

  "emulator"|"emulator-jb"|"emulator-kk"|"emulator-l")
    echo DEVICE=generic >> .tmp-config &&
    echo LUNCH=full-eng >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "emulator-x86"|"emulator-x86-jb"|"emulator-x86-kk"|"emulator-x86-l")
    echo DEVICE=generic_x86 >> .tmp-config &&
    echo LUNCH=full_x86-eng >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "flo")
    echo DEVICE=flo >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "rpi")
    echo PRODUCT_NAME=rpi >> .tmp-config &&
    CONFIG_NAME=$DEVICE_NAME
    ;;

  "shinano")
    echo PRODUCT_NAME=shinano >> .tmp-config &&
    CONFIG_NAME="shinao"
    ;;

  "aries")
    echo PRODUCT_NAME=aries >> .tmp-config &&
    CONFIG_NAME="aries"
    ;;
  *)
    exit -1
    ;;
  esac
  # For debugging and DRY reason we collect all we could collect,
  # and we "return" it when it's in a subprocess.
  echo "$CONFIG_NAME"
}

do_repo_sync() {
  local depth_option=""
  if [ $OPTION_SHALLOW_CLONE == true ]; then
    depth_option="--depth=1"
  fi
  rm -rf .repo/manifest* &&
  $REPO init -u $GITREPO -b $BRANCH -m $1.xml $REPO_INIT_FLAGS $depth_option &&
  $REPO sync $sync_flags $REPO_SYNC_FLAGS
}

handle_interrupt() {
  FLAG_USER_INTERRUPTED=true
}

# $1: the config
# $2: the retry max
repo_sync() {
  trap handle_interrupt INT
  local retry_max=$OPTION_RETRY_MAX
  # if no such argument, we need to at least execute it once.
  if [ $((retry_max)) == 0 ]; then
    retry_max=1
  fi
  local retry_count=0
  local ret=-1
  while [ $FLAG_USER_INTERRUPTED != true ] && \
        [ $((ret)) != 0 ] && [ $((retry_max)) != $((retry_count)) ]
  do
    do_repo_sync $1
    ret=$?
    retry_count=$(($retry_count+1))
  done
  if [ $ret -ne 0 ]; then
    prompt_repo_sync_fail
    exit -1
  fi
}

get_cpu_core() {
  case `uname` in
  "Darwin")
    # Should also work on other BSDs
    CORE_COUNT=`sysctl -n hw.ncpu`
    ;;
  "Linux")
    CORE_COUNT=`grep processor /proc/cpuinfo | wc -l`
    ;;
  *)
    echo Unsupported platform: `uname`
    exit -1
  esac
}

