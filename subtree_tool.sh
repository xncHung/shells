#!/usr/bin/env bash
function error(){
    echo  -e "\033[31m $1 \033[0m" >&2
}
config='shells/subtrees.config'
if ! [[ -f ${config} ]]; then
    error '无subtrees.config文件'
    exit 1
fi
action=$1
remote=$2
branch=$3
if ! [[ ${branch} ]] || ! [[ ${action} ]] || ! [[ ${remote} ]]; then
    error '参数非法，请依次指定以下参数，action(push pull add ),remote,remote_branch'
    exit 3
fi

result=$(grep -E "\\\$${remote}\\\$" ${config})
if ! [[ ${result} ]]; then
    error "无此远程配置:${remote}，请检查配置文件${config}"
    exit 2
fi
num=$(echo -n  ${result} | wc -l)
if [[ ${num} -gt 1 ]]; then
  error '找到多个配置'
  exit 4
fi
dir=$(echo ${result} | cut -f 1 -d \$)
url=$(echo ${result} | cut -f 3 -d \$)
git remote | grep -q -E "^${remote}\$"
  if [[ $? -eq 1 ]]; then
	    git remote add ${remote} ${url}
  fi
  if [[ -d ${dir} ]]; then
	    git subtree ${action} --prefix=${dir} ${remote} ${branch}
  fi
