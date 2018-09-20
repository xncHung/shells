#!/usr/bin/env bash
#subtree 添加脚本，请不要修改这个文件
txt='# subtree 配置文件，请不要随意修改\n
# 子目录$子目录跟踪的远程库$库地址$远程分支 如：sample$sample$master指本地的sample目录跟踪远程库sample的master分支\n
app/src/main/assets/configSystem$configSys$http://git-ma.paic.com.cn/paSmartcity/configSystem.git$master\n'
config='shells/subtrees.config'
if ! [[ -f ${config} ]]; then
    touch subtrees.config && echo -e  ${txt} > ${config}
fi
for item in $(grep -v -E '^\s*#' ${config})
    do
      dir=$(echo ${item} | cut -f 1 -d \$)
      repo=$(echo ${item} | cut -f 2 -d \$)
      url=$(echo ${item} | cut -f 3 -d \$)
      branch=$(echo ${item} | cut -f 4 -d \$)
      git remote | grep -q -E "^${repo}\$"
        if [[ $? -eq 1 ]]; then
	          git remote add ${repo} ${url}
	      else
	          git remote set-url ${repo} ${url}
        fi
   done

