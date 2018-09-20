#!/usr/bin/env bash

function error(){
    echo  -e "\033[31m $1 \033[0m" >&2
}
#各种正则，注意除line_contains_cn_reg外，都只有sed可用。
java_doc_comment_reg='/\/\*/,/\*\//'
java_common_comment_reg='/^[ ]*\/\//'
xml_comment_reg='/<!--/,/-->/'
log_reg='/^[ ]*XLog\./'
xml_tools_reg='/^[ ]*tools:/'

#配置##############
out_dir='build/hard_code'
all_out="${out_dir}/all.txt"
ignore_config='shells/.hard_code_ignore.properties'
rule_config='shells/hard_code_config.properties'
comment_reg='^\s*#.*'
settings="settings.gradle"
divider='###############################################################'
##################
#检查#########
setting_file_exists=$(ls | grep ${settings})
build_file_exists=$(ls | grep build.gradle)
if ! [[ $setting_file_exists ]] || ! [[ ${build_file_exists} ]] ; then
    error '非工程目录'
    exit 1
fi
##################
if ! [[ -d build ]]; then
    mkdir build
fi

if ! [[ -d ${out_dir} ]]; then
    mkdir -p ${out_dir}
fi
ignorelist="${out_dir}/ignorelist"
echo '#all ignore list' >${ignorelist}
echo -e "#生成时间：$(date)\n\n" >>${ignorelist}
git log -1 | sed -E 's/.*/#&/' >>${ignorelist}

#init
ignore=()
rules=()
index=0
if [[ -f ${ignore_config} ]]; then
    for item in $(pcregrep -v ${comment_reg} ${ignore_config})
      do
          ignore[${index}]=${item}
          index=${index}+1
      done
fi
index=0
if [[ -f ${rule_config} ]]; then
    for item in $(pcregrep -v ${comment_reg} ${rule_config})
      do
          rules[${index}]=${item}
          index=${index}+1
      done
fi

#############

target=$1
if ! test ${target}; then
      error '请指定module,使用-a指定所有'
      exit 1
fi







function tip(){
    printf '开始扫描目录%s\n' $1
}

function ignore_this(){
 local file=$1
 for item in ${ignore[@]}
 do
      echo ${file} | pcregrep -q ${item}
      if [[ $? -eq 0  ]]; then
          echo ${file} >>${ignorelist}
          return 0
      fi
 done
      return 1

}
function handleFile(){

  local target_module=${1//./}
  local target_file=$2
  local module_out_dir="${out_dir}${target_module}"
  local module_out="${module_out_dir}/out.txt"
  local flag=1
  if ! [[ -d ${module_out_dir} ]]; then
      mkdir -p ${module_out_dir}
      echo "生成时间：$(date)">${module_out}
      echo -e "\n\n\n" >>${module_out}
  fi
 for item in ${rules[@]}
 do
       local result=$(sed "${java_doc_comment_reg}d;${java_common_comment_reg}d;${xml_comment_reg}d;${xml_tools_reg}d;${log_reg}d" ${target_file} | pcregrep  -M ${item} )
      if [[ ${result} ]]; then
        if [[ ${flag} -ne  0 ]]; then
          echo ${divider}${target_file}${divider} >>${all_out}
          echo ${divider}${target_file}${divider} >>${module_out}
        fi
          echo "${result}" >>${all_out}
          echo "${result}" >>${module_out}
          flag=0
      fi
 done
 if [[ ${flag} -eq  0 ]]; then
      echo -e "\n\n\n" >>${module_out}
      echo -e "\n\n\n" >>${all_out}
 fi
}

function handleDir(){

    local target_module=$1
    local target_dir=$2
    for file in $(ls ${target_dir} )
        do
            local temp=${target_dir}'/'${file}
              ignore_this ${temp}
             if [[ $? -eq 0 ]] ; then
                continue
             fi
            if test -d ${temp} ; then
                tip ${temp}
                handleDir ${target_module} ${temp}
            else
                handleFile ${target_module} ${temp}
            fi
        done
}


function handle_module(){
    local target=${1}
    local java_src="${target}/src"
    echo  -e "\033[31m 开始处理module:${target} \033[0m"
    rm -r "${out_dir}${target//./}"
    handleDir ${target} ${java_src}
}

all_fields=$(sed -E '/\s*\/\//d;s#include##g' ${settings})
all_fields=${all_fields// /}
if [[ ${target} == '-a' ]]; then
    count=$(echo ${all_fields} | grep -o ',' | wc -l)
    rm ${all_out}
    echo -e "生成时间：$(date)\n\n" >>${all_out}
for ((index=1;index<=count+1;index++));
     do
        field=$(echo ${all_fields} | cut -d ',' -f ${index})
        field=${field//\'/}
        field=${field// /}
        field=".${field//:/\/}"
        if [[ -d ${field} ]]; then
            handle_module ${field}
        fi
     done
else
    field=$(pcregrep  -o "(:\w+)*:${target}\b" ${settings})
    if [[ $? -eq 0 ]]; then
        field=".${field//:/\/}"
        if [[ -d ${field} ]]; then
            handle_module ${field}
        fi
    else
    error '该module不存在'
    fi
fi

