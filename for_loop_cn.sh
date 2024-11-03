#!/bin/bash

# 检查参数数量
if [ "$#" -ne 3 ]; then
    echo "用法: $0 <输入文件> <输出文件> <超时时间>"
    exit 1
fi

# 获取输入和输出文件名以及超时时间
input_file="$1"
output_file="$2"
timeout="$3"

# 写入初始部分到输出文件
cat <<EOL > $output_file
/log info "Loading CN ipv4 address list"
/ip firewall address-list remove [/ip firewall address-list find list=CN]
/ip firewall address-list
:local ipList {
EOL

# 读取输入文件，提取 IP 地址和子网，写入到 ipList 中
grep -oP 'address=\K[0-9./]+' $input_file | while read -r line; do
    echo "    \"$line\";" >> $output_file
done

# 写入循环部分到输出文件
cat <<EOL >> $output_file
}
:foreach ip in=\$ipList do={
    /ip firewall address-list add address=\$ip list=CN timeout=$timeout
}
EOL

echo "转换完成！生成的文件是 $output_file"
