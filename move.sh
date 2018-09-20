#!/usr/bin/env bash
    function error(){
        echo  -e "\033[31m $1 \033[0m" >&2
    }
    name_reg='[0-9a-zA-Z_+]'
    app_srcPath="app/src/main/res"
    base_srcPath="common/baselibs/src/main/res"
    targetModulePath=$1
    targetFilePath=$2
    if ! [[ ${targetFilePath} ]]; then
        targetFilePath=${targetModulePath}/src
    fi
    java_doc_comment_reg='/\/\*/,/\*\//'
    java_common_comment_reg='/^\s*\/\//'
    targetPath="${targetModulePath}/src/main/res"
    parentPath=$(pwd)
    white_reg="color|dimen|string|style"
    res_white_reg="zxing_.*|temp_.*|top_view|common_title_right|iv_title_left"
    module_name=$(echo ${targetModulePath} | sed -r "s#${parentPath}/##g")
    onclick_regex='@\s*OnClick\s*\(\s*\{\s*(R\s*(\s*\.\s*\w+\s*){2},\s*)*R\s*(\s*\.\s*\w+\s*){2}\}\s*\)'
    echo "目标目录：$targetPath"
    #echo '请输入前缀:'
    #read prefix;
    #if ! [[ ${prefix} =~ ${name_reg}+_ ]]; then
    #    echo  -e "\033[31m 前缀含有非法字符或没有以_结尾！ \033[0m" >&2
    #    exit 1
    #fi
    prefix=$(pcregrep -o 'resourcePrefix\s*"\w+"' "${targetModulePath}/build.gradle")
    if ! [[ $? -eq 0 ]]; then
        error '未找到前缀配置'
        exit 1
    fi
    prefix=$(echo ${prefix//\"/} | cut -d ' ' -f 2)
    echo "前缀：${prefix}"
    manifest=$(./gradlew "$(echo ${targetModulePath} | sed "s#$(pwd)##g;s#/#:#g"):sourS" |  pcregrep -oM '^Manifest file.*/main/.*$' | head -1 | cut -d : -f 2)
    pkg_name=$(pcregrep -oM '<manifest[^>]*' ${manifest} |  grep -o -E  'package\s*=\s*"[^"]*"' | cut -d = -f 2)
    pkg_name=${pkg_name//\"/}
    echo "module:${targetModulePath}的包名:${pkg_name}"
    #read pkg_name;
    ##验证包名是否正确
    #reg_path="${targetModulePath}/build/generated/source/r/.*/${pkg_name//.//}/R.java"
    #if ! test $(find ${targetModulePath} -regex ${reg_path} | head -1); then
    #    echo  -e "\033[31m error:包名非法！ \033[0m" >&2
    #    exit 1
    #fi
function copy(){
          local name=${1// /}
          name="${name/#${prefix}/}"
          local dstfile=$(find ${targetPath} -type f -name ${prefix}${name}\.*)
          if [[ -f ${dstfile} ]]; then
              return
          fi
          local src=$(find ${app_srcPath} -type f -name ${name}\.*)
          if ! [[ ${src} ]]; then
              src=$(find ${base_srcPath} -type f -name ${name}\.*)
          fi
          if ! [[ ${src} ]]; then
              error "未找到资源：${name},位于文件：${2}"
          fi
          if [[ ${src} ]] && ! [[ ${dstfile}  ]] ; then
              for file in ${src}
              do
              local dst=$(echo ${file} | sed -r "s#(app|common/baselibs)#${module_name}#;s#(.*/)(.*)#\1${prefix}\2#")
              local dstDir=$(echo ${dst} | sed -r 's#/[^/]*$##g')
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
           for item in $(pcregrep -o  "R\.\s*(?!(${white_reg}|id))\s*\w+\.\s*(?!(${res_white_reg}))\w+" ${fileName} )
             do
              local name=$(echo ${item}  | sed -E "s/R\.${name_reg}+\.//g")
              #copy资源
              copy ${name} ${fileName}
           done
           #加前缀
           sed  -r -i "\
           ${java_common_comment_reg}!{\
           /R\s*\.\s*(${white_reg})\s*\.\s*\w+/!{\
           /R\s*\.\s*\w+\s*\.\s*(${res_white_reg})/!{\
           s/(\s*R\s*\.\s*${name_reg}+\s*\.\s*)(${prefix})*(${name_reg}+\s*)/\1${prefix}\3/g\
           }\
           }\
           }" ${fileName}
                      #s/^\s*import\s+com\.pingan\.smt\.R/import ${pkg_name}.R/g;\
           #s#(R\s*\.\s*(${white_reg})\s*\.\s*)((${prefix})+)(\w+)#\1\5#g;s#(R\.\w+\.)((${prefix})+)(${res_white_reg})#\1\4#g\

           #去除butterknife导包
           sed -r -i "/^\s*import\s+butterknife\..*$/d" ${fileName}
            #生成findViewById();
            local all_fields=$(pcregrep -M -o "@\s*BindView\s*\(\s*R(\s*\.\s*${name_reg}+\s*){2}\)\s+${name_reg}+\s+${name_reg}+;" ${fileName})
            local count=$(echo ${all_fields} | grep -o '@' | wc -l)
            for ((index=1;index<=count+1;index++));
            do
              local field=$(echo ${all_fields} | cut -d '@' -f ${index})
              local statement=$(echo ${field} | sed -r 's#BindView\s*(\s*\(R(\s*\.\s*\w+\s*){2}\))\s+(\w+)\s+(\w+)#\4=(\3)findViewById\1#g')
              if [[ ${statement} ]]; then
              sed -i -r "/^.*ButterKnife\s*\.bind\s*\(.*\).*$/i${statement}" ${fileName}
              fi
            done
            #删除BindView注解
            sed -i -r "s#@\s*BindView\s*\(\s*R(\s*\.\s*\w+\s*){2}\)##g" ${fileName}
        #    生成OnClick();
        #    @OnClick({ R.id.tv_near, R.id.tv_sort })

              local all_click=$(pcregrep -M -o "${onclick_regex}" ${fileName}  | sed -r 's/@\s*OnClick\s*\(\s*\{\s*//g;s/\s*\}\s*\)//g')
              local click_count=$(echo ${all_click} | grep -o ',' | wc -l)
            for ((index=1;index<=click_count+1;index++));
            do
                   local field=$(echo ${all_click} | cut -d ',' -f ${index} | cut -d '.' -f 3)
                   local click_set=$(sed -n -r "s#(\w+)\s*=.*findViewById\s*\(\s*R\s*\.\s*id\s*\.\s*${field}\s*\)\s*;#\1.setOnClickListener(this);#gp" ${fileName})
                   if [[ ${click_set} ]]; then
                        grep ${click_set} ${fileName}
                       if [[ $? -eq 1 ]] ; then
                          sed -i -r "/^.*ButterKnife\s*\.bind\s*\(.*\).*$/a${click_set}" ${fileName}
                        fi
                   fi
            done
              #改方法签名
                local click_m=$(pcregrep -M -o "${onclick_regex}" ${fileName} | tail -1)
                local new_click_m=$(echo ${click_m} | sed -r  -n "s#(\w+\s\w+\s)\w+\s*(\(.*\))#\1onClick\2#pg")
                if [[ ${new_click_m} ]]; then
                    click_m=${click_m//(/\\(}
                    click_m=${click_m//)/\\)}
                    sed -i -r "s#${click_m}#${new_click_m}#g" ${fileName}
                fi

        fi



        if [[ ${fileName} =~ .*\.xml ]]; then
            for item in $(pcregrep -o  "@(?!(${white_reg}|\+*id))\w+/(?!(${res_white_reg}))\w+" ${fileName} )
             do
                local name=$(echo ${item}  | sed -E "s/@(\w|\+)+\///g")
                copy ${name} ${fileName}
            done
            sed   -r -i "/@(${white_reg})\/(\w|\+)+/!{/@(\w|\+)+\/(${res_white_reg})/!{s/(@(\w|\+)+\/)(${prefix})*(\w+)/\1${prefix}\4/g}}"\
            ${fileName}
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

if [[ -d ${targetFilePath} ]]; then
    handleDir ${targetFilePath}
elif [[ -f ${targetFilePath} ]];then
    handleFile     ${targetFilePath}
fi

