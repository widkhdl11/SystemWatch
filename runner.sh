#!/bin/bash


# 설정 값들
MONITOR_INTERVAL=60  # 60초마다 체크
REPORT_DIR="reports"
HISTORY_DIR="reports/history"
LOG_DIR="logs"


HTML_REPORT="$REPORT_DIR/system_status.html"
HISTORY_CSV="$HISTORY_DIR/history.csv"
EMAIL_LOG="$LOG_DIR/email_log.txt"
FAILED_EMAIL_LOG="$LOG_DIR/failed_email_log.txt"

CSV_HEADER="날짜 CPU사용량 Memory사용량 DISK사용량"

if [ ! -d $LOG_DIR ]; then
    mkdir -p $LOG_DIR
fi

if [ ! -d $REPORT_DIR ]; then
    mkdir -p $REPORT_DIR
fi
if [ ! -d $HISTORY_DIR ]; then
    mkdir -p $HISTORY_DIR
fi

if [ ! -f $HTML_REPORT ]; then
    touch $HTML_REPORT
fi

if [ ! -f $EMAIL_LOG ]; then
    touch $EMAIL_LOG
fi

if [ ! -f $FAILED_EMAIL_LOG ]; then
    touch $FAILED_EMAIL_LOG
fi

if [ ! -f $HISTORY_CSV ]; then
    touch $HISTORY_CSV
    echo "$CSV_HEADER" >> $HISTORY_CSV
elif [ $(wc -l < "$HISTORY_CSV") -lt 1 ]
then 
    echo "$CSV_HEADER" >> $HISTORY_CSV
fi

# 임계값 설정
declare -A WARN CRIT
WARN["cpu"]=70
CRIT["cpu"]=85
WARN["mem"]=75
CRIT["mem"]=90
WARN["disk"]=80
CRIT["disk"]=95

# cpu 정보 수집 함수
collect_cpu_usage() {
    cpu_usage=$(top -bn1 | grep '%Cpu(s)' | awk -F'[,: ]+' '{printf "%.1f\n", ( $2+ $4 )}' )
    get_status_level cpu $cpu_usage
}

# 메모리 사용률 수집 함수
collect_memory_usage() {
    memory_usage=$(free | grep "Mem:" | awk '{printf "%.2f\n", ($3*100 /$2) }')
    get_status_level mem $memory_usage
}

# 디스크 사용류 수집 함수수
collect_disk_usage() {
    disk_usage=$( df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    get_status_level disk $disk_usage
}

# 임계값에 대한 상태값 설정 함수수
get_status_level() {
    system_name=$1
    usage_value=$2
    if (awk -v v="$usage_value" -v c="${CRIT[$system_name]}" 'BEGIN{exit !(v>=c)}'; )
    then
        echo "CRITICAL ☠️"  
        send_smtp_email "$system_name - CRITICAL 임계값 초과 [ $usage_value/${CRIT[$system_name]} ]"
    elif (awk -v v="$usage_value" -v w="${WARN[$system_name]}" 'BEGIN{exit !(v>=w)}'); 
    then 
        echo "WARNING ⚠️"
        send_smtp_email "$system_name - WARNING 임계값 초과 [ $usage_value/${WARN[$system_name]} ]"
    else 
        echo "GOOD ✅"
    fi

        
}

# CPU 사용량 높은 프로세스 TOP 5
get_top_cpu_processes() {
    echo "$(ps aux --sort=-%cpu | tail -n +2 | head -n 5 | awk '{printf "%s (PID : %d) 사용량 : %.1f% \n", $11, $2, $3 }')"
}

# 메모리 사용량 높은 프로세스 TOP 5  
get_top_memory_processes() {
    echo "$(ps aux --sort=-%mem | tail -n +2 | head -n 5 | awk '{printf "%s (PID : %d) 사용량 : %.1f% \n", $11, $2, $4 }')"
}

# 좀비 프로세스 개수 확인
check_zombie_processes() {
    top -bn1 | awk 'NR>7 {if ( $8 == "Z" )print $8}' | wc -l
}

# ssmtp
send_smtp_email() {
    local subject="$1"
    local message="$2"
    local to_email="${3:-wjdrudgml17@gmail.com}"
    local temp_file="/tmp/systemwatch_email_$$"
    
    cat > "$temp_file" << EOF
To: $to_email
From: SystemWatch <wjdrudgml17@gmail.com>
Subject: $subject
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

=== SystemWatch 자동 알림 ===

$message

---
발송 시간: $(date '+%Y-%m-%d %H:%M:%S')
시스템: $(hostname)
발송자: SystemWatch 모니터링 시스템

이 메일은 자동으로 발송되었습니다.
EOF

    # 메일 발송 시도
    if ssmtp "$to_email" < "$temp_file" 2>/dev/null; then
        echo "📧 SMTP 이메일 발송 성공: $to_email"
        echo "$(date): EMAIL SENT to $to_email - $subject" >> $EMAIL_LOG
        rm -f "$temp_file"
        return 0
    else
        echo "❌ SMTP 이메일 발송 실패"
        echo "$(date): EMAIL FAILED to $to_email - $subject" >> $EMAIL_LOG
        
        # 백업 로그로 저장
        echo "=== 발송 실패한 이메일 ===" >> $FAILED_EMAIL_LOG
        cat "$temp_file" >> $FAILED_EMAIL_LOG
        echo "========================" >> $FAILED_EMAIL_LOG
        
        rm -f "$temp_file"
        return 1
    fi
}

# 이메일 테스트 함수
test_email_system() {
    echo "=== SystemWatch 이메일 시스템 테스트 ==="
    
    # 기본 테스트
    echo "📧 테스트 메일 발송 중..."
    send_smtp_email "SystemWatch 테스트" "이메일 시스템이 정상 작동합니다."
    
    sleep 2
    
    # 경고 메일 테스트  
    echo "⚠️ 경고 메일 발송 중..."
    send_smtp_email "[WARNING] SystemWatch 경고" "CPU 사용률이 임계값을 초과했습니다."
    
    sleep 2
    
    # 위험 메일 테스트
    echo "🚨 위험 메일 발송 중..." 
    send_smtp_email "[CRITICAL] SystemWatch 위험" "시스템이 위험 상태입니다. 즉시 확인이 필요합니다."
    
    echo "✅ 이메일 테스트 완료 - Gmail 받은편지함을 확인하세요!"
}

save_history() {
    TS=$(date +"%Y%m%d_%H:%M:%S")
    echo "$TS $cpu_usage $memory_usage $disk_usage" >> $HISTORY_CSV
}




# HTML 리포트 생성 함수
generate_html_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > $HTML_REPORT << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SystemWatch - 시스템 모니터링</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .good { color: green; }
        .warning { color: orange; }
        .critical { color: red; }
        .status-box { 
            border: 1px solid #ccc; 
            padding: 10px; 
            margin: 10px 0; 
            border-radius: 5px; 
        }
    </style>
</head>
<body>
    <h1>🖥️ SystemWatch 모니터링</h1>
    <p><strong>마지막 업데이트:</strong> $timestamp</p>
    
    <div class="status-box">
        <h3>💻 CPU 사용률: ${cpu_usage}% - $(get_status_level cpu $cpu_usage)</h3>
    </div>
    
    <div class="status-box">
        <h3>🧠 메모리 사용률: ${memory_usage}% - $(get_status_level mem $memory_usage)</h3>
    </div>
    
    <div class="status-box">
        <h3>💾 디스크 사용률: ${disk_usage}% - $(get_status_level disk $disk_usage)</h3>
    </div>

    <div class="status-box">
        <h3> CPU 사용률 TOP5 프로세스 
        <h4>$(get_top_cpu_processes)</h4>
    </div>

    <div class="status-box">
        <h3> 메모리 사용률 TOP5 프로세스 
        <h4>$(get_top_memory_processes)</h4>
    </div>
    
    <div class="status-box">
        <h3> 좀비 프로세스 
        <h4>$(check_zombie_processes)</h4>
    </div>


</body>
</html>
EOF
}



main_monitoring_loop() {
    # 지정된 간격으로 반복 실행
    while true; do
        collect_cpu_usage
        collect_memory_usage
        collect_disk_usage

        get_top_cpu_processes
        get_top_memory_processes
        check_zombie_processes

        save_history
        generate_html_report

        sleep $MONITOR_INTERVAL
    done
}

main_monitoring_loop
