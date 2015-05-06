#!/bin/bash

## Main script ##

# include all functions
source "libconfig.sh"

# define these variables here so we know how many global
# variables would be used.
OPTION_RETRY_MAX=0
OPTION_SHALLOW_CLONE=false
FLAG_USER_INTERRUPTED=false
REPO=${REPO:-./repo}
GITREPO=${GITREPO:-"git://github.com/mozilla-b2g/b2g-manifest"}
BRANCH=${BRANCH:-master}
sync_flags=""

get_cpu_core

while [ $# -ge 1 ]; do
	case $1 in
	-d|-l|-f|-n|-c|-q|-j*)
		sync_flags="$sync_flags $1"
		if [ $1 = "-j" ]; then
			shift
			sync_flags+=" $1"
		fi
		shift
		;;
	--help|-h)
    prompt_help
    exit 0
		;;
  --shallow)
    OPTION_SHALLOW_CLONE=true
    shift
    ;;
  --retry)
    shift
    OPTION_RETRY_MAX=$1
    OPTION_RETRY_MAX=$((OPTION_RETRY_MAX))
    if [ $OPTION_RETRY_MAX == 0 ]; then
      echo "--retry: should come with a number > 0"
      exit 1
    fi
    shift
    ;;
	-*)
		echo "$0: unrecognized option $1" >&2
		exit 1
		;;
	*)
		break
		;;
	esac
done

DEVICE_NAME=$1
CUSTOMIZED_BRANCH=$2

if [ -n "$CUSTOMIZED_BRANCH" ]; then
  set_customized_branch $DEVICE_NAME $CUSTOMIZED_BRANCH
fi

config=$(write_tmp_config $DEVICE_NAME)
result=$?
if [ $((result)) != 0 ]; then
  prompt_help
  exit -1
fi
repo_sync $config
if [ $? -ne 0 ]; then
	echo Configuration failed
	exit -1
fi

mv .tmp-config .config
echo Run \|./build.sh\| to start building

