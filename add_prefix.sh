#!/usr/bin/env bash


  echo '请输入前缀:'
    read prefix;
    if ! [[ ${prefix} =~ [0-9a-zA-Z]+_ ]]; then
        echo  -e "\033[31m 前缀含有非法字符或没有以_结尾！ \033[0m" >&2
        exit 1
    fi
function handleDir(){
    local target=${1}
    if ! test ${target}; then
    exit 1
    fi
    for file in $(ls ${target} )
        do
            local temp=${target}'/'${file}
            if test -d ${temp} ; then
            if  [[ ${file} != 'values' ]]; then
                handleDir ${temp}
            fi
            else
                dst=$(echo ${temp} | sed -E "s#(.*/)((${prefix})*)(.*)#\1${prefix}\4#g")
              if ! [[ -f ${dst} ]]; then
                    echo "mv $temp $dst"
                    mv ${temp} ${dst}
              fi
            fi
        done
}
handleDir $1