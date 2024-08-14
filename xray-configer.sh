# XRAY_SUB_URL=""
# XRAY_CONFIG_PATH=""
HOME_DIR="/etc/xrayconfiger"
OUTPUT_CONFIGS_DIR="$HOME_DIR/configs"
TEMLATES_DIR="$HOME_DIR/templates"
LOGS_DIR="$HOME_DIR/logs"
GH_PROXY='https://mirror.ghproxy.com/'

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m"; exit 1; }  # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }

ensure_env() {
    check_operating_system
    [ ! $(type -p xray) ] && error "xray not found, please install xray first. see https://github.com/XTLS/Xray-install/tree/main $(xray)"

    # find xray config file path
    if [ "$SYSTEM" = "Debian" ] || [ "$SYSTEM" = "Ubuntu" ] || [ "$SYSTEM" = "CentOS" ]; then
        xray_config_path=$(systemctl show xray | grep ExecStart | grep -oP '(?<=-config\s)[^;]+' | awk '{$1=$1};1')
        if [ -z "$xray_config_path" ]; then
            error "Can not find xray config path. Maybe xray can't be called by systemctl."
        else
            echo "Find xray config path in systemctl: \"$xray_config_path\""
        fi
    elif [ -n "$XRAY_CONFIG_PATH" ]; then
        echo "Find xray config path in environment variable: XRAY_CONFIG_PATH: $XRAY_CONFIG_PATH"
        xray_config_path=$XRAY_CONFIG_PATH
    else
        error "Can not find xray config path. Please set XRAY_CONFIG_PATH environment variable (it MUST BE set in profile，such as ~/.bashrc file), and run 'bash $0 install' again."
    fi

    [ -z "$XRAY_SUB_URL" ] && error "Please set XRAY_SUB_URL environment variable (it MUST BE set in profile，such as ~/.bashrc file), and run 'bash $0 install' again.\n e.g.:\n export XRAY_SUB_URL=https://sub.example.com/sub?target=xray \n bash $0 install"

    [ ! -d "$HOME_DIR" ] && mkdir -p $HOME_DIR
    [ ! -d "$OUTPUT_CONFIGS_DIR" ] && mkdir -p $OUTPUT_CONFIGS_DIR
    [ ! -d "$TEMLATES_DIR" ] && mkdir -p $TEMLATES_DIR
    [ ! -d "$LOGS_DIR" ] && mkdir -p $LOGS_DIR
    return 0

}
check_subscribe_changed() {
    info "Checking if subscribe changed..."
    local sub_latest="$(curl -s "$XRAY_SUB_URL")"

    # 对sub_latest进行base64解码
    if ! temp_sub_latest=$(echo "$sub_latest" | base64 -di 2>/dev/null); then
        # base64解码失败，直接校验原始数据格式
        echo "$sub_latest" | grep -E '^(vless://|vmess://|ss://|trojan://)' > /dev/null
        [ $? -eq 0 ] && decoded_sub_latest="$sub_latest" || error "Cannot find any valid subscription config node from your subscription link. (original data)"
    else
        # base64解码成功
        echo "$temp_sub_latest"
        echo "$temp_sub_latest" | grep -E '^(vless://|vmess://|ss://|trojan://)' > /dev/null
        [ $? -eq 0 ] && decoded_sub_latest="$temp_sub_latest" || error "Cannot find any valid subscription config node from your subscription link. (decoded data)"
    fi
    if [ -f "$HOME_DIR/sub.txt" ]; then
        [ "$(cat $HOME_DIR/sub.txt)" != "$decoded_sub_latest" ] && return 0 || return 1
    else
        return 0
    fi
}

update_configs_and_restart() {
    fetch_configs
    start_with_new_config
}

fetch_configs() {
    check_subscribe_changed
    if [[ $? -eq 1 ]]; then
        echo "Subscribe not changed, skipping..."
        exit 0
    fi
    # [ -f "$HOME_DIR/sub.txt" ] && echo "Updating subscribe..." || echo "Creating subscribe..."
   
    nodes=$HOME_DIR/nodes.txt
    echo "$decoded_sub_latest" > $HOME_DIR/sub.txt
    echo -n "" > $nodes
    rm -rf $OUTPUT_CONFIGS_DIR/*
    local counter=1
    while read line; do
        if [ $counter -gt 100 ]; then
            break
        fi
        echo "Config ==> $counter, $line"
        local json_info=$(transform_to_json "$line")
        echo $json_info

        local protocol=$(echo $json_info | jq -r '.protocol')
        local net=$(echo $json_info | jq -r '.net')
        local type=$(echo $json_info | jq -r '.type')
        local remark=$(echo $json_info | jq -r '.remark')
        local idx=$(printf "%02d" $counter)

        if [ "$protocol" = "vmess" ] && [ "$net" = "ws" ]; then
            info "Find protocol: vmess_ws"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_vmess_ws.json ${OUTPUT_CONFIGS_DIR}/${idx}_vmess_ws.json
            echo "["$idx"]" "(vmess_ws) $remark" >> $nodes
        elif [ "$protocol" = "vmess" ] && [ "$net" = "tcp" ]; then
            info "Find protocol: vmess_tcp"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_vmess_tcp.json ${OUTPUT_CONFIGS_DIR}/${idx}_vmess_tcp.json
            echo "["$idx"]" "(vmess_tcp) $remark" >> $nodes
        elif [ "$protocol" = "vless" ] && [ "$type" = "ws" ]; then
            info "Find protocol: vless_ws"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_vless_ws.json ${OUTPUT_CONFIGS_DIR}/${idx}_vless_ws.json
            echo "["$idx"]" "(vless_ws) $remark" >> $nodes
        elif [ "$protocol" = "vless" ] && [ "$type" = "tcp" ]; then
            info "Find protocol: vless_tcp"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_vless_tcp.json ${OUTPUT_CONFIGS_DIR}/${idx}_vless_tcp.json
            echo "["$idx"]" "(vless_tcp) $remark" >> $nodes
        elif [ "$protocol" = "trojan" ] && [ "$type" = "ws" ]; then
            info "Find protocol: trojan_ws"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_trojan_ws.json ${OUTPUT_CONFIGS_DIR}/${idx}_trojan_ws.json
            echo "["$idx"]" "(trojan_ws) $remark" >> $nodes
        elif [ "$protocol" = "trojan" ] && [ "$type" = "grpc" ]; then
            info "Find protocol: trojan_grpc"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_trojan_grpc.json ${OUTPUT_CONFIGS_DIR}/${idx}_trojan_grpc.json
            echo "["$idx"]" "(trojan_grpc) $remark" >> $nodes
        elif [ "$protocol" = "trojan" ] && ( [ "$type" = "null" ] || [ "$type" = "tcp" ] ); then
            info "Find protocol: trojan_tcp"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_trojan_tcp.json ${OUTPUT_CONFIGS_DIR}/${idx}_trojan_tcp.json
            echo "["$idx"]" "(trojan_tcp) $remark" >> $nodes
        elif [ "$protocol" = "ss" ]; then
            info "Find protocol: ss"
            generate_config "$json_info" ${TEMLATES_DIR}/tmp_win_ss.json ${OUTPUT_CONFIGS_DIR}/${idx}_ss.json
            echo "["$idx"]" "(ss) $remark" >> $nodes
        else
            hint "unknown protocol." protocol=$protocol, net=$net, type=$type.
            continue
        fi
        ((counter++))
    done <<< "$decoded_sub_latest"

}

start_with_new_config() {
    #如果config.json为普通文件类型，且非软连接类型，则重命名为config.json.bak+日期   
    local configjson=$xray_config_path
    if [ -e "$configjson" ] && ! [ -L "$configjson" ]; then
        local newname=$configjson.bak.$(date +%Y%m%d%H%M%S)
        echo "Original config.json exists, renamed to $newname"
        mv $configjson $newname
    fi
    
    # 在configs文件夹下随机取一个文件，在当前目录创建一个软链接config.json指向该文件 
    local config_files=($OUTPUT_CONFIGS_DIR/*)
    local random_index=$((RANDOM % ${#config_files[@]}))
    local random_file=${config_files[$random_index]}
    echo $random_file, $configjson
    ln -sf $random_file $configjson
    info "Starting xray with config: $random_file"

    ${SYSTEMCTL_RESTART_XRAY[SYS_IDX]}
    sleep 2
    local status=$(${SYSTEMCTL_ISACTIVE_XRAY[SYS_IDX]}) 
    [[ "$status" == "active" ]] && info "Xray started successfully." || error "Xray start failed."
    echo 
    nodes_list
    testing_network
    echo 
    show_proxy_info
}

testing_network() {
    local port=$(cat $xray_config_path | jq -r '.inbounds[] | select(.tag == "http").port')
    echo "network testing with proxy: http://127.0.0.1:$port"
    curl -4 --retry 2 -ksm5 --proxy http://127.0.0.1:$port https://www.google.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "network test success \u2705"
        return 0
    else
        error "network test failed \u274C"
    fi
}

show_proxy_info() {
    local porthttp=$(cat $xray_config_path | jq -r '.inbounds[] | select(.tag == "http").port')
    local portsocks=$(cat $xray_config_path | jq -r '.inbounds[] | select(.tag == "socks").port')
    info "Proxy Info:"
    echo "http/https proxy server: http://127.0.0.1:${porthttp}"
    echo "socks proxy server: socks5://127.0.0.1:${portsocks}"
    echo "e.g."
    echo "1) set in bash profile: export http_proxy=http://127.0.0.1:${porthttp};export https_proxy=http://127.0.0.1:${porthttp};export ALL_PROXY=socks5://127.0.0.1:${portsocks}"
    echo "2) set in curl command: curl --proxy http://127.0.0.1:${porthttp} https://www.google.com"
}

generate_config() {
    json_config=$1
    template_file=$2
    output_file=$3
    # echo template_file=$template_file, output_file=$output_file

    template=$(cat $template_file)
    # 遍历json_config中的所有字段，将template中的字段名替换为对应的值，其中字段名的规则是 ${字段名}。
    while IFS= read -r line; do
        key=$(echo $line | cut -d '=' -f 1)
        value=$(echo $line | cut -d '=' -f 2)
        template=${template//\$\{$key\}/$value}
    done <<< "$(echo $json_config | jq -r 'to_entries | map("\(.key)=\(.value)") | join("\n")')"
    echo "$template" > $output_file
}

transform_to_json() {
    local link=$(echo "$1" | tr -d '\n\r')
    # link="trojan://CMLiu@218.158.87.155:11423?security=tls&sni=aliorg.filegear-sg.me&type=ws&host=aliorg.filegear-sg.me&path=%2F#%E9%9F%A9%E5%9B%BD%E3%80%90%E4%BB%98%E8%B4%B9%E6%8E%A8%E8%8D%90%EF%BC%9Ahttps%3A%2F%2Fa0a.xyz%E3%80%9176"
    local protocol=$(echo "$link" | cut -d: -f1)
    # decode URL
    local flink=$(echo -e "$(echo "$link" | sed 's/%/\\x/g')")
    link=$(echo "$flink")
    local json_defalut="{}"
    [[ "$protocol" = "trojan" ]] && json_defalut='{"alpn":"http/1.1"}'
    # echo B, "$flink"
    # 1、link本身经过base64加密，协议后面的内容完全经过base64编码。如：vmess://eyJwb3J0Ijo4NCwicHMiOiI1YzQ3NTBkOC1WTWVzc19XUyIsInRscyI6InRscyIsImlkIjoiNWM0NzUwZDgtMzEiLCJhaWQiOjAsInYiOjIsImhvc3QiOiJhdTIubmV0Mi54eXoiLCJ0eXBlIjoibm9uZSIsInBhdGgiOiIva3lrenZ3cyIsIm5ldCI6IndzIiwiYWRkIjoiYXUyLm5ldDIueHl6IiwiYWxsb3dJbnNlY3VyZSI6MCwibWV0aG9kIjoibm9uZSIsInBlZXIiOiJhdTIubmV0Mi54eXoiLCJzbmkiOiJhdTIubmV0Mi54eXoifQ==
    # 如果link不包含？,同时不包含@，则截取协议后面的内容 
    if [[ $link != *"?"* ]] && [[ $link != *"@"* ]]; then
        local link_part=$(echo "$link" | sed 's/^.*\/\///;s/#.*//')
        # echo link_part $link_part
        json_content=$(echo "$link_part" | base64 -di 2>/dev/null)
        [ $? -eq 0 ] || error "Invalid base64 encoded content: $link_part"
       
        if ! echo "$json_content" | jq . &> /dev/null; then
            error "Invalid JSON content: $json_content"
        fi
       
        local remark=$(echo "$json_content" | jq -r '.ps')
        local basic_info_json="{\"remark\":\"$remark\",\"protocol\":\"$protocol\"}"
        local final_json=$(jq -n --argjson json1 "$json_defalut" --argjson json2 "$basic_info_json" --argjson json3 "$json_content" \
                  '$json1 + $json2 + $json3')
        echo $final_json
        return 0
    fi
    
    # 2、link为明文时
    # 提取protocol， id, server, 和 port.  (protocol://id@server:port)
    # link="ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTo4M2NlZjNmMC1kN2NkLTRiMDgtYTgwNS1kMmEyNGI4ODEyYWE=@usa1.iepl.cooc.icu:31881#节点104"
    local id=$(echo "$link" | sed -n 's|.*://\([^@]*\)@.*|\1|p')
    local server=$(echo "$link" | sed -n 's|.*@\([^:]*\):.*|\1|p')
    local port=$(echo "$link" | sed -n 's|.*:\([0-9]*\)[?#].*|\1|p')
    local remark=$(echo "$link" | sed -n 's|.*#\(.*\)|\1|p')
    # echo R. id:$id, server:$server, port:$port, remark:"$remark"
    
    local id_decoded=$(echo "$id" | base64 -di 2>/dev/null)
    # 如果命令执行成功，且id_decoded包含":"，则执行以下操作
    if [ $? -eq 0 ] && [[ $id_decoded =~ ":" ]] && [[ $protocol = "ss" ]];then 
        remark=$(echo "$remark" | tr -d '\n\r')
        local method=$(echo "$id_decoded" | cut -d ":" -f 1)
        local password=$(echo "$id_decoded" | cut -d ":" -f 2)
        local basic_info_json="{\"remark\":\""$remark"\",\"protocol\":\"$protocol\",\"method\":\"$method\",\"password\":\"$password\",\"server\":\"$server\",\"port\":$port}"
        # echo R1 $basic_info_json
    elif [[ $id =~ ":" ]] && [[ $protocol = "ss" ]]; then
        local method=$(echo "$id" | cut -d ":" -f 1)
        local password=$(echo "$id" | cut -d ":" -f 2)
        local basic_info_json="{\"remark\":\""$remark"\",\"protocol\":\"$protocol\",\"method\":\"$method\",\"password\":\"$password\",\"server\":\"$server\",\"port\":$port}"
    else
        local basic_info_json="{\"remark\":\""$remark"\",\"protocol\":\"$protocol\",\"id\":\"$id\",\"server\":\"$server\",\"port\":$port}"
    fi
    
    # 提取查询参数部分
    local query_params=$(echo "$link" | sed -E 's/^[^?]*//;s/#.*//' | sed 's/^\?//')
    # echo "Q2: $query_params"

    local query_params_json="{"
    IFS='&'
    read -ra PAIRS <<< "$query_params" # 将参数字符串读入数组
    for pair in "${PAIRS[@]}"; do
        IFS='=' read -r key value <<< "$pair" # 再次设置内部字段分隔符为 = 并读取键值对
        query_params_json+="\"$key\":\"$value\","
    done

    # 删除最后一个逗号
    query_params_json="${query_params_json%,}"
    query_params_json+="}"
    
    # echo "Q" "$basic_info_json", "$query_params_json"
    # 合并JSON对象,后者的字段会覆盖前者
    local final_json=$(jq -n --argjson json1 "$json_defalut" --argjson json2 "$basic_info_json" --argjson json3 "$query_params_json" \
                  '$json1 + $json2 + $json3')

    echo "$final_json"
    return 0
}

install() {
    info "Installing..."    
    [ ! $(type -p jq) ] && info "install jq" && ${PACKAGE_INSTALL[SYS_IDX]} jq 
    if [ ! $(type -p jq) ]; then
        [ "$SYSTEM" = "CentOS" ] && info "install epel-release" && ( ${PACKAGE_INSTALL[SYS_IDX]} epel-release || error "epel-release install failed" )
        ${PACKAGE_INSTALL[SYS_IDX]} jq || error "jq install failed"
    fi

    [ ! $(type -p wget) ] && info "install wget" && ( ${PACKAGE_INSTALL[SYS_IDX]} wget || error "wget install failed" )
    [ ! $(type -p curl) ] && info "install curl" && ( ${PACKAGE_INSTALL[SYS_IDX]} curl || error "curl install failed" )
    
    info "Downloading config templates..."
    rm -fr $TEMLATES_DIR/*
    wget -qO $TEMLATES_DIR/tmp_win_trojan_grpc.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_trojan_grpc.json'
    wget -qO $TEMLATES_DIR/tmp_win_trojan_tcp.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_trojan_tcp.json'
    wget -qO $TEMLATES_DIR/tmp_win_trojan_ws.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_trojan_ws.json'
    wget -qO $TEMLATES_DIR/tmp_win_vless_tcp.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_vless_tcp.json'
    wget -qO $TEMLATES_DIR/tmp_win_vless_ws.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_vless_ws.json'
    wget -qO $TEMLATES_DIR/tmp_win_vmess_ws.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_vmess_ws.json'
    wget -qO $TEMLATES_DIR/tmp_win_vmess_tcp.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_vmess_tcp.json'
    wget -qO $TEMLATES_DIR/tmp_win_ss.json ${GH_PROXY}'https://raw.githubusercontent.com/MinionTim/xray-configer/main/templates/tmp_win_ss.json'

    if [ $(find "$TEMLATES_DIR" -maxdepth 1 -name "*.json" | wc -l) -eq 0 ]; then
        error "Download templates failed."
    fi
    echo Downloaded templates: 
    find "$TEMLATES_DIR" -maxdepth 1 -name "*.json" | xargs -n1 printf "%s\n"

    info "Add cron job"
    local interval_min=10
    cron_command="*/$interval_min * * * * /bin/bash -l -c 'env PATH=$PATH ${HOME_DIR}/$(basename $0) r' >> ${HOME_DIR}/logs/cron.log 2>&1"
    existing_cron_jobs=$(crontab -l 2>/dev/null)
    if ! echo "$existing_cron_jobs" | grep -qF "$cron_command"; then
        (crontab -l 2>/dev/null; echo "$cron_command") | crontab -
    fi

    mv "$0" $HOME_DIR/xray-configer.sh
    chmod +x $HOME_DIR/xray-configer.sh
    ln -sf $HOME_DIR/xray-configer.sh /usr/bin/xray-configer
    
    echo "The script has been installed in: $HOME_DIR"
    echo "Config templates in: $TEMLATES_DIR"
    echo "Config files in: $OUTPUT_CONFIGS_DIR"
    echo "Cron job in: crontab, checking subscribe every $interval_min minutes"
    echo "Shortcut in: /usr/bin/xray-configer"
    info "Installed successfully, the script will automatically run every $interval_min minutes to ensure that the configuration file is always up to date.\nAlso, you can type 'xray-configer' to see more features. Source file [$0] has been deleted"
}

nodes_list() {
    info "Node list:"
    echo -e "   from \"$XRAY_SUB_URL\"\n------------------------------"
    local index=$(basename `readlink -f $xray_config_path` | cut -d '_' -f 1)
    while read line; do
        if [[ "$(echo "$line" | sed -n 's|^\[\([0-9]*\)\].*|\1|p')" = "$index" ]]; then
            warning "*"$line
        else
            echo $line
        fi
    done < $HOME_DIR/nodes.txt 
    echo "------------------------------"
}

change_node() {
    nodes_list
    reading "Please input the node index you want to change to:(e.g. 01) " node_index
    # 如果找到了以[$node_index]开头的行，则打印该行的内容，否则提示输入错误
    
    if grep -q "^\[$node_index\]" $HOME_DIR/nodes.txt; then
        local line=$(grep "^\[$node_index\]" $HOME_DIR/nodes.txt)
        # 在OUTPUT_CONFIGS_DIR目录下，找到文件名以$node_index_开头的文件，并打印该文件名
        local config_file=$(ls $OUTPUT_CONFIGS_DIR | grep "^${node_index}_")
        echo -n "choose node: "; warning "$line"
        ln -sf "$OUTPUT_CONFIGS_DIR/$config_file" "$xray_config_path"
        echo "Restarting xray with config: $OUTPUT_CONFIGS_DIR/$config_file"
        ${SYSTEMCTL_RESTART_XRAY[SYS_IDX]}
        sleep 2
        local status=$(${SYSTEMCTL_ISACTIVE_XRAY[SYS_IDX]}) 
        [[ "$status" == "active" ]] && info "Xray restarted successfully." || error "Xray restart failed."
        testing_network
    else
        error "Input error, please try again."
    fi
}

# 多方式判断操作系统，试到有值为止。只支持 Debian 9/10/11、Ubuntu 18.04/20.04/22.04 或 CentOS 7/8 ,如非上述操作系统，退出脚本
check_operating_system() {
    unset SYS SYSTEM SYS_IDX
    if [ -s /etc/os-release ]; then
        SYS="$(grep -i pretty_name /etc/os-release | cut -d \" -f2)"
    elif [ $(type -p hostnamectl) ]; then
        SYS="$(hostnamectl | grep -i system | cut -d : -f2)"
    elif [ $(type -p lsb_release) ]; then
        SYS="$(lsb_release -sd)"
    elif [ -s /etc/lsb-release ]; then
        SYS="$(grep -i description /etc/lsb-release | cut -d \" -f2)"
    elif [ -s /etc/redhat-release ]; then
        SYS="$(grep . /etc/redhat-release)"
    elif [ -s /etc/issue ]; then
        SYS="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"
    elif [ $(type -p uname) ]; then
        SYS="$(uname -s)"
    fi
    
    REGEX=("debian" "ubuntu" "centos|red hat|kernel|alma|rocky|amazon linux" "alpine" "arch linux" "openwrt" "darwin")
    RELEASE=("Debian" "Ubuntu" "CentOS" "Alpine" "Arch" "OpenWrt" "MacOS")
    EXCLUDE=("---")
    MAJOR=("9" "16" "7" "" "" "" "4")
    PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "apk update -f" "pacman -Sy" "opkg update" "brew update")
    PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "apk add -f" "pacman -S --noconfirm" "opkg install" "brew install")
    PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "apk del -f" "pacman -Rcnsu --noconfirm" "opkg remove --force-depends" "brew uninstall")
    SYSTEMCTL_START_XRAY=("systemctl start xray" "systemctl start xray" "systemctl start xray" "" "" "")
    SYSTEMCTL_STOP_XRAY=("systemctl stop xray" "systemctl stop xray" "systemctl stop xray" "kill -15 $(pgrep xray)" "systemctl stop xray" "kill -15 $(pgrep xray)")
    SYSTEMCTL_RESTART_XRAY=("systemctl restart xray" "systemctl restart xray" "systemctl restart xray" "" "" "")
    SYSTEMCTL_ISACTIVE_XRAY=("systemctl is-active xray" "systemctl is-active xray" "systemctl is-active xray" "" "" "")
    
    local int
    for int in "${!REGEX[@]}"; do
        local syslower=$(echo "$SYS" | tr '[:upper:]' '[:lower:]')
        [[ "${syslower}" =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
    done

    # 针对各云厂运的订制系统
    if [ -z "$SYSTEM" ]; then
        [ $(type -p yum) ] && int=2 && SYSTEM='CentOS' || error "本脚本只支持 Debian、Ubuntu、CentOS、MacOS、Arch 或 Alpine 系统。"
    fi
    SYS_IDX=$int
    # echo "System Info：$SYS -- $SYSTEM, $SYS_IDX"
}

check_root() {
  [ "$(id -u)" != 0 ] && error "You must run the script as root. You can type \"sudo su\" and then download and run it again."
}

uninstall() {
    rm -fr $HOME_DIR
    echo "Install derectory removed."
    rm -fr /usr/bin/xray-configer
    echo "shortcut removed."
    crontab -l | grep -v "${HOME_DIR}/$(basename $0)" | crontab -
    echo "cron job removed."
    unset XRAY_SUB_URL XRAY_CONFIG_PATH
    info "The script is removed successfully. Environment variables (XRAY_SUB_URL or XRAY_CONFIG_PATH) NOT removed, need to manually remove them."
}

usage() {
    echo "A assistive tool for xray. It can generate config files from subscribe link, and keep the newest configrations automaticlly."
    echo ""
    echo "usage:"
    echo "  bash $0 [option]"
    echo "options:"
    echo "  h | help: print help info."
    echo "  r | update_restart: fetch xrayconfig and restart xray."
    echo "  f | fetch: fetch config only."
    echo "  t | test: test network with proxy."
    echo "  n | nodes: show node list from subscribe."
    echo "  i | install: install the script."
    echo "  u | uninstall: uninstall the script."
}


main() {
    check_root
    OPTION=$(tr 'A-Z' 'a-z' <<< "$1")
    hint "[$(date '+%Y-%m-%d %H:%M:%S')] run script: $0 $OPTION"
    case "$OPTION" in
        h | help | "") usage; exit 0;;
        r | update_restart ) ensure_env && update_configs_and_restart; exit 0;;
        f | fetch ) ensure_env && fetch_configs; exit 0;;
        t | test ) ensure_env && testing_network; exit 0;;
        n | nodes ) ensure_env && nodes_list; exit 0;;
        c | change_node ) ensure_env && change_node; exit 0;;
        i | install ) ensure_env && install; exit 0;;
        u | uninstall ) uninstall; exit 0;;
        * ) echo "unknown options \"$OPTION\", please refer to the belowing..."; usage; exit 0;;
    esac
}

main "$@"
# transform_to_json "vless://cefffd1d-cc58-4560-b4d1-44f1af528f30@151.101.131.1:80?encryption=none&security=none&type=ws&host=fraud.chase&path=%2F%3Fed%3D2048#US%F0%9F%87%BA%F0%9F%87%B8"
