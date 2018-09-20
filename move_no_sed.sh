#!/usr/bin/env bash

    name_reg='[0-9a-zA-Z_]'
    srcPath="app/src/main/res"
    targetModulePath=$1
    targetPath="${targetModulePath}/src/main/res"
    parentPath=$(pwd)
    module_name=$(echo ${targetModulePath} | sed "s#${parentPath}/##g")
    echo "目标目录：$targetPath"
    echo '请输入前缀:'
    read prefix;
    if ! [[ ${prefix} =~ ${name_reg}+_ ]]; then
        echo  -e "\033[31m 前缀含有非法字符或没有以_结尾！ \033[0m" >&2
        exit 1
    fi
    #prefix=''
function copy(){
          local name=${1// /}
          local src=$(find ${srcPath} -type f -name ${name}\.*)
          local dstfile=$(find ${targetPath} -type f -name ${prefix}${name}\.*)
          if [[ ${src} ]] && ! [[ ${dstfile}  ]] ; then
             #cp ${srcPath}/${path} ${targetPath}/${path}
              for file in ${src}
              do
              local dst=$(echo ${file} | sed -E "s#app#${module_name}#;s#${name_reg}\..*\$#${prefix}&#")
              local dstDir=$(echo ${dst} | sed -E 's#/[^/]*$##g')
              if ! [[ -d ${dstDir} ]]; then
               echo "mkdir $dstDir"
               mkdir ${dstDir}
              fi
              echo "cp  -f ${file}   ${dst}"
               cp  -f ${file}   ${dst}
              done

          fi
}


function handleFile(){
        local fileName=$1;
        if [[ ${fileName} =~ .*\.java ]]; then
           for item in $(grep -o -E "R(\.${name_reg}+){2}" ${fileName} )
            do
             local name=$(echo ${item}  | sed -E "s/R\.${name_reg}+\.//g")
             copy ${name}
            done

        fi
        if [[ ${fileName} =~ .*\.xml ]]; then
            for item in $(grep -o -E "@${name_reg}+/${name_reg}+" ${fileName} )
            do
            local name=$(echo ${item}  | sed -E "s/@${name_reg}+\///g")
             copy ${name}
            done
        fi
}
function handleDir(){
    local target=${1}
    if ! test ${target}; then
    exit 1
    fi
    for file in $(ls ${target} )
        do
            local temp=${target}'/'${file}
            if test -d ${temp} ; then
                handleDir ${temp}
            else
                handleFile ${temp}
            fi
        done
}



handleDir ${targetModulePath}/src
