#!/bin/sh

PROGRESS_CURR=0
PROGRESS_TOTAL=1839                        

# This file was autowritten by rmlint
# rmlint was executed from: /home/hugo/dotfiles/
# Your command line was: rmlint /home/hugo

RMLINT_BINARY="/usr/bin/rmlint"

# Only use sudo if we're not root yet:
# (See: https://github.com/sahib/rmlint/issues/27://github.com/sahib/rmlint/issues/271)
SUDO_COMMAND="sudo"
if [ "$(id -u)" -eq "0" ]
then
  SUDO_COMMAND=""
fi

USER='hugo'
GROUP='hugo'

# Set to true on -n
DO_DRY_RUN=

# Set to true on -p
DO_PARANOID_CHECK=

# Set to true on -r
DO_CLONE_READONLY=

# Set to true on -q
DO_SHOW_PROGRESS=true

# Set to true on -c
DO_DELETE_EMPTY_DIRS=

# Set to true on -k
DO_KEEP_DIR_TIMESTAMPS=

# Set to true on -i
DO_ASK_BEFORE_DELETE=

##################################
# GENERAL LINT HANDLER FUNCTIONS #
##################################

COL_RED='[0;31m'
COL_BLUE='[1;34m'
COL_GREEN='[0;32m'
COL_YELLOW='[0;33m'
COL_RESET='[0m'

print_progress_prefix() {
    if [ -n "$DO_SHOW_PROGRESS" ]; then
        PROGRESS_PERC=0
        if [ $((PROGRESS_TOTAL)) -gt 0 ]; then
            PROGRESS_PERC=$((PROGRESS_CURR * 100 / PROGRESS_TOTAL))
        fi
        printf '%s[%3d%%]%s ' "${COL_BLUE}" "$PROGRESS_PERC" "${COL_RESET}"
        if [ $# -eq "1" ]; then
            PROGRESS_CURR=$((PROGRESS_CURR+$1))
        else
            PROGRESS_CURR=$((PROGRESS_CURR+1))
        fi
    fi
}

handle_emptyfile() {
    print_progress_prefix
    echo "${COL_GREEN}Deleting empty file:${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        rm -f "$1"
    fi
}

handle_emptydir() {
    print_progress_prefix
    echo "${COL_GREEN}Deleting empty directory: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        rmdir "$1"
    fi
}

handle_bad_symlink() {
    print_progress_prefix
    echo "${COL_GREEN} Deleting symlink pointing nowhere: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        rm -f "$1"
    fi
}

handle_unstripped_binary() {
    print_progress_prefix
    echo "${COL_GREEN} Stripping debug symbols of: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        strip -s "$1"
    fi
}

handle_bad_user_id() {
    print_progress_prefix
    echo "${COL_GREEN}chown ${USER}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chown "$USER" "$1"
    fi
}

handle_bad_group_id() {
    print_progress_prefix
    echo "${COL_GREEN}chgrp ${GROUP}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chgrp "$GROUP" "$1"
    fi
}

handle_bad_user_and_group_id() {
    print_progress_prefix
    echo "${COL_GREEN}chown ${USER}:${GROUP}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chown "$USER:$GROUP" "$1"
    fi
}

###############################
# DUPLICATE HANDLER FUNCTIONS #
###############################

check_for_equality() {
    if [ -f "$1" ]; then
        # Use the more lightweight builtin `cmp` for regular files:
        cmp -s "$1" "$2"
        echo $?
    else
        # Fallback to `rmlint --equal` for directories:
        "$RMLINT_BINARY" -p --equal  "$1" "$2"
        echo $?
    fi
}

original_check() {
    if [ ! -e "$2" ]; then
        echo "${COL_RED}^^^^^^ Error: original has disappeared - cancelling.....${COL_RESET}"
        return 1
    fi

    if [ ! -e "$1" ]; then
        echo "${COL_RED}^^^^^^ Error: duplicate has disappeared - cancelling.....${COL_RESET}"
        return 1
    fi

    # Check they are not the exact same file (hardlinks allowed):
    if [ "$1" = "$2" ]; then
        echo "${COL_RED}^^^^^^ Error: original and duplicate point to the *same* path - cancelling.....${COL_RESET}"
        return 1
    fi

    # Do double-check if requested:
    if [ -z "$DO_PARANOID_CHECK" ]; then
        return 0
    else
        if [ "$(check_for_equality "$1" "$2")" -ne "0" ]; then
            echo "${COL_RED}^^^^^^ Error: files no longer identical - cancelling.....${COL_RESET}"
            return 1
        fi
    fi
}

cp_symlink() {
    print_progress_prefix
    echo "${COL_YELLOW}Symlinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            # replace duplicate with symlink
            rm -rf "$1"
            ln -s "$2" "$1"
            # make the symlink's mtime the same as the original
            touch -mr "$2" -h "$1"
        fi
    fi
}

cp_hardlink() {
    if [ -d "$1" ]; then
        # for duplicate dir's, can't hardlink so use symlink
        cp_symlink "$@"
        return $?
    fi
    print_progress_prefix
    echo "${COL_YELLOW}Hardlinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            # replace duplicate with hardlink
            rm -rf "$1"
            ln "$2" "$1"
        fi
    fi
}

cp_reflink() {
    if [ -d "$1" ]; then
        # for duplicate dir's, can't clone so use symlink
        cp_symlink "$@"
        return $?
    fi
    print_progress_prefix
    # reflink $1 to $2's data, preserving $1's  mtime
    echo "${COL_YELLOW}Reflinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            touch -mr "$1" "$0"
            if [ -d "$1" ]; then
                rm -rf "$1"
            fi
            cp --archive --reflink=always "$2" "$1"
            touch -mr "$0" "$1"
        fi
    fi
}

clone() {
    print_progress_prefix
    # clone $1 from $2's data
    # note: no original_check() call because rmlint --dedupe takes care of this
    echo "${COL_YELLOW}Cloning to: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        if [ -n "$DO_CLONE_READONLY" ]; then
            $SUDO_COMMAND $RMLINT_BINARY --dedupe  --dedupe-readonly "$2" "$1"
        else
            $RMLINT_BINARY --dedupe  "$2" "$1"
        fi
    fi
}

skip_hardlink() {
    print_progress_prefix
    echo "${COL_BLUE}Leaving as-is (already hardlinked to original): ${COL_RESET}$1"
}

skip_reflink() {
    print_progress_prefix
    echo "${COL_BLUE}Leaving as-is (already reflinked to original): ${COL_RESET}$1"
}

user_command() {
    print_progress_prefix

    echo "${COL_YELLOW}Executing user command: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        # You can define this function to do what you want:
        echo 'no user command defined.'
    fi
}

remove_cmd() {
    print_progress_prefix
    echo "${COL_YELLOW}Deleting: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            if [ -n "$DO_KEEP_DIR_TIMESTAMPS" ]; then
                touch -r "$(dirname "$1")" "$STAMPFILE"
            fi
            if [ -n "$DO_ASK_BEFORE_DELETE" ]; then
              rm -ri "$1"
            else
              rm -rf "$1"
            fi
            if [ -n "$DO_KEEP_DIR_TIMESTAMPS" ]; then
                # Swap back old directory timestamp:
                touch -r "$STAMPFILE" "$(dirname "$1")"
                rm "$STAMPFILE"
            fi

            if [ -n "$DO_DELETE_EMPTY_DIRS" ]; then
                DIR=$(dirname "$1")
                while [ ! "$(ls -A "$DIR")" ]; do
                    print_progress_prefix 0
                    echo "${COL_GREEN}Deleting resulting empty dir: ${COL_RESET}$DIR"
                    rmdir "$DIR"
                    DIR=$(dirname "$DIR")
                done
            fi
        fi
    fi
}

original_cmd() {
    print_progress_prefix
    echo "${COL_GREEN}Keeping:  ${COL_RESET}$1"
}

##################
# OPTION PARSING #
##################

ask() {
    cat << EOF

This script will delete certain files rmlint found.
It is highly advisable to view the script first!

Rmlint was executed in the following way:

   $ rmlint /home/hugo

Execute this script with -d to disable this informational message.
Type any string to continue; CTRL-C, Enter or CTRL-D to abort immediately
EOF
    read -r eof_check
    if [ -z "$eof_check" ]
    then
        # Count Ctrl-D and Enter as aborted too.
        echo "${COL_RED}Aborted on behalf of the user.${COL_RESET}"
        exit 1;
    fi
}

usage() {
    cat << EOF
usage: $0 OPTIONS

OPTIONS:

  -h   Show this message.
  -d   Do not ask before running.
  -x   Keep rmlint.sh; do not autodelete it.
  -p   Recheck that files are still identical before removing duplicates.
  -r   Allow deduplication of files on read-only btrfs snapshots. (requires sudo)
  -n   Do not perform any modifications, just print what would be done. (implies -d and -x)
  -c   Clean up empty directories while deleting duplicates.
  -q   Do not show progress.
  -k   Keep the timestamp of directories when removing duplicates.
  -i   Ask before deleting each file
EOF
}

DO_REMOVE=
DO_ASK=

while getopts "dhxnrpqcki" OPTION
do
  case $OPTION in
     h)
       usage
       exit 0
       ;;
     d)
       DO_ASK=false
       ;;
     x)
       DO_REMOVE=false
       ;;
     n)
       DO_DRY_RUN=true
       DO_REMOVE=false
       DO_ASK=false
       DO_ASK_BEFORE_DELETE=false
       ;;
     r)
       DO_CLONE_READONLY=true
       ;;
     p)
       DO_PARANOID_CHECK=true
       ;;
     c)
       DO_DELETE_EMPTY_DIRS=true
       ;;
     q)
       DO_SHOW_PROGRESS=
       ;;
     k)
       DO_KEEP_DIR_TIMESTAMPS=true
       STAMPFILE=$(mktemp 'rmlint.XXXXXXXX.stamp')
       ;;
     i)
       DO_ASK_BEFORE_DELETE=true
       ;;
     *)
       usage
       exit 1
  esac
done

if [ -z $DO_REMOVE ]
then
    echo "#${COL_YELLOW} ///${COL_RESET}This script will be deleted after it runs${COL_YELLOW}///${COL_RESET}"
fi

if [ -z $DO_ASK ]
then
  usage
  ask
fi

if [ -n "$DO_DRY_RUN" ]
then
    echo "#${COL_YELLOW} ////////////////////////////////////////////////////////////${COL_RESET}"
    echo "#${COL_YELLOW} /// ${COL_RESET} This is only a dry run; nothing will be modified! ${COL_YELLOW}///${COL_RESET}"
    echo "#${COL_YELLOW} ////////////////////////////////////////////////////////////${COL_RESET}"
fi

######### START OF AUTOGENERATED OUTPUT #########

handle_emptydir '/home/hugo/VirtualBox VMs/win95/Snapshots' # empty folder
handle_emptydir '/home/hugo/VirtualBox VMs/MS-DOS/Snapshots' # empty folder
handle_emptydir '/home/hugo/Documents/programacion/P2E4/include/python3.11' # empty folder
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/chardet/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_internal/operations/build/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/MS-DOS/v4.0/src/H/MAKEFILE' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib-3.8.4.dist-info/REQUESTED' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/sphinxext/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-glibc-hwcaps-2-cache.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/pyparsing/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/chardet/metadata/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/MS-DOS/v4.0/src/LIB/MAKEFILE' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip-24.0.dist-info/REQUESTED' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/contourpy/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnss_files.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_internal/resolution/resolvelib/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/compat/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/urllib3/packages/backports/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libdl.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/lib/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/nss/tst-nss-gai-hv2-canonname.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/REQUESTED' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libBrokenLocale.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnss_hesiod.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/nss/tst-reload1.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/truststore/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/_qhull.pyi' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/kiwisolver/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/loongarch/lp64/libpthread.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_internal/resolution/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libanl.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnss_nis.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/f2py/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libutil.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/random/tests/data/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/code_proyects/chess/board.c' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/fft/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libm.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/testing/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/cycler/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/idna/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-rootdir.root/preclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/PRINTER/4208/MAKEFILE' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/backends/_backend_agg.pyi' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/tenacity/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/polynomial/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/loongarch/lp64/librt.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnsl.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/_image.pyi' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/backends/qt_editor/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/mach/hurd/libhurduser.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/backends/_macosx.pyi' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-ld_so_conf-update.root/ldconfig.run' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/chardet/cli/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/_core/__init__.pyi' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/ld.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnss_compat.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_internal/resolution/legacy/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyparsing/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/ma/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyinstaller-6.5.0.dist-info/REQUESTED' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/wordcopy.c' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fontTools/colorLib/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/urllib3/packages/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-glibc-hwcaps-prepend-cache.root/ldconfig.run' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnss_db.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/mach/hurd/x86_64/libdl.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/urllib3/contrib/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/certifi/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libc_malloc_debug.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnss_nisplus.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/distro/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/cachecontrol/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/backends/_tkagg.pyi' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/typing/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/jaraco/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/matrixlib/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/core/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libpthread.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/mach/libmachuser.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/packaging/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/_ttconv.pyi' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/_pyinstaller/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/misc/tst-syslog-long-progname.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/distutils/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/testing/_private/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-bad-aux-cache.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libresolv.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/PRINTER/4201/MAKEFILE' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/jaraco/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-glibc-hwcaps-cache.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/linalg/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-ld_so_conf-update.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_internal/utils/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/urllib3/contrib/_securetransport/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy/random/tests/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/rich/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/librt.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/resolvelib/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/platformdirs/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_internal/operations/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fontTools/misc/plistlib/py.typed' # empty file
handle_emptyfile '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/resolvelib/compat/__init__.py' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/locale/tst-localedef-path-norm.root/postclean.req' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/sysdeps/generic/libnss_dns.abilist' # empty file
handle_emptyfile '/home/hugo/Documents/glibc-2.39/elf/tst-glibc-hwcaps-prepend-cache.root/postclean.req' # empty file

original_cmd  '/home/hugo/Documents/code_proyects/game/example/VulkanTest' # original
remove_cmd    '/home/hugo/Documents/code_proyects/game/triangle/VulkanTest' '/home/hugo/Documents/code_proyects/game/example/VulkanTest' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips32/libm-test-ulps' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/libm-test-ulps' '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips32/libm-test-ulps' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/i386/dl-machine-rel.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/dl-machine-rel.h' '/home/hugo/Documents/glibc-2.39/sysdeps/i386/dl-machine-rel.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/ieee754.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128/ieee754.h' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/ieee754.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-p_align1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-p_align2.c' '/home/hugo/Documents/glibc-2.39/elf/tst-p_align1.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-nodelete-rtldmod.cc' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-nodelete-zmod.cc' '/home/hugo/Documents/glibc-2.39/elf/tst-nodelete-rtldmod.cc' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/bsd-_setjmp.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-32/bsd-_setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/bsd-_setjmp.S' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/bsd-_setjmp.S' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-32/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/bsd-_setjmp.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/makecontext.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mach/hurd/i386/makecontext.S' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/makecontext.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/fpu/s_fma.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/fpu/s_fma.c' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/fpu/s_fma.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/alpha/fpu/s_fma.c' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/fpu/s_fma.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/BS_4730' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CSA_Z243.4-1985-1' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CSA_Z243.4-1985-2' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/DIN_66003' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/DS_2089' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ES' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ES2' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/GB_1988-80' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IT' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/JIS_C6220-1969-RO' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/JUS_I.B1.002' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/KSC5636' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/MSZ_7795.3' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/NC_NC00-10' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/NF_Z_62-010' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/NF_Z_62-010_1973' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/NS_4551-1' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/NS_4551-2' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/PT' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/PT2' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/SEN_850200_B' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/SEN_850200_C' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ANSI_X3.4-1968' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-bad-aux-cache.root/etc/ld.so.conf' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-glibc-hwcaps-2-cache.root/etc/ld.so.conf' '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-bad-aux-cache.root/etc/ld.so.conf' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-glibc-hwcaps-cache.root/etc/ld.so.conf' '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-bad-aux-cache.root/etc/ld.so.conf' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/librt.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n32/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/librt.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/librt.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libm.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libm.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libm.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/localplt.data' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/fpu/localplt.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/localplt.data' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/bits/wordsize.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/bits/wordsize.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/bits/wordsize.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/bits/wordsize.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/bits/wordsize.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libm.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libm.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libm.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libm.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libm.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libm.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libm.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libm.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/aio_cancel.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/aio_cancel.c' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/aio_cancel.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/bits/environments.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/bits/environments.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/bits/environments.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libresolv.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libresolv.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/rt-sysdep.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/rt-sysdep.c' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/rt-sysdep.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv7/multiarch/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/be/armv7/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv7/multiarch/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/rt-sysdep.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/mips/rt-sysdep.S' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/rt-sysdep.S' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/alpha/rt-sysdep.S' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/rt-sysdep.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/shlib-versions' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/shlib-versions' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/shlib-versions' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libdl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libdl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libdl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libnsl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libnsl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libnsl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libnsl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libnsl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/stdlib/ldbl2mpn.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/stdlib/mpn2ldbl.c' '/home/hugo/Documents/glibc-2.39/stdlib/ldbl2mpn.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/dl-cache.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/dl-cache.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/dl-cache.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/riscv/rv64/c++-types.data' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/loongarch/lp64/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/riscv/rv64/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/riscv/rv64/c++-types.data' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/c++-types.data' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/nios2/c++-types.data' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/csky/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/nios2/c++-types.data' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/riscv/rv32/c++-types.data' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/or1k/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/riscv/rv32/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arc/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/riscv/rv32/c++-types.data' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/64/c++-types.data' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-64/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/64/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/64/c++-types.data' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/c++-types.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/64/c++-types.data' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/fpu/multiarch/s_fma-generic.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/sparcv9/fpu/multiarch/s_fma-generic.c' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/fpu/multiarch/s_fma-generic.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/bits/long-double.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/bits/long-double.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/bits/long-double.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sincosf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sincosf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sincosf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sincosf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sincosf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sincos-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sincos-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sincos-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sincos-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sincos-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power6x/fpu/multiarch/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power6/fpu/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power6x/fpu/multiarch/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/mach/stack_chk_fail_local.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/hurd/stack_chk_fail_local.c' '/home/hugo/Documents/glibc-2.39/mach/stack_chk_fail_local.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libdl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libdl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libdl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-syslog-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-syslog-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-syslog-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tan-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tan-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tan-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tan-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tan-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cos-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cos-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cos-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cos-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cos-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-logf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-logf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-logf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-logf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-logf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erff-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erff-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erff-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erff-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erff-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sin-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sin-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sin-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sin-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sin-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cosf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cosf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cosf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cosf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cosf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-wscanf-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-wscanf-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-wscanf-ibm128.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wscanf-ibm128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-wscanf-ibm128.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wscanf-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-wscanf-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-pow-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-pow-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-pow-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-pow-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-pow-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-powf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-powf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-powf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-powf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-powf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-strfmon-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-strfmon-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-strfmon-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-coshf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-coshf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-coshf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-coshf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-coshf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tanh-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tanh-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tanh-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tanh-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-tanh-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cbrtf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cbrtf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cbrtf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cbrtf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-cbrtf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinhf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinhf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinhf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinhf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-sinhf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wcstold-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wcstold-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wcstold-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanhf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanhf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanhf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanhf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-tanhf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp2-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp2-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp2-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp2-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp2-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp2f-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp2f-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp2f-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp2f-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp2f-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log2f-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log2f-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log2f-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log2f-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log2f-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asin-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asin-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asin-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asin-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asin-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cosh-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cosh-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cosh-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cosh-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cosh-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acos-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acos-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acos-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acos-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acos-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log2-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log2-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log2-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log2-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log2-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erfc-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erfc-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erfc-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erfc-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-erfc-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/float128/e_scalbf128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/float128/s_significandf128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/float128/e_scalbf128.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/float128/w_scalbf128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/float128/e_scalbf128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acosf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acosf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acosf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acosf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acosf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sinh-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sinh-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sinh-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sinh-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-sinh-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cbrt-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cbrt-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cbrt-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cbrt-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-cbrt-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erfcf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erfcf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erfcf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erfcf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-erfcf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-obstack-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-obstack-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-obstack-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power7/multiarch/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power6x/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power7/multiarch/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-strfrom-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-strfrom-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-strfrom-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips64/Makefile' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/soft-fp/Makefile' '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips64/Makefile' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/nptl/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/htl/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/nptl/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/htl/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/htl/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/htl/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/Subdirs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/nofpu/Subdirs' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/Subdirs' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/nios2/Subdirs' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/Subdirs' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/alpha/Subdirs' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/Subdirs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanhf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanhf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanhf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanhf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atanhf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/microblaze/sfp-machine.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/coldfire/nofpu/sfp-machine.h' '/home/hugo/Documents/glibc-2.39/sysdeps/microblaze/sfp-machine.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asinh-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asinh-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asinh-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asinh-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-asinh-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-expm1-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-expm1-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-expm1-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-expm1-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-expm1-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-hypotf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-hypotf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-hypotf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-hypotf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-hypotf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expm1f-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expm1f-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expm1f-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expm1f-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-expm1f-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log1pf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log1pf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log1pf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log1pf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log1pf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-size-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-size-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-size-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log1p-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log1p-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log1p-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log1p-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log1p-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atan2f-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atan2f-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atan2f-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atan2f-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-atan2f-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan2-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan2-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan2-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan2-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atan2-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp10-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp10-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp10-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp10-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-exp10-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acoshf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acoshf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acoshf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acoshf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-acoshf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atanh-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atanh-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atanh-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atanh-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-atanh-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-hypot-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-hypot-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-hypot-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-hypot-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-hypot-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log10-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log10-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log10-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log10-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-log10-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acosh-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acosh-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acosh-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acosh-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-double-libmvec-acosh-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log10f-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log10f-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log10f-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log10f-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-log10f-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp10f-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp10f-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp10f-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp10f-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-exp10f-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinhf-avx.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinhf-avx2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinhf-avx.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinhf-avx512f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/test-float-libmvec-asinhf-avx.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/librt.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/librt.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/localedata/tests/test1.def' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/localedata/tests/test3.def' '/home/hugo/Documents/glibc-2.39/localedata/tests/test1.def' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_ceil-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_ceil-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_ceil-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_ufromfpl.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128/s_ufromfpl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_ufromfpl.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_fromfpxl.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128/s_fromfpxl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_fromfpxl.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/power7/strcasecmp_l.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power7/strcasecmp_l.S' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/power7/strcasecmp_l.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/Implies-after' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/Implies-after' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/Implies-after' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/multiarch/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power4/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/multiarch/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/multiarch/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-64/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_log.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/fpu/multiarch/w_log.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_log.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/w_log.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_log.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/w_log.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_log.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libBrokenLocale.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libBrokenLocale.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_exp.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/w_exp.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_exp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/w_exp.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_exp.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_pow.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/w_pow.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_pow.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/w_pow.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/multiarch/w_pow.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libBrokenLocale.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-64/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libBrokenLocale.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libBrokenLocale.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/nios2/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n32/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/csky/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/time64-compat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/time64-compat.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/csky/bsd-_setjmp.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arc/bsd-_setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/csky/bsd-_setjmp.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/tst-armtlsdescextlazy.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/tst-armtlsdescextnow.c' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/tst-armtlsdescextlazy.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c11.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c89.c' '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c11.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c99.c' '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c11.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-gnu11.c' '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c11.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-gnu89.c' '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c11.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-gnu99.c' '/home/hugo/Documents/glibc-2.39/nptl/tst-initializers1-c11.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/sh4/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/sh4/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/sh4/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-quad1pie.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-quad2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-quad1pie.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-oncex4.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-oncey4.c' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-oncex4.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-audit1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-audit8.c' '/home/hugo/Documents/glibc-2.39/elf/tst-audit1.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-oncex3.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-oncey3.c' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-oncex3.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/sh3/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/sh3/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/sh3/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/libio/tst-bz28828.input' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup.exp' '/home/hugo/Documents/glibc-2.39/libio/tst-bz28828.input' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sh/le/sh4/fpu/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sh/be/sh4/fpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/le/sh4/fpu/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/wcsmbs/Depend' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/string/Depend' '/home/hugo/Documents/glibc-2.39/wcsmbs/Depend' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/stdlib/Depend' '/home/hugo/Documents/glibc-2.39/wcsmbs/Depend' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/stdio-common/Depend' '/home/hugo/Documents/glibc-2.39/wcsmbs/Depend' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/posix/Depend' '/home/hugo/Documents/glibc-2.39/wcsmbs/Depend' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/libio/Depend' '/home/hugo/Documents/glibc-2.39/wcsmbs/Depend' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/debug/Depend' '/home/hugo/Documents/glibc-2.39/wcsmbs/Depend' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/microblaze/le/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/microblaze/be/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/microblaze/le/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/librt.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/librt.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/librt.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/bin/python3' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/bin/python3.11' '/home/hugo/Documents/programacion/P2E4/bin/python3' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libthread_db.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/zipp.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/zipp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/zipp.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_adapters.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/_adapters.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_adapters.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_compat.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/_compat.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_compat.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_common.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/_common.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_common.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_legacy.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/_legacy.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_legacy.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/readers.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/readers.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/readers.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/simple.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/simple.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/simple.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/actions.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/actions.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/actions.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/common.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/common.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/common.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/testing.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/testing.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/testing.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/util.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/util.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/util.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/unicode.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/unicode.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/unicode.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/results.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/results.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/results.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/diagram/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/diagram/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/diagram/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/abc.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/abc.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/abc.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libnsl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libnsl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libnsl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libnsl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libnsl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/jaraco/context.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/jaraco/context.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/jaraco/context.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_musllinux.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/_musllinux.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_musllinux.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/_musllinux.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_musllinux.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_manylinux.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/_manylinux.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_manylinux.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/_manylinux.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_manylinux.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/utils.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/utils.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/utils.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/utils.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/utils.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/tags.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/tags.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/tags.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/tags.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/tags.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/version.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/version.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/version.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/version.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/version.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/specifiers.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/specifiers.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/specifiers.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/specifiers.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/specifiers.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/_re.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/tomli/_re.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/_re.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/_parser.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/tomli/_parser.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/_parser.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/single-thread.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-64/single-thread.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/single-thread.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/single-thread.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/single-thread.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/single-thread.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/single-thread.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/single-thread.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/single-thread.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arc/single-thread.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/single-thread.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/single-thread.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/x86_64/single-thread.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imagingmath.pyi' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imagingmorph.pyi' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imagingmath.pyi' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_webp.pyi' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imagingmath.pyi' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imaging.pyi' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imagingmath.pyi' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imagingft.pyi' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PIL/_imagingmath.pyi' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_structures.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/_structures.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_structures.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/_structures.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_structures.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/packaging/_structures.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/_structures.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/nios2/bits/statfs.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/csky/bits/statfs.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/nios2/bits/statfs.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/isfinite-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/isinf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/isfinite-inputs' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/isnan-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/isfinite-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/tst-armtlsdescextlazymod.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/tst-armtlsdescextnowmod.c' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/tst-armtlsdescextlazymod.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86/fpu/test-flt-eval-method-387.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86/fpu/test-flt-eval-method-sse.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/fpu/test-flt-eval-method-387.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-6a.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-6b.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-6a.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-5a.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-5b.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-5a.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sh/tininess.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/tininess.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mips/tininess.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/hppa/tininess.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/csky/tininess.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arc/tininess.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/alpha/tininess.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tininess.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_floorf-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_floorf-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_floorf-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_roundf-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_roundf-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_roundf-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_truncf-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_truncf-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_truncf-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/abort-instr.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/abort-instr.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/abort-instr.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-chk-redir-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-chk-redir-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-chk-redir-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/bits/epoll.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/bits/epoll.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/bits/epoll.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libthread_db.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libthread_db.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libthread_db.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libthread_db.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/or1k/sys/user.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/sys/user.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/or1k/sys/user.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/or1k/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips64/n64/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips64/n32/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips32/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/coldfire/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/loongarch/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/csky/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arc/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nofpu/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libthread_db.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libthread_db.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libthread_db.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libthread_db.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-5.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-6.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-5.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_fromfpl.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128/s_fromfpl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_fromfpl.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/multiarch/dl-symbol-redir-ifunc.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/sparcv9/multiarch/dl-symbol-redir-ifunc.h' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/multiarch/dl-symbol-redir-ifunc.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/exceptions.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/exceptions.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/exceptions.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/generic/dl-procinfo.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/generic/dl-procruntime.c' '/home/hugo/Documents/glibc-2.39/sysdeps/generic/dl-procinfo.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/reldep4mod2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/reldep4mod4.c' '/home/hugo/Documents/glibc-2.39/elf/reldep4mod2.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/alpha/nptl/pthread-offsets.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/nptl/pthread-offsets.h' '/home/hugo/Documents/glibc-2.39/sysdeps/alpha/nptl/pthread-offsets.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/localedata/tst-localedef-hardlinks.root/test1_locale' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/localedata/tst-localedef-hardlinks.root/test2_locale' '/home/hugo/Documents/glibc-2.39/localedata/tst-localedef-hardlinks.root/test1_locale' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_round-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_round-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_round-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/nss/tst-nss-test3.root/tst-nss-test3.script' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/nss/tst-reload1.root/tst-reload1.script' '/home/hugo/Documents/glibc-2.39/nss/tst-nss-test3.root/tst-nss-test3.script' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_floor-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_floor-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_floor-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_trunc-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_trunc-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_trunc-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_ceilf-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_ceilf-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_ceilf-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fontTools/pens/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fontTools/misc/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fontTools/pens/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fontTools/encodings/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fontTools/pens/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rv64/rvf/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rv32/rvf/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rv64/rvf/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv6/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/be/armv6/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv6/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv7/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/be/armv7/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv7/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/nofpu/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/be/nofpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/nofpu/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/roundeven-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/trunc-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/roundeven-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-unique1mod2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-unique2mod2.c' '/home/hugo/Documents/glibc-2.39/elf/tst-unique1mod2.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-5a.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-5b.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-5a.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/64/tst-map-32bit-1b.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/64/tst-map-32bit-2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/64/tst-map-32bit-1b.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-6a.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-6b.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-6a.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-_setjmp.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/bsd-_setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-_setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/bsd-_setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-_setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/or1k/bsd-_setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-_setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/nios2/bsd-_setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-_setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/alpha/bsd-_setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-_setjmp.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-4a.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-4b.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-4a.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-4c.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-4a.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/csky/bsd-setjmp.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arc/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/csky/bsd-setjmp.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-pt-vfork1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-vfork1x.c' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-pt-vfork1.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-pt-vfork2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-vfork2x.c' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-pt-vfork2.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fonttools-4.51.0.dist-info/WHEEL' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib-3.8.4.dist-info/WHEEL' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fonttools-4.51.0.dist-info/WHEEL' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-5c.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-6c.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-mod-5c.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_setpayloadl.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128/s_setpayloadl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_setpayloadl.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_ufromfpxl.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128/s_ufromfpxl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_ufromfpxl.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/help.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/help-symbolic.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/help.svg' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/home-symbolic.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/home.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/home-symbolic.svg' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/forward.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/forward-symbolic.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/forward.svg' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/subplots-symbolic.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/subplots.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/subplots-symbolic.svg' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/back-symbolic.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/back.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/back-symbolic.svg' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libresolv.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libresolv.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libresolv.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libresolv.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/zoom_to_rect.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/zoom_to_rect-symbolic.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/zoom_to_rect.svg' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/filesave-symbolic.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/filesave.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/filesave-symbolic.svg' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/ldconfig.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/ldconfig.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/ldconfig.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/tests.txt' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/tests.txt' '/home/hugo/Documents/programacion/P2E3/tests.txt' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/s_scalblnl.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/s_scalblnl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/s_scalblnl.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/s_scalblnf.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/s_scalblnf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/s_scalblnf.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/main.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/main.c' '/home/hugo/Documents/programacion/P2E3/main.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.c' '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/printers.bbclit/main.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/main.c' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/main.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/printers.bbclit/makefile' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/makefile' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/makefile' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/cola.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/cola.c' '/home/hugo/Documents/programacion/P2E3/cola.c' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/cola.c' '/home/hugo/Documents/programacion/P2E3/cola.c' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/cola.c' '/home/hugo/Documents/programacion/P2E3/cola.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/printers.bbclit/lista.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/lista.c' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/lista.c' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/lista.c' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/lista.c' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/lista.c' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/lista.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/test.txt' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/test.txt' '/home/hugo/Documents/programacion/P2E3/test.txt' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/test.txt' '/home/hugo/Documents/programacion/P2E3/test.txt' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/include/cola.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/cola.h' '/home/hugo/Documents/programacion/P2E3/include/cola.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/include/cola.h' '/home/hugo/Documents/programacion/P2E3/include/cola.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/include/cola.h' '/home/hugo/Documents/programacion/P2E3/include/cola.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/bbclit.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/include/bbclit.h' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/bbclit.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/printers.bbclit/printers.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/printers.c' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/printers.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/lista.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/include/lista.h' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/lista.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/include/lista.h' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/lista.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/include/lista.h' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/lista.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/include/printers.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/printers.h' '/home/hugo/Documents/programacion/P2E3/include/printers.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/include/printers.h' '/home/hugo/Documents/programacion/P2E3/include/printers.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/include/printers.h' '/home/hugo/Documents/programacion/P2E3/include/printers.h' # duplicate

original_cmd  '/home/hugo/Documents/code_proyects/game/example/makefile' # original
remove_cmd    '/home/hugo/Documents/code_proyects/game/triangle/makefile' '/home/hugo/Documents/code_proyects/game/example/makefile' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/shlib-versions' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/shlib-versions' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/shlib-versions' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/mplot3d/tests/conftest.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/axes_grid1/tests/conftest.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/mplot3d/tests/conftest.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/axisartist/tests/conftest.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/mplot3d/tests/conftest.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/mplot3d/tests/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/axes_grid1/tests/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/mplot3d/tests/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/axisartist/tests/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/mpl_toolkits/mplot3d/tests/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/bits/poll.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/bits/poll.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/bits/poll.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib-3.8.4.dist-info/LICENSE_STIX' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/fonts/ttf/LICENSE_STIX' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib-3.8.4.dist-info/LICENSE_STIX' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/nodel2mod2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/reldep8mod2.c' '/home/hugo/Documents/glibc-2.39/elf/nodel2mod2.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libpthread.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libpthread.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/move-symbolic.svg' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/move.svg' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib/mpl-data/images/move-symbolic.svg' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/FORMAT.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/FORMAT.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/FORMAT.DOC' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/INT24.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/INT24.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/INT24.DOC' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/include/printer_data.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/printer_data.h' '/home/hugo/Documents/programacion/P2E3/include/printer_data.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/include/printer_data.h' '/home/hugo/Documents/programacion/P2E3/include/printer_data.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/include/printer_data.h' '/home/hugo/Documents/programacion/P2E3/include/printer_data.h' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/QUICK.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/QUICK.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/QUICK.DOC' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/CONFIG.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/CONFIG.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/CONFIG.DOC' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/PROFILE.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/PROFILE.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/PROFILE.DOC' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/ANSI.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/ANSI.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/ANSI.DOC' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/INCOMP.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/INCOMP.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/INCOMP.DOC' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/SYSINIT.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/SYSINIT.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/SYSINIT.DOC' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-sonamemove-linkmod1.map' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-sonamemove-runmod2.map' '/home/hugo/Documents/glibc-2.39/elf/tst-sonamemove-linkmod1.map' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-64/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n32/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libanl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libutil.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libutil.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libutil.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libutil.abilist' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/UTILITY.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/UTILITY.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/UTILITY.DOC' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/librt.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/librt.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libdl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libdl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libdl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libdl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libdl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/librt.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/librt.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libanl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libanl.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libanl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-soname-lib-with-soname.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-soname-lib-without-soname.c' '/home/hugo/Documents/glibc-2.39/elf/tst-ldconfig-soname-lib-with-soname.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-chk-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-chk-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-printf-chk-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-syslog-chk-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-syslog-chk-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-syslog-chk-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libanl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libanl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-obstack-chk-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-obstack-chk-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-obstack-chk-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sh/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/hppa/hppa1.1/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arc/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libanl.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libanl.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libanl.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libutil.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libutil.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-chk-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-chk-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-chk-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power7/fpu/multiarch/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power6x/fpu/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power7/fpu/multiarch/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libutil.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libutil.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/e_exp10l.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/e_exp10l.S' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/e_exp10l.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/s_expm1l.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/s_expm1l.S' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/s_expm1l.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips64/n64/fpu/s_fma.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips64/n32/fpu/s_fma.c' '/home/hugo/Documents/glibc-2.39/sysdeps/mips/mips64/n64/fpu/s_fma.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-10a-static.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-10a.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/tst-cet-legacy-10a-static.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1163' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1164' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1163' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/nldbl-abi.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/nldbl-abi.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/nldbl-abi.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/nldbl-abi.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/nldbl-abi.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/nldbl-abi.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/nldbl-abi.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-chk-redir-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-chk-redir-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-wprintf-chk-redir-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/DEBUG/SYSVER.FAL' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/DEBUG/SYSVER.INC' '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/DEBUG/SYSVER.FAL' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power5/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/970/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power5/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power7/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power6x/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power7/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/s_scalbln.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/s_scalbln.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/s_scalbln.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/nodel2mod1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/reldep8mod1.c' '/home/hugo/Documents/glibc-2.39/elf/nodel2mod1.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyparsing-3.1.2.dist-info/WHEEL' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/packaging-24.0.dist-info/WHEEL' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyparsing-3.1.2.dist-info/WHEEL' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cancel21-static.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cancelx21.c' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cancel21-static.c' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/FILESYS/_PARSE.ASM' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/MEM/_PARSE.ASM' '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/FILESYS/_PARSE.ASM' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sh/le/sh3/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sh/be/sh3/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/le/sh3/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/nodel2mod3.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/reldep8mod3.c' '/home/hugo/Documents/glibc-2.39/elf/nodel2mod3.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/reldep9mod3.c' '/home/hugo/Documents/glibc-2.39/elf/nodel2mod3.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/unload7mod2.c' '/home/hugo/Documents/glibc-2.39/elf/nodel2mod3.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sh/le/sh4/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sh/be/sh4/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/le/sh4/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86/float128-abi.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/float128-abi.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/float128-abi.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/roundevenf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/truncf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/roundevenf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tst-isa-level-mod-1-baseline.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tst-isa-level-mod-1-v2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tst-isa-level-mod-1-baseline.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tst-isa-level-mod-1-v3.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tst-isa-level-mod-1-baseline.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tst-isa-level-mod-1-v4.c' '/home/hugo/Documents/glibc-2.39/sysdeps/x86/tst-isa-level-mod-1-baseline.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/____longjmp_chk.S' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/____longjmp_chk.S' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/____longjmp_chk.S' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/w_log2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/w_log2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/w_log2.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/w_exp2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/w_exp2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/w_exp2.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libBrokenLocale.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libBrokenLocale.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libBrokenLocale.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libBrokenLocale.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libBrokenLocale.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-scanf-ibm128.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-scanf-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-scanf-ibm128.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-scanf-ibm128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-scanf-ibm128.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-scanf-ieee128.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128ibm-compat/test-isoc99-scanf-ibm128.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power6x/multiarch/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power6/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power6x/multiarch/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/nptl/tst-stackguard1-static.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-stackguard1-static.c' '/home/hugo/Documents/glibc-2.39/nptl/tst-stackguard1-static.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/strrchr.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/strrchr.c' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/strrchr.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/sparcv9/strrchr.c' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/strrchr.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-setjmp.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/or1k/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/nios2/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-setjmp.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/alpha/bsd-setjmp.S' '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/bsd-setjmp.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/fpu/multiarch/s_fmaf-generic.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc32/sparcv9/fpu/multiarch/s_fmaf-generic.c' '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/sparc64/fpu/multiarch/s_fmaf-generic.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/s390/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/loongarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-array1-static.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-array2.c' '/home/hugo/Documents/glibc-2.39/elf/tst-array1-static.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-array3.c' '/home/hugo/Documents/glibc-2.39/elf/tst-array1-static.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/ifuncmain9pic.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/ifuncmain9picstatic.c' '/home/hugo/Documents/glibc-2.39/elf/ifuncmain9pic.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/ifuncmain9pie.c' '/home/hugo/Documents/glibc-2.39/elf/ifuncmain9pic.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/ifuncmain9static.c' '/home/hugo/Documents/glibc-2.39/elf/ifuncmain9pic.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cond11-static.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cond11-time64.c' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cond11-static.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/nss/tst-initgroups2.root/etc/passwd' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/nss/tst-initgroups1.root/etc/passwd' '/home/hugo/Documents/glibc-2.39/nss/tst-initgroups2.root/etc/passwd' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/filtmod1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/filtmod2.c' '/home/hugo/Documents/glibc-2.39/elf/filtmod1.c' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/DIRENT.ASM' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/RAMDRIVE/DIRENT.INC' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/DIRENT.ASM' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/EMM.ASM' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/RAMDRIVE/EMM.INC' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/EMM.ASM' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/464/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/476/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/464/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/440/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/464/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/440/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/405/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/440/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/405/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/fpu/multiarch/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power4/fpu/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/fpu/multiarch/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/fpu/multiarch/Implies' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/MI.ASM' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/RAMDRIVE/MI.INC' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/MI.ASM' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/struct_kernel_msqid64_ds.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/struct_kernel_msqid64_ds.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/struct_kernel_msqid64_ds.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/struct_kernel_msqid64_ds.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/struct_kernel_msqid64_ds.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-default-static.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-default.c' '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-default-static.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-nostart-stop-gc-static.c' '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-default-static.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-nostart-stop-gc.c' '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-default-static.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-start-stop-gc-static.c' '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-default-static.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-start-stop-gc.c' '/home/hugo/Documents/glibc-2.39/libio/tst-cleanup-default-static.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cancel5.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cancelx4.c' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cancel5.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-audit14a.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-audit15.c' '/home/hugo/Documents/glibc-2.39/elf/tst-audit14a.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-audit16.c' '/home/hugo/Documents/glibc-2.39/elf/tst-audit14a.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rvf/fegetenv.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mips/fpu/fegetenv.c' '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rvf/fegetenv.c' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/XMAEM/XMAEM.ARF' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/XMAEM/XMAEM.LNK' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/XMAEM/XMAEM.ARF' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sh/stackguard-macros.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/nios2/stackguard-macros.h' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/stackguard-macros.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_setpayloadsigl.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-128/s_setpayloadsigl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/ldbl-96/s_setpayloadsigl.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/math-use-builtins-sqrt.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/sparc/fpu/math-use-builtins-sqrt.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/math-use-builtins-sqrt.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/s390/fpu/math-use-builtins-sqrt.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/math-use-builtins-sqrt.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rvd/math-use-builtins-sqrt.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/math-use-builtins-sqrt.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/coldfire/fpu/math-use-builtins-sqrt.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/math-use-builtins-sqrt.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/loongarch/fpu/math-use-builtins-sqrt.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/math-use-builtins-sqrt.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/fpu/math-use-builtins-sqrt.h' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/fpu/math-use-builtins-sqrt.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_rem_pio2l.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/k_rem_pio2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_rem_pio2l.c' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/FC/INTERNAT.H' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/H/INTERNAT.H' '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/FC/INTERNAT.H' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/H/JOINTYPE.H' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/H/TYPES.H' '/home/hugo/Documents/MS-DOS/v4.0/src/H/JOINTYPE.H' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/stdio-common/errlist-compat-data.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/libtracemod1-1.c' '/home/hugo/Documents/glibc-2.39/stdio-common/errlist-compat-data.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/libtracemod2-1.c' '/home/hugo/Documents/glibc-2.39/stdio-common/errlist-compat-data.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/libtracemod3-1.c' '/home/hugo/Documents/glibc-2.39/stdio-common/errlist-compat-data.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/libtracemod4-1.c' '/home/hugo/Documents/glibc-2.39/stdio-common/errlist-compat-data.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/libtracemod5-1.c' '/home/hugo/Documents/glibc-2.39/stdio-common/errlist-compat-data.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/resolv/tst-leaks2.root/etc/nsswitch.conf' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/nss/tst-nss-files-hosts-v4mapped.root/etc/nsswitch.conf' '/home/hugo/Documents/glibc-2.39/resolv/tst-leaks2.root/etc/nsswitch.conf' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/nss/tst-nss-files-hosts-long.root/etc/nsswitch.conf' '/home/hugo/Documents/glibc-2.39/resolv/tst-leaks2.root/etc/nsswitch.conf' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/generic/dl-vdso-setup.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/math/w_exp10f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/generic/dl-vdso-setup.c' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/INC/DBCS.OFF' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/INC/DBCS.SW' '/home/hugo/Documents/MS-DOS/v4.0/src/INC/DBCS.OFF' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libresolv.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libresolv.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n32/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libresolv.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libresolv.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/reldep4mod1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/reldep4mod3.c' '/home/hugo/Documents/glibc-2.39/elf/reldep4mod1.c' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/CHKDSK/PATHMAC.INC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/RECOVER/PATHMAC.INC' '/home/hugo/Documents/MS-DOS/v4.0/src/CMD/CHKDSK/PATHMAC.INC' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/Versions' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/Versions' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/Versions' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/Versions' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/Versions' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/LOADALL.ASM' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/RAMDRIVE/LOADALL.INC' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/LOADALL.ASM' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pillow-10.3.0.dist-info/zip-safe' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/python_dateutil-2.9.0.post0.dist-info/zip-safe' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pillow-10.3.0.dist-info/zip-safe' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/altgraph-0.17.4.dist-info/zip-safe' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pillow-10.3.0.dist-info/zip-safe' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/mach/x86_64/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/mach/i386/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/mach/x86_64/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/nss/tst-nss-gai-actions.root/etc/host.conf' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/nss/tst-nss-files-hosts-long.root/etc/host.conf' '/home/hugo/Documents/glibc-2.39/nss/tst-nss-gai-actions.root/etc/host.conf' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/rt/Depend' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/resolv/Depend' '/home/hugo/Documents/glibc-2.39/rt/Depend' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/nscd/Depend' '/home/hugo/Documents/glibc-2.39/rt/Depend' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/rthooks/pyi_rth_pythoncom.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/rthooks/pyi_rth_pywintypes.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/rthooks/pyi_rth_pythoncom.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/htl/Makefile' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/htl/Makefile' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/htl/Makefile' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/s390/nptl/Makefile' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/nptl/Makefile' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/nptl/Makefile' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libpthread.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/libpthread.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/pila.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/pila.c' '/home/hugo/Documents/programacion/P2E3/pila.c' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/pila.c' '/home/hugo/Documents/programacion/P2E3/pila.c' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/pila.c' '/home/hugo/Documents/programacion/P2E3/pila.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/localedata/bs_BA.UTF-8.in' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/localedata/hr_HR.UTF-8.in' '/home/hugo/Documents/glibc-2.39/localedata/bs_BA.UTF-8.in' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/localedata/sr_RS.UTF-8.in' '/home/hugo/Documents/glibc-2.39/localedata/bs_BA.UTF-8.in' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/signal/tst-raise.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-raise1.c' '/home/hugo/Documents/glibc-2.39/signal/tst-raise.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/s390/fpu/math-use-builtins-fma.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/loongarch/fpu/math-use-builtins-fma.h' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/fpu/math-use-builtins-fma.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/fpu/math-use-builtins-fma.h' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/fpu/math-use-builtins-fma.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/python_dateutil-2.9.0.post0.dist-info/WHEEL' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyinstaller_hooks_contrib-2024.3.dist-info/WHEEL' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/python_dateutil-2.9.0.post0.dist-info/WHEEL' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/localedata/fur_IT.UTF-8.in' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/localedata/sc_IT.UTF-8.in' '/home/hugo/Documents/glibc-2.39/localedata/fur_IT.UTF-8.in' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/sh4/fpu/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/sh4/fpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/sh4/fpu/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/rtld-memset.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/rtld-memset.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/rtld-memset.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_itertools.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/_itertools.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/_itertools.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/kernel_stat.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/kernel_stat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/kernel_stat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/kernel_stat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/kernel_stat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/kernel_stat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/kernel_stat.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/kernel_stat.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/kernel_stat.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nptl/pthread_spin_init.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/nptl/pthread_spin_init.c' '/home/hugo/Documents/glibc-2.39/sysdeps/sh/nptl/pthread_spin_init.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/pre_safe_import_module/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/pre_find_module_path/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_modff-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_modff-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_modff-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1167' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM5347' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1167' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM901' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1167' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM902' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1167' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM921' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1167' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1112' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1122' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1123' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1130' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1140' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1141' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1142' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1143' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1144' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1145' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1146' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1147' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1148' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1149' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1153' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1154' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1155' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1156' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1157' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1158' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1166' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1097' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/xstatver.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/xstatver.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/xstatver.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/xstatver.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/xstatver.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/xstatver.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/xstatver.h' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/xstatver.h' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/xstatver.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/htl/tcb-offsets.sym' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/htl/tcb-offsets.sym' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/htl/tcb-offsets.sym' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/power4/Makefile' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/Makefile' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/power4/Makefile' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libc_malloc_debug.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libc_malloc_debug.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libc_malloc_debug.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/be/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/microblaze/le/libc_malloc_debug.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/nofpu/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/fpu/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n32/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/nofpu/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/fpu/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libc_malloc_debug.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libc_malloc_debug.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-64/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libc_malloc_debug.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/libc_malloc_debug.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n64/libc_malloc_debug.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libc_malloc_debug.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libc_malloc_debug.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libc_malloc_debug.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libc_malloc_debug.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libc_malloc_debug.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libc_malloc_debug.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libpthread.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libpthread.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/libpthread.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/locale-defines.sym' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/i686/multiarch/locale-defines.sym' '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/locale-defines.sym' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/fmaxf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/fminf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/fmaxf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/s390/nptl/pthread-offsets.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/nptl/pthread-offsets.h' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/nptl/pthread-offsets.h' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/loongarch/localplt.data' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/csky/localplt.data' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/loongarch/localplt.data' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/ld.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/ld.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/ld.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/ld.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/ld.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/ld.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/le/ld.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/ld.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/arm/be/ld.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/coldfire/ld.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n32/ld.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips32/ld.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/mips/mips64/n32/ld.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libpthread.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libpthread.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libpthread.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/alpha/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc32/libpthread.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/importlib_resources/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/importlib_resources/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/fmax-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/fmin-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/fmax-inputs' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/DEVSYM.ASM' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/RAMDRIVE/DEVSYM.INC' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/SMARTDRV/DEVSYM.ASM' # duplicate

original_cmd  '/home/hugo/Documents/code_proyects/game/example/main.cpp' # original
remove_cmd    '/home/hugo/Documents/code_proyects/game/triangle/main.cpp' '/home/hugo/Documents/code_proyects/game/example/main.cpp' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/__about__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/__about__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/__about__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/__about__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/__about__.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.Qsci.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.Qt3DAnimation.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.Qt3DCore.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.Qt3DExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.Qt3DInput.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.Qt3DLogic.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.Qt3DRender.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtBluetooth.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtChart.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtCore.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtDataVisualization.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtDBus.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtDesigner.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtGui.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtHelp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtLocation.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtMacExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtMultimedia.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtMultimediaWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtNetworkAuth.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtNfc.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtOpenGL.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtPositioning.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtPrintSupport.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtPurchasing.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtQuick.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtQuick3D.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtQuickWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtRemoteObjects.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtScript.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtSensors.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtSerialPort.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtSql.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtSvg.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtTest.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtTextToSpeech.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebChannel.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebKit.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebSockets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWinExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtX11Extras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtXml.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtXmlPatterns.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.Qt3DAnimation.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.Qt3DCore.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.Qt3DExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.Qt3DInput.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.Qt3DLogic.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.Qt3DRender.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtAxContainer.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtCharts.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtConcurrent.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtCore.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtDataVisualization.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtGui.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtHelp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtLocation.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtMacExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtMultimediaWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtOpenGL.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtOpenGLFunctions.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtPositioning.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtPrintSupport.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtQuick.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtQuickControls2.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtQuickWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtRemoteObjects.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtScript.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtScriptTools.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtScxml.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtSensors.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtSerialPort.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtSql.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtSvg.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtTest.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtTextToSpeech.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWebChannel.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWebKit.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWebSockets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWinExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtX11Extras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtXml.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtXmlPatterns.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QAxContainer.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebEngine.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebEngineWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebEngine.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebKitWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebEngine.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWebEngine.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebEngine.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWebEngineWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebEngine.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide2.QtWebKitWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt5.QtWebEngine.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.Qsci.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.Qt3DAnimation.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.Qt3DCore.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.Qt3DExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.Qt3DInput.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.Qt3DLogic.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtBluetooth.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCharts.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtDataVisualization.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtDBus.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtDesigner.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtMultimedia.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtMultimediaWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtNetworkAuth.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtNfc.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtPdf.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtPdfWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtPositioning.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtQuick3D.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtRemoteObjects.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtSensors.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtSerialPort.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtSpatialAudio.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtSvgWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtTextToSpeech.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWebChannel.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWebSockets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.Qt3DAnimation.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.Qt3DCore.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.Qt3DExtras.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.Qt3DInput.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.Qt3DLogic.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.Qt3DRender.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtAxContainer.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtBluetooth.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtCharts.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtConcurrent.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtDBus.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtDataVisualization.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtDesigner.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtLocation.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtMultimediaWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtNetworkAuth.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtNfc.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtPdf.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtPdfWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtPositioning.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtQuick3D.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtRemoteObjects.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtScxml.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtSensors.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtSerialBus.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtSerialPort.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtSpatialAudio.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtStateMachine.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtSvgWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtTextToSpeech.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtWebChannel.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtWebSockets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QAxContainer.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtGui.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtHelp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtOpenGL.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtOpenGLWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtPrintSupport.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtQuick.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtQuickWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtSql.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtSvg.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtTest.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtXml.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtCore.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtGui.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtHelp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtOpenGL.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtOpenGLWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtPrintSupport.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtQuick.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtQuickWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtSql.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtSvg.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtTest.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtUiTools.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtXml.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtCore.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWebEngineQuick.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWebEngineWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWebEngineQuick.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtWebEngineQuick.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWebEngineQuick.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PySide6.QtWebEngineWidgets.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-PyQt6.QtWebEngineQuick.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-distutils.command.check.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-setuptools._distutils.command.check.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/hook-distutils.command.check.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-backports.zoneinfo.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-zoneinfo.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-backports.zoneinfo.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/dl-lookupcfg.h' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/aarch64/dl-lookupcfg.h' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/dl-lookupcfg.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.AppIndicator3.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Atk.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.AyatanaAppIndicator3.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.cairo.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Champlain.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Clutter.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.DBus.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.freetype2.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Gdk.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GdkPixbuf.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Gio.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GIRepository.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GLib.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GModule.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GObject.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Graphene.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Gsk.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Gst.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstAllocators.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstApp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstAudio.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstBadAudio.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstBase.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstCheck.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstCodecs.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstController.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstGL.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstGLEGL.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstGLWayland.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstGLX11.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstInsertBin.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstMpegts.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstNet.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstPbutils.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstPlay.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstPlayer.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstRtp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstRtsp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstRtspServer.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstSdp.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstTag.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstTranscoder.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstVulkan.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstVulkanWayland.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstVulkanXCB.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GstWebRTC.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Gtk.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GtkChamplain.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GtkClutter.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GtkosxApplication.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.GtkSource.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.HarfBuzz.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Pango.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.PangoCairo.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.xlib.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/hook-gi.repository.Adw.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cleanup0.expect' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cleanupx0.expect' '/home/hugo/Documents/glibc-2.39/sysdeps/pthread/tst-cleanup0.expect' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/intl/Depend' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/assert/Depend' '/home/hugo/Documents/glibc-2.39/intl/Depend' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/depend/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/building/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_safe_import_module/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/pre_find_module_path/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/utils/cliutils/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/utils/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/loader/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/lib/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/hooks/rthooks/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/utils/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/DISPLAY/ZERO.DAT' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/PRINTER/ZERO.DAT' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/DISPLAY/ZERO.DAT' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/64/Implies-after' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rv64/Implies-after' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/loongarch/lp64/Implies-after' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-64/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/posix/bug-ga2.root/etc/services' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/nss/tst-reload1.root/etc/services' '/home/hugo/Documents/glibc-2.39/posix/bug-ga2.root/etc/services' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-32/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-32/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/x86_64/x32/Implies-after' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-32/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/riscv/rv32/Implies-after' '/home/hugo/Documents/glibc-2.39/sysdeps/s390/s390-32/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv6t2/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/be/armv6t2/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/armv6t2/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/framestate.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/unwind-pe.c' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/framestate.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cuda_cupti.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cuda_nvrtc.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cuda_runtime.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cudnn.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cufft.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.curand.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cusolver.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cusparse.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.nccl.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.nvjitlink.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.nvtx.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-nvidia.cublas.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/include/pila.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/include/pila.h' '/home/hugo/Documents/programacion/P2E3/include/pila.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/include/pila.h' '/home/hugo/Documents/programacion/P2E3/include/pila.h' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/include/pila.h' '/home/hugo/Documents/programacion/P2E3/include/pila.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/tomli/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-1' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-10' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-1' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-2' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-1' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-4' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-1' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-5' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-1' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-9' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-1' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/KOI8-R' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-1' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1124' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1129' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1124' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM922' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM1124' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP770' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP771' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP772' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP773' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP774' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-14' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/ISO-8859-15' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/CP1256' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/bin/pip' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/bin/pip3' '/home/hugo/Documents/programacion/P2E4/bin/pip' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/bin/pip3.11' '/home/hugo/Documents/programacion/P2E4/bin/pip' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-datasets.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-detectron2.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-datasets.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-fastai.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-datasets.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-fvcore.nn.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-datasets.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-timm.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/_pyinstaller_hooks_contrib/hooks/stdhooks/hook-datasets.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/packaging/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/__init__.py' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/packaging/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/packaging/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-initordera2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-order-a2.c' '/home/hugo/Documents/glibc-2.39/elf/tst-initordera2.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-initorderb1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-order-b1.c' '/home/hugo/Documents/glibc-2.39/elf/tst-initorderb1.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-initordera3.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-order-a3.c' '/home/hugo/Documents/glibc-2.39/elf/tst-initordera3.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-initorderb2.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-order-b2.c' '/home/hugo/Documents/glibc-2.39/elf/tst-initorderb2.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-initordera1.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-order-a1.c' '/home/hugo/Documents/glibc-2.39/elf/tst-initordera1.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-initordera4.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-order-a4.c' '/home/hugo/Documents/glibc-2.39/elf/tst-initordera4.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/_types.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/tomli/_types.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/tomli/_types.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_modf-power5+.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc32/power4/fpu/multiarch/s_modf-power5+.c' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/multiarch/s_modf-power5+.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/librt.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/librt.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/s390/s390-32/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/librt.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc32/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/librt.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/m68k/m680x0/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/librt.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/i386/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/librt.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/librt.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/librt.abilist' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libpthread.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/aarch64/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/powerpc/powerpc64/le/libpthread.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip-24.0.dist-info/top_level.txt' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip-24.0.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/six-1.16.0.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyparsing-3.1.2.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pillow-10.3.0.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/packaging-24.0.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy-1.26.4.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/kiwisolver-1.4.5.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/fonttools-4.51.0.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/cycler-0.12.1.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/python_dateutil-2.9.0.post0.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/contourpy-1.2.1.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/matplotlib-3.8.4.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/altgraph-0.17.4.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyinstaller_hooks_contrib-2024.3.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pyinstaller-6.5.0.dist-info/INSTALLER' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools-65.5.0.dist-info/INSTALLER' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/arm/be/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/arm/le/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/mach/htl/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/htl/Subdirs' '/home/hugo/Documents/glibc-2.39/sysdeps/mach/htl/Implies' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/src/fibonacci.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/src/fibonacci.c' '/home/hugo/Documents/programacion/P2E4/src/fibonacci.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/src/vectordinamico.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/src/vectordinamico.c' '/home/hugo/Documents/programacion/P2E4/src/vectordinamico.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/src/bubblesort.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/src/bubblesort.c' '/home/hugo/Documents/programacion/P2E4/src/bubblesort.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libpthread.abilist' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/le/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libpthread.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sh/be/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libpthread.abilist' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/hppa/libpthread.abilist' '/home/hugo/Documents/glibc-2.39/sysdeps/unix/sysv/linux/sparc/sparc64/libpthread.abilist' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/src/quicksort.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/src/quicksort.c' '/home/hugo/Documents/programacion/P2E4/src/quicksort.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/makefile' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/makefile' '/home/hugo/Documents/programacion/P2E4/makefile' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/include/selectionsort.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/include/selectionsort.h' '/home/hugo/Documents/programacion/P2E4/include/selectionsort.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy-1.26.4.dist-info/WHEEL' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/contourpy-1.2.1.dist-info/WHEEL' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/numpy-1.26.4.dist-info/WHEEL' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/include/bubblesort.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/include/bubblesort.h' '/home/hugo/Documents/programacion/P2E4/include/bubblesort.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/include/quicksort.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/include/quicksort.h' '/home/hugo/Documents/programacion/P2E4/include/quicksort.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/include/vectordinamico.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/coto_florez/include/vectordinamico.h' '/home/hugo/Documents/programacion/P2E4/include/vectordinamico.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/archive/__init__.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/utils/win32/__init__.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/PyInstaller/archive/__init__.py' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/gmon/tst-gmon-pie.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/gmon/tst-gmon-static-pie.c' '/home/hugo/Documents/glibc-2.39/gmon/tst-gmon-pie.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/gmon/tst-gmon-static.c' '/home/hugo/Documents/glibc-2.39/gmon/tst-gmon-pie.c' # duplicate

original_cmd  '/home/hugo/Documents/code_proyects/pngtw/makefile' # original
remove_cmd    '/home/hugo/Documents/code_proyects/classes/makefile' '/home/hugo/Documents/code_proyects/pngtw/makefile' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/fpu/Implies' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/power4/fpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/fpu/Implies' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/be/fpu/Implies' '/home/hugo/Documents/glibc-2.39/sysdeps/powerpc/powerpc64/le/fpu/Implies' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/resolv/tst-leaks2.root/etc/hosts' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/posix/bug-ga2.root/etc/hosts' '/home/hugo/Documents/glibc-2.39/resolv/tst-leaks2.root/etc/hosts' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/elf/tst-tls1-static-non-pie.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/elf/tst-tls1-static.c' '/home/hugo/Documents/glibc-2.39/elf/tst-tls1-static-non-pie.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/nss/tst-initgroups2.root/etc/group' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/nss/tst-initgroups1.root/etc/group' '/home/hugo/Documents/glibc-2.39/nss/tst-initgroups2.root/etc/group' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E5/ini_wrapper.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E5/cotoflorez_5/ini_wrapper.h' '/home/hugo/Documents/programacion/P2E5/ini_wrapper.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E5/cotoflorez_5/main.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E5/main.c' '/home/hugo/Documents/programacion/P2E5/cotoflorez_5/main.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E5/vectordinamico.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E5/cotoflorez_5/vectordinamico.c' '/home/hugo/Documents/programacion/P2E5/vectordinamico.c' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E5/vectordinamico.h' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E5/cotoflorez_5/vectordinamico.h' '/home/hugo/Documents/programacion/P2E5/vectordinamico.h' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E5/ini_wrapper.c' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E5/cotoflorez_5/ini_wrapper.c' '/home/hugo/Documents/programacion/P2E5/ini_wrapper.c' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/doasin.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/doasin.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/dosincos.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_exp2f_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_exp_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/e_exp_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_log2_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/e_log2_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_log2f_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_log_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/e_log_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_logf_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_pow_log_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/e_pow_log_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/e_powf_log2_data.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/k_cosl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/k_sinl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/k_tanf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/k_tanl.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/lgamma_productf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/math_err.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/math_err.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/math_errf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/mpa.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/mpatan.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/mpatan.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/mpatan2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/mpatan2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/mpsqrt.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/i386/fpu/mpsqrt.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/mptan.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/sincos32.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/sincostab.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_exp.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_exp10.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_exp2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/w_exp2f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/w_expf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_fmod.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/w_fmodf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_hypot.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/w_hypotf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_log.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_log2.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/w_log2f.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/w_logf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/dbl-64/w_pow.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/sysdeps/ieee754/flt-32/w_powf.c' '/home/hugo/Documents/glibc-2.39/sysdeps/m68k/m680x0/fpu/branred.c' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Febrero 2006.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/febrero2006.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Febrero 2006.pdf' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Junio 2008.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/ExamenComputadores0708.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Junio 2008.pdf' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/exp2f-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/expf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/exp2f-inputs' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Prácticas/2/S2-ejercicios_tema1-PARTE2.pdf' # original
remove_cmd    '/home/hugo/Downloads/S2-ejercicios_tema1-PARTE2.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Prácticas/2/S2-ejercicios_tema1-PARTE2.pdf' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2013.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/examen_fundcomp_mayo_2013.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2013.pdf' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2011.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/mayo2011.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2011.pdf' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/acosf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/asinf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/acosf-inputs' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/atanhf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/acosf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/acos-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/asin-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/acos-inputs' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/atanh-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/acos-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/erfcf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/erff-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/erfcf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/erf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/erfc-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/erf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/expf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/expm1f-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/expf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/log10f-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/log2f-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/log10f-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/exp-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/expm1-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/exp-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/log10-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/log2-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/log10-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/coshf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/sinhf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/coshf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/log2f-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/logf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/log2f-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cosf-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/sinf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cosf-inputs' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/tanf-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cosf-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cosh-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/sinh-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cosh-inputs' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM930..UTF8' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM939..UTF8' '/home/hugo/Documents/glibc-2.39/iconvdata/testdata/IBM930..UTF8' # duplicate

original_cmd  '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cos-inputs' # original
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/sin-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cos-inputs' # duplicate
remove_cmd    '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/tan-inputs' '/home/hugo/Documents/glibc-2.39/benchtests/libmvec/cos-inputs' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/cli-32.exe' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/cli.exe' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/cli-32.exe' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/helpers.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/helpers.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/helpers.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/six.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/six.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pip/_vendor/six.py' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/gui-32.exe' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/gui.exe' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/gui-32.exe' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/printers.bbclit/ejecutable' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/ejecutable' '/home/hugo/Documents/programacion/P2E3/printers.bbclit/ejecutable' # duplicate

original_cmd  '/home/hugo/Documents/code_proyects/bbclit/libbbclit.a' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/libbbclit.a' '/home/hugo/Documents/code_proyects/bbclit/libbbclit.a' # duplicate
remove_cmd    '/home/hugo/Documents/programacion/P2E3/CotoFlorez_0/printers.bbclit/libbbclit.a' '/home/hugo/Documents/code_proyects/bbclit/libbbclit.a' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E3/actividad_2_PII___2024___impresoras.pdf' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E3/printers.bbclit/actividad_2_PII___2024___impresoras.pdf' '/home/hugo/Documents/programacion/P2E3/actividad_2_PII___2024___impresoras.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitácora_23_R.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitácora_23_R (1).pdf' '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitácora_23_R.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Junio 2008.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/junio2008.pdf' '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Junio 2008.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Exámenes/testmaio11II.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/testmaio11II.pdf' '/home/hugo/Documents/calc/megapack_calculo/Exámenes/testmaio11II.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Junio 2009.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/junio2009.pdf' '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Junio 2009.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Mayo 2008.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/mayo2008.pdf' '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Mayo 2008.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Teoría/Sistemas_Ecuaciones_Lineales_IV.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/Sistemas_Ecuaciones_Lineales_IV.pdf' '/home/hugo/Documents/calc/megapack_calculo/Teoría/Sistemas_Ecuaciones_Lineales_IV.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Teoría/Sistemas_Ecuaciones_Lineales_II.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/Sistemas_Ecuaciones_Lineales_II.pdf' '/home/hugo/Documents/calc/megapack_calculo/Teoría/Sistemas_Ecuaciones_Lineales_II.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Mayo 2011.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/mayo2011.pdf' '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Mayo 2011.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Teoría/Sistemas_Ecuaciones_Lineales_III.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/Sistemas_Ecuaciones_Lineales_III.pdf' '/home/hugo/Documents/calc/megapack_calculo/Teoría/Sistemas_Ecuaciones_Lineales_III.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Mayo 2007.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/mayo2007.pdf' '/home/hugo/Documents/calc/megapack_calculo/Exámenes/Mayo 2007.pdf' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/DEVDRIV.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/DEVDRIV.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/DEVDRIV.DOC' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Teoría/Teoria_CAN-1.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/Teoria_CAN-1.pdf' '/home/hugo/Documents/calc/megapack_calculo/Teoría/Teoria_CAN-1.pdf' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v2.0/bin/SYSCALL.DOC' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v2.0/source/SYSCALL.txt' '/home/hugo/Documents/MS-DOS/v2.0/bin/SYSCALL.DOC' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Teoría/CN_Ec_No_Lineales.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/CN_Ec_No_Lineales.pdf' '/home/hugo/Documents/calc/megapack_calculo/Teoría/CN_Ec_No_Lineales.pdf' # duplicate

original_cmd  '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/PRINTER/CPSFONT.ASM' # original
remove_cmd    '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/PRINTER/CPSFONT3.ASM' '/home/hugo/Documents/MS-DOS/v4.0/src/DEV/PRINTER/CPSFONT.ASM' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Prácticas/8/ejercicios_tema5.pdf' # original
remove_cmd    '/home/hugo/Downloads/ejercicios_tema5.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Prácticas/8/ejercicios_tema5.pdf' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2016.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/mayo2016-2.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2016.pdf' # duplicate

original_cmd  '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/core.py' # original
remove_cmd    '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/setuptools/_vendor/pyparsing/core.py' '/home/hugo/Documents/programacion/P2E4/lib/python3.11/site-packages/pkg_resources/_vendor/pyparsing/core.py' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitacora11.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitacora11 (1).pdf' '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitacora11.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Teoría/thomasintegracionnumerica.ppt' # original
remove_cmd    '/home/hugo/Documents/calc/thomasintegracionnumerica.ppt' '/home/hugo/Documents/calc/megapack_calculo/Teoría/thomasintegracionnumerica.ppt' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitácora_19.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitácora_19 (1).pdf' '/home/hugo/Documents/calc/megapack_calculo/Bitácoras/15-16/Bitácora_19.pdf' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2015.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/mayo2015.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Mayo 2015.pdf' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Apuntes/ApuntesFuCo-2016_160616104451.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/ApuntesFuCo-2016_160616104451.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Apuntes/ApuntesFuCo-2016_160616104451.pdf' # duplicate

original_cmd  '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Julio 2015.pdf' # original
remove_cmd    '/home/hugo/Documents/fundcomp/examenes/examen_computadores_15_jul.pdf' '/home/hugo/Documents/fundcomp/examenes/megapack/Exámenes/Julio 2015.pdf' # duplicate

original_cmd  '/home/hugo/Documents/calc/megapack_calculo/Teoría/teoria_tema2-CAN.pdf' # original
remove_cmd    '/home/hugo/Documents/calc/teoria_tema2-CAN.pdf' '/home/hugo/Documents/calc/megapack_calculo/Teoría/teoria_tema2-CAN.pdf' # duplicate
                                               
                                               
                                               
######### END OF AUTOGENERATED OUTPUT #########
                                               
if [ $PROGRESS_CURR -le $PROGRESS_TOTAL ]; then
    print_progress_prefix                      
    echo "${COL_BLUE}Done!${COL_RESET}"      
fi                                             
                                               
if [ -z $DO_REMOVE ] && [ -z $DO_DRY_RUN ]     
then                                           
  echo "Deleting script " "$0"             
  rm -f '/home/hugo/dotfiles/rmlint.sh';                                     
fi                                             
