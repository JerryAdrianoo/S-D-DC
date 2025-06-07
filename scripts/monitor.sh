#!/bin/bash

# Sistema de Monitoramento de Incident Management
# Este script monitora a saúde dos serviços e detecta incidentes

# Configurações
LOG_DIR="./logs"
INCIDENT_LOG="$LOG_DIR/incidents.log"
STATUS_LOG="$LOG_DIR/status.log"
ALERT_THRESHOLD=3  # Número de falhas consecutivas para alerta
MONITOR_INTERVAL=30  # Intervalo em segundos

# URLs dos serviços para monitoramento
WEB_URL="http://localhost:8080"
API_URL="http://localhost:3000/health"
DB_CHECK_URL="http://localhost:3000/db-health"

# Contadores de falhas
WEB_FAIL_COUNT=0
API_FAIL_COUNT=0
DB_FAIL_COUNT=0

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para criar logs se não existirem
init_logs() {
    mkdir -p "$LOG_DIR"
    touch "$INCIDENT_LOG"
    touch "$STATUS_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Monitor iniciado" >> "$STATUS_LOG"
}

# Função para log de incidentes
log_incident() {
    local service="$1"
    local severity="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] INCIDENT - Service: $service | Severity: $severity | Message: $message" >> "$INCIDENT_LOG"
    echo -e "${RED}🚨 INCIDENT DETECTED${NC}"
    echo -e "${RED}Service: $service${NC}"
    echo -e "${RED}Severity: $severity${NC}"
    echo -e "${RED}Message: $message${NC}"
    echo -e "${RED}Time: $timestamp${NC}"
    echo "----------------------------------------"
}

# Função para log de status
log_status() {
    local service="$1"
    local status="$2"
    local response_time="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] STATUS - Service: $service | Status: $status | Response: ${response_time}ms" >> "$STATUS_LOG"
}

# Função para verificar saúde do serviço web
check_web_service() {
    echo -e "${BLUE}Checking Web Service...${NC}"
    
    start_time=$(date +%s%3N)
    if curl -f -s "$WEB_URL" > /dev/null; then
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
        
        echo -e "${GREEN} Web Service: OK (${response_time}ms)${NC}"
        log_status "web" "UP" "$response_time"
        WEB_FAIL_COUNT=0
        return 0
    else
        echo -e "${RED} Web Service: DOWN${NC}"
        WEB_FAIL_COUNT=$((WEB_FAIL_COUNT + 1))
        log_status "web" "DOWN" "timeout"
        
        if [ $WEB_FAIL_COUNT -ge $ALERT_THRESHOLD ]; then
            log_incident "web" "HIGH" "Web service down for $WEB_FAIL_COUNT consecutive checks"
            attempt_service_restart "web"
        fi
        return 1
    fi
}

# Função para verificar API
check_api_service() {
    echo -e "${BLUE}Checking API Service...${NC}"
    
    start_time=$(date +%s%3N)
    if curl -f -s "$API_URL" > /dev/null; then
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
        
        echo -e "${GREEN} API Service: OK (${response_time}ms)${NC}"
        log_status "api" "UP" "$response_time"
        API_FAIL_COUNT=0
        return 0
    else
        echo -e "${RED} API Service: DOWN${NC}"
        API_FAIL_COUNT=$((API_FAIL_COUNT + 1))
        log_status "api" "DOWN" "timeout"
        
        if [ $API_FAIL_COUNT -ge $ALERT_THRESHOLD ]; then
            log_incident "api" "HIGH" "API service down for $API_FAIL_COUNT consecutive checks"
            attempt_service_restart "api"
        fi
        return 1
    fi
}

# Função para verificar conectividade com banco
check_database_service() {
    echo -e "${BLUE}Checking Database Service...${NC}"
    
    start_time=$(date +%s%3N)
    if curl -f -s "$DB_CHECK_URL" > /dev/null; then
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
        
        echo -e "${GREEN} Database Service: OK (${response_time}ms)${NC}"
        log_status "database" "UP" "$response_time"
        DB_FAIL_COUNT=0
        return 0
    else
        echo -e "${RED} Database Service: DOWN${NC}"
        DB_FAIL_COUNT=$((DB_FAIL_COUNT + 1))
        log_status "database" "DOWN" "timeout"
        
        if [ $DB_FAIL_COUNT -ge $ALERT_THRESHOLD ]; then
            log_incident "database" "CRITICAL" "Database connectivity failed for $DB_FAIL_COUNT consecutive checks"
            attempt_service_restart "database"
        fi
        return 1
    fi
}

# Função para tentar reiniciar serviços
attempt_service_restart() {
    local service="$1"
    echo -e "${YELLOW} Attempting to restart service: $service${NC}"
    
    if docker-compose restart "$service" 2>/dev/null; then
        echo -e "${GREEN} Service $service restarted successfully${NC}"
        log_incident "$service" "INFO" "Service automatically restarted due to consecutive failures"
    else
        echo -e "${RED} Failed to restart service: $service${NC}"
        log_incident "$service" "CRITICAL" "Automatic restart failed - manual intervention required"
    fi
}

# Função para verificar uso de recursos
check_system_resources() {
    echo -e "${BLUE}Checking System Resources...${NC}"
    
    # Verificar uso de CPU (média dos últimos 5 minutos)
    cpu_usage=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $2}' | sed 's/,//')
    
    # Verificar uso de memória
    memory_usage=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
    
    # Verificar espaço em disco
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    echo -e "${GREEN} CPU Load: $cpu_usage${NC}"
    echo -e "${GREEN} Memory Usage: $memory_usage%${NC}"
    echo -e "${GREEN} Disk Usage: $disk_usage%${NC}"
    
    # Alertas de recursos
    if (( $(echo "$memory_usage > 80" | bc -l) )); then
        log_incident "system" "MEDIUM" "High memory usage detected: $memory_usage%"
    fi
    
    if [ "$disk_usage" -gt 85 ]; then
        log_incident "system" "MEDIUM" "High disk usage detected: $disk_usage%"
    fi
}

# Função para mostrar resumo do status
show_status_summary() {
    echo -e "\n${BLUE}=== STATUS SUMMARY ===${NC}"
    echo -e "Web Service Failures: $WEB_FAIL_COUNT"
    echo -e "API Service Failures: $API_FAIL_COUNT"
    echo -e "Database Failures: $DB_FAIL_COUNT"
    echo -e "Last Check: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BLUE}========================${NC}\n"
}

# Função principal de monitoramento
monitor_services() {
    echo -e "${YELLOW}🚀 Starting Incident Management Monitor${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}\n"
    
    init_logs
    
    while true; do
        echo -e "${BLUE}=== HEALTH CHECK CYCLE ===${NC}"
        echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')\n"
        
        # Verificar todos os serviços
        check_web_service
        echo
        check_api_service
        echo
        check_database_service
        echo
        check_system_resources
        echo
        
        show_status_summary
        
        # Aguardar próximo ciclo
        echo -e "${YELLOW}⏳ Waiting ${MONITOR_INTERVAL} seconds for next check...${NC}\n"
        sleep $MONITOR_INTERVAL
    done
}

# Função para mostrar ajuda
show_help() {
    echo "Incident Management Monitor"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --monitor, -m    Start continuous monitoring (default)"
    echo "  --check, -c      Perform single health check"
    echo "  --logs, -l       Show recent incidents"
    echo "  --help, -h       Show this help message"
    echo ""
}

# Função para mostrar logs recentes
show_recent_logs() {
    echo -e "${BLUE}=== RECENT INCIDENTS ===${NC}"
    if [ -f "$INCIDENT_LOG" ]; then
        tail -20 "$INCIDENT_LOG"
    else
        echo "No incidents logged yet."
    fi
    echo -e "\n${BLUE}=== RECENT STATUS ===${NC}"
    if [ -f "$STATUS_LOG" ]; then
        tail -10 "$STATUS_LOG"
    else
        echo "No status logs yet."
    fi
}

# Tratamento de sinal para parada limpa
cleanup() {
    echo -e "\n${YELLOW}🛑 Monitor stopped by user${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Monitor stopped" >> "$STATUS_LOG"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Parse de argumentos da linha de comando
case "${1:-}" in
    --check|-c)
        init_logs
        check_web_service
        check_api_service
        check_database_service
        check_system_resources
        ;;
    --logs|-l)
        show_recent_logs
        ;;
    --help|-h)
        show_help
        ;;
    --monitor|-m|*)
        monitor_services
        ;;
esac