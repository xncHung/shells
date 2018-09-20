#!/usr/bin/env bash
#使用前先确保已经安装jq.
# https://stedolan.github.io/jq/
#请在工程目录新建shells/actLaunchConf.json文件，编辑json配置
#{
#  "useUsb": 使用usb设备，反之使用模拟器,默认为true，非必须
#  "module_name":"应用module名，一般为app，必须配置",
#  "appId":"应用id，在gradle文件中可找到，非必须",
#  "variant":"构建变体，在gradle配置，如betaDebug，必须配置"
#
#
#  "目标activity的全名": {
#    "intentkey": {
#      "type": "类型",
#      "value": "值"
#    }
#   }
#}
#类型map:
#s=String
#i=int
#b=boolean
#l=long
#f=float
#ia=int array
#la=long array
#fa=float array
#sa=string array


#example:
#如要打开com.haha.test应用下的com.haha.test.targetActivity,并向其以"testString"为key传"I am testString",以"testIntArray"传int数组{1，2，3，4}，则可这样定义json
#{
#
#
#  "com.haha.test.targetActivity": {
#    "testString": {
#      "type": "s",
#      "value": "I am testString"
#    }
#
#    "testIntArray":{
#       "type":"ia"
#       "value":[
#                    1,
#                    2,
#                    3,
#                    4
#                ]
#    }
#   }
#
#}
#启动Activity,sh startAct.sh targetAct,如要启动com.haha.test.targetActivity，运行sh startAct.sh com.haha.test.targetActivity

cfg_file="shells/actLaunchConf.json"

function error(){
    echo  -e "\033[31m $1 \033[0m" >&2
}

function attachExtra(){
    local params=$1
    keys=$(echo ${params} | jq '. | keys[]')
    result=" "
    for key in ${keys}
        do
            local item=$(echo ${params} | jq .[${key}])
            local type=$(echo ${item} | jq -r .type)
            local value=$(echo ${item} | jq --indent 0  .value)
            value=${value/#[/"\""}
            value=${value/%]/"\""}
            case ${type} in
            "s")
            result="${result}  --es ${key} ${value} "

            ;;
            "i")
            result="${result} --ei ${key} ${value} "

            ;;
            "b")
            result="${result} --ez ${key} ${value} "

            ;;
            "l")
            result="${result} --el ${key} ${value} "

            ;;
            "f")
            result="${result} --ef ${key} ${value} "

            ;;
            "ia")
            result="${result} --eia ${key} ${value} "

            ;;
            "la")
            result="${result} --ela ${key} ${value} "

            ;;
            "fa")
            result="${result} --efa ${key} ${value} "

            ;;
            "sa")
            result="${result} --esa ${key} ${value} "

            ;;
            esac
        done
        echo ${result}
}
#检查参数
target=$1
if ! [[ ${target} ]]; then
    error '未指定activity'
    exit 6
fi

module=$(jq -r '.module_name' "${cfg_file}")
if ! [[ ${module} ]]; then
    error '未配置打包的模块名，请参照脚本的注释内容配置'
    exit 1
fi


variant_conf=$(jq -r '.variant' "${cfg_file}" | perl -pe '{s/\b\w/\l$&/g}')
variant=$(echo ${variant_conf} | perl -pe '{s/\b\w/\u$&/g}')
if ! [[ ${variant} ]]; then
    error '未配置打包的构建变体，请参照脚本的注释内容配置'
    exit 8
fi

echo "target is ${target}"

hasExtra=$(jq "has(\"${target}\")" "${cfg_file}")
echo "has extra :${hasExtra}"



#检查设备
count=$(($(adb devices | wc -l) - 2 ))
if [[ ${count} -eq 0 ]]; then
    error 'error:no devices found'
    exit 2
fi


#选择设备
if [[ ${count} -gt 1 ]]; then
   useUsb=$(jq -r '.useUsb' "${cfg_file}")
   type=''
   typeDesc='usb设备'
   deviceConfig='-d'
   if [[ ${useUsb} == false ]]; then
      error 'use emulator'
      typeDesc='模拟器'
      type='-v'
      deviceConfig='-e'
   fi
   devCount=$(( $(adb devices -l | grep 'device ' | grep ${type} ' usb:' | wc -l) ))
   if [[ ${devCount} -eq 0 ]]; then
     error "你已经指定使用${typeDesc}，却未找到任何${typeDesc}"
     exit 3
   fi
   if [[ ${devCount} -gt 1 ]]; then
       all_dev=$(adb devices -l | grep 'device ' | grep ${type} ' usb:' | grep -n '')
       echo -e "one more dev found:\n${all_dev}\ntype num to select one"
       read num
       if ! [[ num=~[0-9] ]]; then
         error '请输入编号'
         exit 4
       fi
       if [[ $((num)) -gt ${devCount} ]] || [[ $((num)) -lt 1 ]] ; then
         error '编号不存在'
         exit 5
       fi
       serialNum=$(echo ${all_dev} | head -${num} | tail -1 | cut -d ' ' -f 1 | cut -d : -f 2)
       deviceConfig=" -s ${serialNum}"
   fi
else
   deviceConfig=''
fi



#是否是debug模式
echo -n 'debug(y/n)?:'
read -t 5 debug
echo ''

#是否要重装
echo -n 'reinstall(y/n)?:'
read -t 5 reassemble
echo ''

#打包
if [[ ${reassemble} == y ]]; then
    if [[ $((count)) -eq 1 ]]; then
        ./gradlew ":${module}:install${variant}" 
    else
       ./gradlew ":${module}:assemble${variant}"
    fi
    if ! [[ $? -eq 0 ]]; then
        error "打包失败！"
        exit 10
    fi
fi



#获取输出日志
reg=$(echo ${variant_conf} | perl -pe '{s/\B[A-Z]/[a-z]*$&/g}')
out_path=$(./gradlew ":${module}:consConAttr" | pcregrep -oM "^${reg}[a-z]*RuntimeElements\s(^\s.*\s)*" | pcregrep -oM '^\s+ConfigurationVariant\s*:\s*apk\s*Artifact\s*:\s*[\w/\\]*' | pcregrep -oM '^\s*Artifact\s*:\s*[\w/\\]*' | cut -d : -f 2)
output_json_path="${out_path// /}/output.json"
if ! [[ -f ${output_json_path} ]]; then
    if [[ ${reassemble} == y ]] ; then
         error "未找到打包的日志文件：${output_json_path}"
         exit 10
     else
         error "未找到打包的日志文件：${output_json_path},appId将尝试使用${cfg_file}中的配置"
         appId=$(jq -r '.appId' "${cfg_file}")
         if [[ ${appId} ]]; then
             error '未配置appId,请参照脚本的注释内容配置'
         fi
    fi
else
    apk_path="${out_path}/$(jq -r .[0].path ${output_json_path})"
    appId=$(jq -r .[0].properties.packageId ${output_json_path})
fi



#生成命令
adb ${deviceConfig} shell am force-stop ${appId}
cmd="adb ${deviceConfig} shell am start  -n ${appId}/${target} -a android.intent.action.MAIN -c android.intent.category.LAUNCHER"
if [[ ${debug} == y ]]; then
  cmd="${cmd} -D"
fi
#添加参数
if [ "true" == "${hasExtra}" ];
    then
        params=$(attachExtra   "$(jq ".[\"${target}\"]" "${cfg_file}")")
        cmd="${cmd} ${params}"
fi
if [[ ${reassemble} == y ]] && ! [[ $((count)) -eq 1 ]]; then
  adb ${deviceConfig} install -r -t ${apk_path}
fi
if [[ $? -eq 0 ]]; then
  echo ${cmd} && ${cmd}
fi
