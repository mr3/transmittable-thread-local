#!/bin/bash
# SDKMAN! with Travis
# https://objectcomputing.com/news/2019/01/07/sdkman-travis
set -eEuo pipefail

[ -z "${__source_guard_37F50E39_A075_4E05_A3A0_8939EF62D836:+dummy}" ] || return 0
__source_guard_37F50E39_A075_4E05_A3A0_8939EF62D836="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=common.sh
source "$__source_guard_37F50E39_A075_4E05_A3A0_8939EF62D836/common.sh"

__loadSdkman() {
    # install sdkman
    if [ ! -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
        [ -d "$HOME/.sdkman" ] && rm -rf "$HOME/.sdkman"

        curl -s get.sdkman.io | bash || die "fail to install sdkman"
        {
            echo sdkman_auto_answer=true
            echo sdkman_disable_auto_upgrade_check=false

            # sdkman reports offline mode (which is not)
            #   https://github.com/sdkman/sdkman-cli/issues/397
            echo sdkman_curl_connect_timeout=30
            echo sdkman_curl_max_time=50
        } >>"$HOME/.sdkman/etc/config"
    fi

    set +u
    # shellcheck disable=SC1090
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    logAndRun sdk ls java
    set -u
}
__loadSdkman

jdks_install_by_sdkman=(
    7.0.282-zulu
    8.0.282-zulu

    9.0.7-zulu
    10.0.2-zulu
    11.0.10-zulu

    12.0.2-open
    13.0.5-zulu
    14.0.2-zulu
    15.0.2-zulu
    16.ea.34-open
    17.ea.8-open
)
java_home_var_names=()

__setJdkHomeVarsAndInstallJdk() {
    blueEcho "prepared jdks:"

    if [ -n "${JDK6_HOME:-}" ]; then
        java_home_var_names=(JDK6_HOME)
        printf '%s :\n\t%s\n' "JDK6_HOME" "${JDK6_HOME}"
    else
        if [ -d /usr/lib/jvm/java-6-openjdk-amd64 ]; then
            JDK6_HOME=/usr/lib/jvm/java-6-openjdk-amd64
            java_home_var_names=(JDK6_HOME)
            printf '%s :\n\t%s\n' "JDK6_HOME" "${JDK6_HOME}"
        elif [ -d /Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home ]; then
            JDK6_HOME=/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home
            java_home_var_names=(JDK6_HOME)
            printf '%s :\n\t%s\n' "JDK6_HOME" "${JDK6_HOME}"
        fi
    fi

    local jdkNameOfSdkman
    for jdkNameOfSdkman in "${jdks_install_by_sdkman[@]}"; do
        local jdkVersion
        jdkVersion=$(echo "$jdkNameOfSdkman" | awk -F'[.]' '{print $1}')

        # jdkHomeVarName like JDK7_HOME, JDK11_HOME
        local jdkHomeVarName="JDK${jdkVersion}_HOME"

        if [ ! -d "${!jdkHomeVarName:-}" ]; then
            local jdkHomePath="$SDKMAN_CANDIDATES_DIR/java/$jdkNameOfSdkman"

            # set JDK7_HOME ~ JDK1x_HOME to global var java_home_var_names
            eval "$jdkHomeVarName='${jdkHomePath}'"

            # install jdk by sdkman
            [ ! -d "$jdkHomePath" ] && {
                set +u
                logAndRun sdk install java "$jdkNameOfSdkman" || die "fail to install jdk $jdkNameOfSdkman by sdkman"
                set -u
            }
        fi

        java_home_var_names=("${java_home_var_names[@]}" "$jdkHomeVarName")
        printf '%s :\n\t%s\n\tspecified is %s\n' "$jdkHomeVarName" "${!jdkHomeVarName}" "$jdkNameOfSdkman"
    done

    echo
    blueEcho "ls $SDKMAN_CANDIDATES_DIR/java/ :"
    ls -la "$SDKMAN_CANDIDATES_DIR/java/"
}
__setJdkHomeVarsAndInstallJdk

switch_to_jdk() {
    [ $# == 1 ] || die "${FUNCNAME[0]} need 1 argument! But provided: $*"

    local javaHomeVarName="JDK${1}_HOME"
    export JAVA_HOME="${!javaHomeVarName}"

    [ -n "$JAVA_HOME" ] || die "jdk $1 env not found: $javaHomeVarName"
    [ -e "$JAVA_HOME" ] || die "jdk $1 not existed: $JAVA_HOME"
    [ -d "$JAVA_HOME" ] || die "jdk $1 is not directory: $JAVA_HOME"
}
