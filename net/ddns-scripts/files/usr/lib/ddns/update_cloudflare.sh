#!/bin/bash
# cloudflare账号信息
auth_email="$username"
auth_key="$password" # found in cloudflare account settings
zone_name="$domain"
record_name="$lookup_host"
# 可配置参数
ip=$(curl -s http://ipv4.icanhazip.com)
ip_file="ip.txt"
log_file="cloudflare.log"
# 日志记录
log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $log_file
    fi
}
# 开始脚本
log "Check Initiated"

#获取根域名zone_id
zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
-H "X-Auth-Email: $auth_email" \
-H "X-Auth-Key: $auth_key" \
-H "Content-Type: application/json" \
| grep -Po '(?<="id":")[^"]*' | head -1 )

#获取子域名record_id
record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" \
-H "X-Auth-Email: $auth_email" \
-H "X-Auth-Key: $auth_key" \
-H "Content-Type: application/json" \
| grep -Po '(?<="id":")[^"]*')

#如果获取子域名信息为空，创建子域名，并获取子域名record_id
if [[ $record_identifier = "" ]]; then
    #创建子域名
    create=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records" \
    -H "X-Auth-Email: $auth_email" \
    -H "X-Auth-Key: $auth_key" \
    -H "Content-Type: application/json" \
    --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"proxied\":false}")
    #获取子域名record_id
    record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" \
    -H "X-Auth-Email: $auth_email" \
    -H "X-Auth-Key: $auth_key" \
    -H "Content-Type: application/json" \
    | grep -Po '(?<="id":")[^"]*')
fi

#获取子域名ip
cf_ip=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
-H "X-Auth-Email: $auth_email" \
-H "X-Auth-Key: $auth_key" \
-H "Content-Type: application/json" \
|grep -Po '(?<="content":")[^"]*')

#如果子域名ip变化，更改域名记录
if [[ $ip == $cf_ip ]]; then
    echo "IP has not changed."
    exit 0
    else
    update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
    -H "X-Auth-Email: $auth_email" \
    -H "X-Auth-Key: $auth_key" \
    -H "Content-Type: application/json" \
    --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"proxied\":false}")
fi

#记录日志
if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    log "$message"
    echo -e "$message"
    exit 1
else
    message="IP changed to: $ip"
    echo "$ip" > $ip_file
    log "$message"
    echo "$message"
fi
