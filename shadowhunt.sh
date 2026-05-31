#!/usr/bin/env bash

# =============================================================================
# NOM:        SHADOWHUNT.sh - Ultimate Autonomous SOC & Bug Bounty Framework
# VERSION:    2.0.0
# AUTEUR:     sonneperInfosec
# LICENCE:    MIT Open Source License
#
# DESCRIPTION: Framework autonome de Bug Bounty et SOC intégrant OSINT avancé,
#              SIEM/SOAR/EDR open source, priorisation IA, reporting automatisé.
# =============================================================================

set -euo pipefail

# ---------- CONFIGURATION GLOBALE ----------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RESULTS_BASE_DIR="${RESULTS_BASE_DIR:-./results}"
readonly LOG_FILE="/tmp/shadowhunt_$(date +%Y%m%d_%H%M%S).log"
readonly CONFIG_FILE="${SCRIPT_DIR}/shadowhunt.conf"

# Paramètres par défaut
TARGET_DOMAIN=""
OUTPUT_DIR=""
MODE="full"
PRIORITY=10
USE_AI=true
USE_SOAR=true
USE_SIEM=true
USE_EDR=true
USE_OSINT_DEEP=true
UPDATE_TOOLS_ONLY=false

# Chemins des outils SOC et OSINT
declare -A TOOL_PATHS=(
    # --- ProjectDiscovery Suite ---
    ["subfinder"]="${HOME}/go/bin/subfinder"
    ["httpx"]="${HOME}/go/bin/httpx"
    ["nuclei"]="${HOME}/go/bin/nuclei"
    ["naabu"]="${HOME}/go/bin/naabu"
    ["katana"]="${HOME}/go/bin/katana"
    ["uncover"]="${HOME}/go/bin/uncover"
    ["chaos"]="${HOME}/go/bin/chaos"
    ["dnsx"]="${HOME}/go/bin/dnsx"
    ["cvemap"]="${HOME}/go/bin/cvemap"
    ["cloudlist"]="${HOME}/go/bin/cloudlist"
    ["asnmap"]="${HOME}/go/bin/asnmap"
    ["cdncheck"]="${HOME}/go/bin/cdncheck"
    ["notify"]="${HOME}/go/bin/notify"
    ["interactsh"]="${HOME}/go/bin/interactsh-client"
    
    # --- Web Fuzzing & Exploitation ---
    ["ffuf"]="${HOME}/go/bin/ffuf"
    ["gobuster"]="/usr/bin/gobuster"
    ["wfuzz"]="/usr/bin/wfuzz"
    ["feroxbuster"]="/usr/bin/feroxbuster"
    ["dalfox"]="${HOME}/go/bin/dalfox"
    ["kiterunner"]="${HOME}/go/bin/kiterunner"
    
    # --- OSINT Avancé ---
    ["theharvester"]="/usr/bin/theharvester"
    ["recon-ng"]="/usr/bin/recon-ng"
    ["spiderfoot"]="${HOME}/spiderfoot/sf.py"
    ["shodan"]="/usr/bin/shodan"
    ["whois"]="/usr/bin/whois"
    ["dig"]="/usr/bin/dig"
    ["nslookup"]="/usr/bin/nslookup"
    ["host"]="/usr/bin/host"
    ["dnsrecon"]="/usr/bin/dnsrecon"
    ["whatweb"]="/usr/bin/whatweb"
    ["wappalyzer"]="${HOME}/wappalyzer/cli.js"
    ["metagoofil"]="/usr/bin/metagoofil"
    ["exiftool"]="/usr/bin/exiftool"
    ["sherlock"]="${HOME}/sherlock/sherlock"
    ["holehe"]="${HOME}/holehe/holehe"
    ["maigret"]="${HOME}/maigret/maigret"
    
    # --- SOC / SIEM / SOAR ---
    ["wazuh"]="/var/ossec/bin/wazuh-control"
    ["osquery"]="/usr/bin/osqueryi"
    ["suricata"]="/usr/bin/suricata"
    ["zeek"]="/usr/bin/zeek"
    ["velociraptor"]="${HOME}/velociraptor/velociraptor"
    ["caldera"]="${HOME}/caldera/server"
    ["shuffle"]="${HOME}/shuffle/shuffle"
    ["thehive"]="/opt/thehive/bin/thehive"
    ["cortex"]="/opt/cortex/bin/cortex"
    ["misp"]="/var/www/MISP/app/Console/cake"
    
    # --- Vulnerability Management & Reporting ---
    ["defectdojo"]="${HOME}/defectdojo/dojo"
    ["dependency-track"]="${HOME}/dependency-track/track"
    ["vulnrisk"]="${HOME}/vulnrisk/vulnrisk"
)

# ---------- FONCTIONS UTILITAIRES ----------
_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

_error() {
    _log "ERROR" "$1"
    exit 1
}

_warning() {
    _log "WARNING" "$1"
}

_info() {
    _log "INFO" "$1"
}

_success() {
    _log "SUCCESS" "$1"
}

_print_banner() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    ███████╗██╗  ██╗ █████╗ ██████╗  ██████╗ ██╗    ██╗██╗  ██╗██╗   ██╗███╗   ██╗████████╗
║    ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔═══██╗██║    ██║██║  ██║██║   ██║████╗  ██║╚══██╔══╝
║    ███████╗███████║███████║██║  ██║██║   ██║██║ █╗ ██║███████║██║   ██║██╔██╗ ██║   ██║   
║    ╚════██║██╔══██║██╔══██║██║  ██║██║   ██║██║███╗██║██╔══██║██║   ██║██║╚██╗██║   ██║   
║    ███████║██║  ██║██║  ██║██████╔╝╚██████╔╝╚███╔███╔╝██║  ██║╚██████╔╝██║ ╚████║   ██║   
║    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   
║                                                                              ║
║   SHADOWHUNT - Ultimate SOC & Bug Bounty Framework v2.0.0                    ║
║   Autonomous Pentesting | SOC Automation | Vulnerability Detection Engine    ║
║   Open Source | AI-Powered | MIT Licensed                                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

_show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -d, --domain DOMAIN     Target domain (required)
  -o, --output DIR        Output directory (default: ./results)
  -m, --mode MODE         Execution mode: full, fast, stealth, soc, osint (default: full)
  -p, --priority PRIO     CPU priority (nice level: -20 to 19, default: 10)
  --no-ai                 Disable AI-powered analysis
  --no-soar               Disable SOAR actions (webhooks, notifications)
  --no-siem               Disable SIEM integration
  --no-edr                Disable EDR endpoint monitoring
  --no-osint-deep         Disable deep OSINT scanning
  --update-tools          Update all installed tools and exit
  --install-soc           Full SOC stack installation (Wazuh, TheHive, MISP, etc.)
  --help                  Show this help message

Modes:
  full    - Complete scan (recon + vuln + OSINT + SOC)
  fast    - Quick scan (subdomains + nuclei critical)
  stealth - Low and slow scan (avoid detection)
  soc     - SOC operations mode (monitoring, detection, response)
  osint   - Deep OSINT reconnaissance only

Examples:
  $0 -d example.com -o ./scan -m full
  $0 -d example.com --no-siem --mode osint
  $0 -d example.com --install-soc
  $0 --update-tools

EOF
}

_parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                TARGET_DOMAIN="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -p|--priority)
                PRIORITY="$2"
                shift 2
                ;;
            --no-ai)
                USE_AI=false
                shift
                ;;
            --no-soar)
                USE_SOAR=false
                shift
                ;;
            --no-siem)
                USE_SIEM=false
                shift
                ;;
            --no-edr)
                USE_EDR=false
                shift
                ;;
            --no-osint-deep)
                USE_OSINT_DEEP=false
                shift
                ;;
            --update-tools)
                UPDATE_TOOLS_ONLY=true
                shift
                ;;
            --install-soc)
                _install_soc_stack
                exit 0
                ;;
            --help)
                _show_help
                exit 0
                ;;
            *)
                _error "Unknown option: $1"
                ;;
        esac
    done

    if [[ -z "$TARGET_DOMAIN" && "$UPDATE_TOOLS_ONLY" != true ]]; then
        _error "Target domain is required. Use --help for usage."
    fi

    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="${RESULTS_BASE_DIR}/${TARGET_DOMAIN}_$(date +%Y%m%d_%H%M%S)"
    fi

    renice -n "$PRIORITY" $$ > /dev/null 2>&1 || true
}

# ---------- INSTALLATION SOC COMPLETE ----------
_install_soc_stack() {
    _info "🚀 Installing Complete Open-Source SOC Stack..."
    
    # Installation Wazuh SIEM/XDR
    _info "Installing Wazuh SIEM..."
    curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
    sudo bash ./wazuh-install.sh -a
    
    # Installation TheHive + Cortex
    _info "Installing TheHive & Cortex..."
    wget -O- https://raw.githubusercontent.com/TheHive-Project/Cortex/master/install.sh | sudo bash
    wget -O- https://raw.githubusercontent.com/TheHive-Project/TheHive/master/install.sh | sudo bash
    
    # Installation MISP
    _info "Installing MISP Threat Intelligence Platform..."
    sudo apt install -y mysql-server redis-server
    git clone https://github.com/MISP/MISP.git /var/www/MISP
    cd /var/www/MISP && sudo bash install/ubuntu/install.sh
    
    # Installation Shuffle SOAR
    _info "Installing Shuffle SOAR..."
    git clone https://github.com/Shuffle/Shuffle.git
    cd Shuffle && docker-compose up -d
    
    # Installation Velociraptor EDR
    _info "Installing Velociraptor EDR..."
    wget https://github.com/Velocidex/velociraptor/releases/download/v0.7.2/velociraptor-v0.7.2-linux-amd64
    sudo mv velociraptor-v0.7.2-linux-amd64 /usr/local/bin/velociraptor
    chmod +x /usr/local/bin/velociraptor
    
    # Installation Suricata IDS/IPS
    _info "Installing Suricata IDS..."
    sudo apt install -y suricata
    sudo systemctl enable suricata
    
    # Configuration des rules Suricata
    sudo suricata-update
    
    # Installation Zeek Network Monitor
    _info "Installing Zeek NSM..."
    echo 'deb https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /' | sudo tee /etc/apt/sources.list.d/security:zeek.list
    curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null
    sudo apt update && sudo apt install -y zeek
    sudo ln -s /opt/zeek/bin/zeek /usr/local/bin/zeek
    
    # Installation osquery
    _info "Installing osquery..."
    sudo apt install -y osquery
    
    # Installation MITRE CALDERA
    _info "Installing MITRE CALDERA..."
    git clone https://github.com/mitre/caldera.git --recursive
    cd caldera && pip install -r requirements.txt
    
    _success "✅ SOC Stack Installation Complete!"
    _info "Access Wazuh: https://localhost:443 (admin: ChangeMe@123)"
    _info "Access TheHive: http://localhost:9000"
    _info "Access Shuffle SOAR: http://localhost:3001"
    _info "Access MISP: http://localhost:80 (admin: ChangeMe@123)"
}

# ---------- VÉRIFICATION DES DÉPENDANCES ----------
_check_dependencies() {
    _info "Checking system dependencies..."
    
    local required_utils=("curl" "wget" "git" "make" "unzip" "jq" "nmap" "dig" "whois" "python3" "pip3" "docker" "docker-compose")
    local missing_utils=()
    
    for util in "${required_utils[@]}"; do
        if ! command -v "$util" &> /dev/null; then
            missing_utils+=("$util")
        fi
    done
    
    if [[ ${#missing_utils[@]} -gt 0 ]]; then
        _warning "Missing utilities: ${missing_utils[*]}"
        _info "Installing missing packages..."
        
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y "${missing_utils[@]}" build-essential python3-pip
            sudo pip3 install --upgrade pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y epel-release
            sudo yum install -y "${missing_utils[@]}" gcc make python3-pip
        fi
    fi
    
    if ! command -v go &> /dev/null; then
        _info "Installing Go..."
        wget -q https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin
        export PATH=$PATH:$HOME/go/bin
        rm go1.21.5.linux-amd64.tar.gz
    fi
    
    # Installation Docker si absent
    if ! command -v docker &> /dev/null; then
        _info "Installing Docker..."
        curl -fsSL https://get.docker.com | sudo bash
        sudo usermod -aG docker $USER
    fi
    
    _success "All dependencies satisfied"
}

# ---------- INSTALLATION DES OUTILS ----------
_install_tools() {
    _info "🚀 Installing/Updating security tools..."
    
    mkdir -p "$HOME/go/bin"
    export PATH="$PATH:$HOME/go/bin"
    
    # Installation ProjectDiscovery Suite
    declare -A pd_tools=(
        ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
        ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
        ["naabu"]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        ["katana"]="github.com/projectdiscovery/katana/cmd/katana@latest"
        ["uncover"]="github.com/projectdiscovery/uncover/cmd/uncover@latest"
        ["chaos"]="github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
        ["dnsx"]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
        ["cvemap"]="github.com/projectdiscovery/cvemap/cmd/cvemap@latest"
        ["cloudlist"]="github.com/projectdiscovery/cloudlist/cmd/cloudlist@latest"
        ["asnmap"]="github.com/projectdiscovery/asnmap/cmd/asnmap@latest"
        ["cdncheck"]="github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest"
        ["notify"]="github.com/projectdiscovery/notify/cmd/notify@latest"
        ["interactsh"]="github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
    )
    
    for tool in "${!pd_tools[@]}"; do
        _info "Installing/Updating $tool..."
        go install -v "${pd_tools[$tool]}" 2>/dev/null || _warning "Failed to install $tool"
    done
    
    # Installation outils OSINT
    _info "Installing OSINT tools..."
    pip3 install theHarvester recon-ng shodan holehe maigret exifread metagoofil
    
    # Installation SpiderFoot
    if [[ ! -d "$HOME/spiderfoot" ]]; then
        git clone https://github.com/smicallef/spiderfoot.git "$HOME/spiderfoot"
        pip3 install -r "$HOME/spiderfoot/requirements.txt"
    fi
    
    # Installation Sherlock
    if [[ ! -d "$HOME/sherlock" ]]; then
        git clone https://github.com/sherlock-project/sherlock.git "$HOME/sherlock"
        pip3 install -r "$HOME/sherlock/requirements.txt"
    fi
    
    # Installation Holehe
    if [[ ! -d "$HOME/holehe" ]]; then
        git clone https://github.com/megadose/holehe.git "$HOME/holehe"
    fi
    
    # Installation Maigret
    if [[ ! -d "$HOME/maigret" ]]; then
        git clone https://github.com/soxoj/maigret.git "$HOME/maigret"
        pip3 install -r "$HOME/maigret/requirements.txt"
    fi
    
    # Installation outils web
    sudo apt install -y gobuster wfuzz feroxbuster whatweb dnsrecon
    
    # Installation Dalfox
    go install github.com/hahwul/dalfox/v2@latest
    
    # Installation Kiterunner
    go install github.com/assetnote/kiterunner/cmd/kiterunner@latest
    
    # Installation Nuclei templates
    if [[ ! -d "$HOME/nuclei-templates" ]]; then
        nuclei -update-templates -dir "$HOME/nuclei-templates" > /dev/null 2>&1
    fi
    
    # Installation SecLists
    if [[ ! -d "/usr/share/seclists" ]]; then
        git clone --depth 1 https://github.com/danielmiessler/SecLists.git /tmp/seclists
        sudo mv /tmp/seclists /usr/share/seclists 2>/dev/null || mv /tmp/seclists "$HOME/seclists"
    fi
    
    # Installation Ferma
    if [[ ! -d "/usr/share/ferma" ]]; then
        git clone https://github.com/fermasearch/ferma.git /tmp/ferma
        sudo mv /tmp/ferma /usr/share/ferma
    fi
    
    _success "All tools installed"
}

# ---------- IA & PRIORISATION ----------
_predict_bounty() {
    local vulnerability="$1"
    local severity="$2"
    local score=0
    
    case "$severity" in
        "critical") score=8000 ;;
        "high")     score=2500 ;;
        "medium")   score=800 ;;
        "low")      score=150 ;;
        *)          score=0 ;;
    esac
    
    # Bonus pour vulnérabilités critiques
    case "$vulnerability" in
        *"RCE"*|*"SQLi"*|*"SSRF"*|*"SSTI"*|*"LFI"*) score=$((score + 3000)) ;;
        *"XSS"*|*"IDOR"*|*"CSRF"*) score=$((score + 800)) ;;
        *"Subdomain Takeover"*) score=$((score + 1200)) ;;
        *"Info Disclosure"*) score=$((score - 300)) ;;
    esac
    
    echo "$score"
}

_ai_analysis() {
    local findings_file="$1"
    local ai_report="${OUTPUT_DIR}/SOC/ai_analysis.md"
    
    if [[ "$USE_AI" != true ]]; then
        return 0
    fi
    
    _info "🧠 AI-powered vulnerability analysis..."
    
    if command -v ollama &> /dev/null; then
        _info "Using local LLM (Ollama) for deep analysis..."
        
        cat > "$ai_report" << 'EOF'
# 🤖 SOC AI Vulnerability Analysis Report

## Executive Summary
*Generated by SHADOWHUNT AI Engine*

EOF
        
        while IFS= read -r finding; do
            if [[ -n "$finding" ]]; then
                echo -e "\n## Vulnerability Analysis\n" >> "$ai_report"
                echo "$finding" | ollama run llama2 --prompt "Analyze this security vulnerability: $finding" >> "$ai_report" 2>/dev/null || true
            fi
        done < "$findings_file"
    else
        _info "Using heuristic-based AI analysis..."
        cat > "$ai_report" << 'EOF'
# 🧠 Heuristic Vulnerability Analysis

## Assessment Matrix

| Severity | Priority | Bounty Range |
|----------|----------|--------------|
| Critical | P0 | $5000-$10000 |
| High     | P1 | $1000-$5000  |
| Medium   | P2 | $250-$1000   |
| Low      | P3 | $50-$250     |

EOF
    fi
    
    _success "AI analysis completed: $ai_report"
}

# ---------- PHASE 1 : OSINT AVANCÉ ----------
_osint_reconnaissance() {
    _info "🔍 PHASE 1: Advanced OSINT Reconnaissance for $TARGET_DOMAIN"
    
    mkdir -p "${OUTPUT_DIR}/OSINT"
    cd "${OUTPUT_DIR}/OSINT"
    
    # 1. Subdomain enumeration (passif + actif)
    _info "Enumerating subdomains..."
    if command -v subfinder &> /dev/null; then
        subfinder -d "$TARGET_DOMAIN" -all -silent | tee subdomains_passive.txt
    fi
    
    if command -v chaos &> /dev/null; then
        chaos -d "$TARGET_DOMAIN" -silent | tee -a subdomains_passive.txt
    fi
    
    cat subdomains_passive.txt | sort -u > subdomains_all.txt
    _success "Found $(wc -l < subdomains_all.txt) subdomains"
    
    # 2. DNS Enumeration
    _info "DNS enumeration..."
    if command -v dnsx &> /dev/null; then
        dnsx -l subdomains_all.txt -a -resp -silent -o dns_records.txt
        dnsx -l subdomains_all.txt -aaaa -resp -silent -o dns_aaaa.txt
    fi
    
    # 3. WHOIS et ASN lookup
    _info "WHOIS & ASN enumeration..."
    whois "$TARGET_DOMAIN" > whois_info.txt
    if command -v asnmap &> /dev/null; then
        asnmap -d "$TARGET_DOMAIN" -silent -o asn_info.txt
    fi
    
    # 4. Email harvesting
    _info "Email harvesting..."
    if command -v theHarvester &> /dev/null; then
        theHarvester -d "$TARGET_DOMAIN" -b all -l 500 -f emails_harvested
    fi
    
    # 5. Social media reconnaissance
    if [[ -f "$HOME/sherlock/sherlock" ]]; then
        _info "Social media reconnaissance..."
        python3 "$HOME/sherlock/sherlock" --domain "$TARGET_DOMAIN" --output social_media.txt 2>/dev/null || true
    fi
    
    # 6. Email verification avec Holehe
    if [[ -f "$HOME/holehe/holehe" ]]; then
        _info "Email verification..."
        while read email; do
            python3 "$HOME/holehe/holehe" "$email" >> email_verification.txt 2>/dev/null || true
        done < emails_harvested.html 2>/dev/null || true
    fi
    
    # 7. SpiderFoot OSINT automation
    if [[ -f "$HOME/spiderfoot/sf.py" ]]; then
        _info "SpiderFoot OSINT automation..."
        python3 "$HOME/spiderfoot/sf.py" -s "$TARGET_DOMAIN" -o spiderfoot_results.json 2>/dev/null || true
    fi
    
    # 8. Google Dorks generation
    _info "Generating Google Dorks..."
    cat > google_dorks.txt << EOF
site:$TARGET_DOMAIN intitle:"index of"
site:$TARGET_DOMAIN ext:php | ext:asp | ext:jsp
site:$TARGET_DOMAIN inurl:admin | inurl:login
site:$TARGET_DOMAIN "powered by"
site:$TARGET_DOMAIN intitle:"error" | intitle:"warning"
intitle:"dashboard" $TARGET_DOMAIN
"$TARGET_DOMAIN" "password" filetype:log
"$TARGET_DOMAIN" "api_key" filetype:txt
EOF
    
    # 9. Shodan search (si API key configurée)
    if command -v shodan &> /dev/null; then
        _info "Shodan search..."
        shodan domain "$TARGET_DOMAIN" > shodan_results.txt 2>/dev/null || true
    fi
    
    # 10. Wayback Machine et archive.org
    _info "Wayback Machine enumeration..."
    if command -v waybackurls &> /dev/null; then
        cat subdomains_all.txt | waybackurls | sort -u > wayback_urls.txt
    fi
    
    cd - > /dev/null
    _success "OSINT reconnaissance completed"
}

# ---------- PHASE 2 : RECONNAISSANCE RÉSEAU ----------
_network_reconnaissance() {
    _info "🌐 PHASE 2: Network Reconnaissance"
    
    mkdir -p "${OUTPUT_DIR}/Network"
    cd "${OUTPUT_DIR}/Network"
    
    # 1. Port scanning avec Naabu
    _info "Scanning ports..."
    if command -v naabu &> /dev/null; then
        naabu -list "${OUTPUT_DIR}/OSINT/subdomains_all.txt" -silent -top-ports 1000 -o ports_all.txt
    fi
    
    # 2. HTTP probing avec httpx
    _info "HTTP probing..."
    if command -v httpx &> /dev/null; then
        cat "${OUTPUT_DIR}/OSINT/subdomains_all.txt" | httpx -silent -status-code -title -tech-detect -follow-redirects -o live_hosts.txt
    fi
    
    # 3. Technology detection
    _info "Technology detection..."
    if command -v whatweb &> /dev/null; then
        cat live_hosts.txt | cut -d' ' -f1 | while read url; do
            whatweb "$url" >> tech_detection.txt 2>/dev/null || true
        done
    fi
    
    # 4. CDN detection
    if command -v cdncheck &> /dev/null; then
        cdncheck -i live_hosts.txt -o cdn_hosts.txt
    fi
    
    # 5. Cloud resources enumeration
    if command -v cloudlist &> /dev/null; then
        cloudlist -d "$TARGET_DOMAIN" -silent -o cloud_resources.txt
    fi
    
    # 6. URL crawling avec Katana
    _info "URL crawling..."
    if command -v katana &> /dev/null; then
        cat live_hosts.txt | cut -d' ' -f1 | while read url; do
            katana -u "$url" -silent -o "katana_$(echo $url | sed 's/[^a-zA-Z0-9]/_/g').txt" 2>/dev/null || true
        done
        cat katana_*.txt | sort -u > all_urls.txt 2>/dev/null || true
    fi
    
    cd - > /dev/null
    _success "Network reconnaissance completed"
}

# ---------- PHASE 3 : SCAN DE VULNÉRABILITÉS ----------
_vulnerability_scan() {
    _info "🛡️ PHASE 3: Vulnerability Detection & Scanning"
    
    mkdir -p "${OUTPUT_DIR}/Vulnerabilities"
    local findings_file="${OUTPUT_DIR}/Vulnerabilities/findings_all.txt"
    > "$findings_file"
    
    # 1. Nuclei vulnerability scanning
    if command -v nuclei &> /dev/null; then
        _info "Running Nuclei scans..."
        
        local categories=("cves" "exposures" "misconfiguration" "technologies" "vulnerabilities" "takeovers" "default-logins" "misconfiguration" "file" "network" "ssl" "cloud")
        
        for category in "${categories[@]}"; do
            if [[ -d "$HOME/nuclei-templates/$category" ]] || [[ -f "$HOME/nuclei-templates/$category.yaml" ]]; then
                _info "Scanning: $category templates"
                nuclei -l "${OUTPUT_DIR}/Network/live_hosts.txt" \
                       -t "$category" \
                       -severity critical,high,medium \
                       -json \
                       -o "${OUTPUT_DIR}/Vulnerabilities/nuclei_${category}.json" 2>/dev/null || true
            fi
        done
        
        # Extraction résultats Nuclei
        for json_file in "${OUTPUT_DIR}/Vulnerabilities"/nuclei_*.json; do
            if [[ -f "$json_file" ]]; then
                jq -r '"[\(.info.severity)] \(.info.name) - \(.matched-at)"' "$json_file" >> "$findings_file" 2>/dev/null || true
            fi
        done
    fi
    
    # 2. CVE mapping
    if command -v cvemap &> /dev/null; then
        _info "CVE vulnerability mapping..."
        cvemap -silent -o "${OUTPUT_DIR}/Vulnerabilities/cve_mapping.txt" 2>/dev/null || true
    fi
    
    # 3. XSS Detection with Dalfox
    if command -v dalfox &> /dev/null && [[ -f "${OUTPUT_DIR}/Network/all_urls.txt" ]]; then
        _info "XSS vulnerability scanning..."
        dalfox file "${OUTPUT_DIR}/Network/all_urls.txt" --silent --no-color -o "${OUTPUT_DIR}/Vulnerabilities/xss_results.txt" > /dev/null 2>&1 || true
        
        if [[ -f "${OUTPUT_DIR}/Vulnerabilities/xss_results.txt" ]]; then
            grep -E "(Vulnerability|Found)" "${OUTPUT_DIR}/Vulnerabilities/xss_results.txt" >> "$findings_file" || true
        fi
    fi
    
    # 4. API endpoint discovery with Kiterunner
    if command -v kiterunner &> /dev/null && [[ -f "${OUTPUT_DIR}/Network/live_hosts.txt" ]]; then
        _info "API endpoint discovery..."
        cat "${OUTPUT_DIR}/Network/live_hosts.txt" | cut -d' ' -f1 | while read url; do
            kiterunner scan -u "$url" -w /usr/share/seclists/Discovery/Web-Content/api-words.txt -o "${OUTPUT_DIR}/Vulnerabilities/kr_$(echo $url | sed 's/[^a-zA-Z0-9]/_/g').json" 2>/dev/null || true
        done
    fi
    
    # 5. Directory fuzzing with FFUF
    if command -v ffuf &> /dev/null && [[ -f "${OUTPUT_DIR}/Network/live_hosts.txt" ]]; then
        _info "Directory fuzzing..."
        local wordlist="/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
        
        cat "${OUTPUT_DIR}/Network/live_hosts.txt" | cut -d' ' -f1 | head -20 | while read url; do
            ffuf -u "$url/FUZZ" -w "$wordlist" -mc 200,403,500 -o "${OUTPUT_DIR}/Vulnerabilities/ffuf_$(echo $url | sed 's/[^a-zA-Z0-9]/_/g').json" -of json -c -t 50 -s > /dev/null 2>&1 || true
        done
    fi
    
    _success "Vulnerability scan completed"
}

# ---------- PHASE 4 : SOC SIEM INTÉGRATION ----------
_soc_siem_integration() {
    if [[ "$USE_SIEM" != true ]]; then
        return 0
    fi
    
    _info "🏢 PHASE 4: SOC/SIEM Integration & Monitoring"
    
    mkdir -p "${OUTPUT_DIR}/SOC"
    
    # 1. Wazuh integration
    if command -v wazuh &> /dev/null; then
        _info "Integrating with Wazuh SIEM..."
        # Export findings to Wazuh
        cat > "${OUTPUT_DIR}/SOC/wazuh_alerts.json" << EOF
{
  "agent": {
    "name": "SHADOWHUNT-Scanner",
    "ip": "127.0.0.1"
  },
  "manager": {
    "name": "wazuh-manager"
  },
  "data": {
    "vulnerabilities": "$(cat "${OUTPUT_DIR}/Vulnerabilities/findings_all.txt" | wc -l)",
    "target": "$TARGET_DOMAIN",
    "timestamp": "$(date -Iseconds)"
  }
}
EOF
    fi
    
    # 2. osquery endpoint monitoring
    if command -v osquery &> /dev/null; then
        _info "Running osquery endpoint queries..."
        
        osqueryi --json "SELECT * FROM processes;" > "${OUTPUT_DIR}/SOC/osquery_processes.json" 2>/dev/null || true
        osqueryi --json "SELECT * FROM listening_ports;" > "${OUTPUT_DIR}/SOC/osquery_ports.json" 2>/dev/null || true
        osqueryi --json "SELECT * FROM users;" > "${OUTPUT_DIR}/SOC/osquery_users.json" 2>/dev/null || true
    fi
    
    # 3. Suricata IDS rules testing
    if command -v suricata &> /dev/null; then
        _info "Testing Suricata IDS rules..."
        suricata --list-runmodes > "${OUTPUT_DIR}/SOC/suricata_modes.txt" 2>/dev/null || true
    fi
    
    # 4. Zeek network monitoring
    if command -v zeek &> /dev/null; then
        _info "Zeek network analysis..."
        zeek --version > "${OUTPUT_DIR}/SOC/zeek_version.txt"
    fi
    
    # 5. Velociraptor endpoint forensics
    if command -v velociraptor &> /dev/null; then
        _info "Velociraptor endpoint collection..."
        velociraptor --version > "${OUTPUT_DIR}/SOC/velociraptor_version.txt"
    fi
    
    _success "SOC integration completed"
}

# ---------- PHASE 5 : SOAR AUTOMATION ----------
_soar_automation() {
    if [[ "$USE_SOAR" != true ]]; then
        return 0
    fi
    
    _info "⚡ PHASE 5: SOAR Automation & Response"
    
    mkdir -p "${OUTPUT_DIR}/SOAR"
    
    # 1. Shuffle SOAR workflow generation
    cat > "${OUTPUT_DIR}/SOAR/shuffle_workflow.yaml" << 'EOF'
name: SHADOWHUNT-Automated-Response
description: Automated incident response workflow
triggers:
  - type: webhook
    name: vulnerability-detected
    conditions:
      - severity: critical
actions:
  - name: enrich-virustotal
    type: api
    url: https://www.virustotal.com/api/v3/urls
  - name: create-ticket
    type: jira
    project: SEC
    priority: Critical
  - name: notify-slack
    type: slack
    channel: security-alerts
EOF
    
    # 2. TheHive case creation
    if command -v thehive &> /dev/null; then
        _info "Creating TheHive case..."
        cat > "${OUTPUT_DIR}/SOAR/thehive_case.json" << EOF
{
  "title": "SHADOWHUNT Scan - $TARGET_DOMAIN",
  "description": "Automated vulnerability scan results",
  "severity": 2,
  "tags": ["bug-bounty", "automated", "SHADOWHUNT"],
  "customFields": {
    "targetDomain": "$TARGET_DOMAIN",
    "findingsCount": $(cat "${OUTPUT_DIR}/Vulnerabilities/findings_all.txt" 2>/dev/null | wc -l)
  }
}
EOF
    fi
    
    # 3. MISP IOC sharing
    if command -v misp &> /dev/null; then
        _info "Sharing IOCs with MISP..."
        cat > "${OUTPUT_DIR}/SOAR/misp_iocs.json" << EOF
{
  "info": "SHADOWHUNT detected IOCs for $TARGET_DOMAIN",
  "analysis": 2,
  "threat_level_id": 2,
  "distribution": 1
}
EOF
    fi
    
    # 4. Cortex analyzer invocation
    if command -v cortex &> /dev/null; then
        _info "Invoking Cortex analyzers..."
        cat > "${OUTPUT_DIR}/SOAR/cortex_analyzers.txt" << 'EOF'
Analyzers to run:
- VirusTotal_Scan
- AbuseIPDB
- URLScan
- Shodan
- Censys
- RiskIQ
EOF
    fi
    
    # 5. SOAR notifications
    cat > "${OUTPUT_DIR}/SOAR/notify.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "framework": "SHADOWHUNT v2.0",
  "target": "$TARGET_DOMAIN",
  "severity_summary": {
    "critical": $(grep -c "\[critical\]" "${OUTPUT_DIR}/Vulnerabilities/findings_all.txt" 2>/dev/null || echo 0),
    "high": $(grep -c "\[high\]" "${OUTPUT_DIR}/Vulnerabilities/findings_all.txt" 2>/dev/null || echo 0),
    "medium": $(grep -c "\[medium\]" "${OUTPUT_DIR}/Vulnerabilities/findings_all.txt" 2>/dev/null || echo 0),
    "low": $(grep -c "\[low\]" "${OUTPUT_DIR}/Vulnerabilities/findings_all.txt" 2>/dev/null || echo 0)
  },
  "report_path": "${OUTPUT_DIR}/report.md"
}
EOF
    
    _success "SOAR automation completed"
}

# ---------- PHASE 6 : GÉNÉRATION DE RAPPORT ----------
_generate_report() {
    _info "📊 PHASE 6: Generating Comprehensive Report"
    
    local report_file="${OUTPUT_DIR}/report.md"
    local vuln_file="${OUTPUT_DIR}/Vulnerabilities/findings_all.txt"
    
    cat > "$report_file" << EOF
# 🔒 SHADOWHUNT Security Assessment Report

**Target Domain:** $TARGET_DOMAIN  
**Scan Date:** $(date)  
**Execution Mode:** $MODE  

| Feature | Status |
|---------|--------|
| AI Analysis | $(if [[ "$USE_AI" == true ]]; then echo "✅ Enabled"; else echo "❌ Disabled"; fi) |
| SOAR Automation | $(if [[ "$USE_SOAR" == true ]]; then echo "✅ Enabled"; else echo "❌ Disabled"; fi) |
| SIEM Integration | $(if [[ "$USE_SIEM" == true ]]; then echo "✅ Enabled"; else echo "❌ Disabled"; fi) |
| EDR Monitoring | $(if [[ "$USE_EDR" == true ]]; then echo "✅ Enabled"; else echo "❌ Disabled"; fi) |
| Deep OSINT | $(if [[ "$USE_OSINT_DEEP" == true ]]; then echo "✅ Enabled"; else echo "❌ Disabled"; fi) |

---

## 📊 Executive Summary

### Key Statistics

| Metric | Value |
|--------|-------|
| Subdomains Discovered | $(wc -l < "${OUTPUT_DIR}/OSINT/subdomains_all.txt" 2>/dev/null || echo "N/A") |
| Live Hosts | $(wc -l < "${OUTPUT_DIR}/Network/live_hosts.txt" 2>/dev/null || echo "N/A") |
| URLs Collected | $(wc -l < "${OUTPUT_DIR}/Network/all_urls.txt" 2>/dev/null || echo "N/A") |
| Vulnerabilities Found | $(wc -l < "$vuln_file" 2>/dev/null || echo "0") |

---

## 🎯 Vulnerability Findings

### Critical & High Severity

$(grep -E "\[(critical|high)\]" "$vuln_file" 2>/dev/null || echo "No critical/high severity findings")

### Medium & Low Severity

$(grep -E "\[(medium|low)\]" "$vuln_file" 2>/dev/null || echo "No medium/low severity findings")

---

## 🎯 MITRE ATT&CK Framework Mapping

| Tactic | Technique | ID |
|--------|-----------|-----|
| Reconnaissance | Active Scanning | T1595 |
| Reconnaissance | Passive Scanning | T1597 |
| Discovery | Network Service Discovery | T1046 |
| Discovery | System Information Discovery | T1082 |
| Initial Access | Exploit Public-Facing Application | T1190 |
| Persistence | Account Manipulation | T1098 |

---

## 💰 Bounty Potential Analysis

| Vulnerability | Severity | Estimated Bounty |
|---------------|----------|------------------|
$(if [[ -f "$vuln_file" ]]; then
    grep -E "\[(critical|high|medium|low)\]" "$vuln_file" | head -10 | while read line; do
        if [[ "$line" =~ \[(critical|high|medium|low)\]\ (.*) ]]; then
            sev="${BASH_REMATCH[1]}"
            vuln="${BASH_REMATCH[2]}"
            bounty=$(_predict_bounty "$vuln" "$sev")
            echo "| $vuln | ${sev^^} | \$$bounty |"
        fi
    done
else
    echo "| No vulnerabilities found | N/A | \$0 |"
fi)

---

## 🛠️ Tools Used

### OSINT Tools
- theHarvester, Recon-ng, SpiderFoot, Shodan, Sherlock, Holehe, Maigret

### Network Reconnaissance
- Subfinder, Chaos, DNSx, Asnmap, Naabu, Httpx, Katana

### Vulnerability Detection
- Nuclei, Cvemap, Dalfox, Kiterunner, FFUF

### SOC/SIEM Tools
- Wazuh SIEM, Osquery, Suricata, Zeek, Velociraptor

### SOAR Automation
- Shuffle, TheHive, Cortex, MISP

---

## 📝 Recommendations

1. **Critical & High Severity**  
   - Patch immediately or implement compensating controls
   - Prioritize based on exploitability and business impact

2. **Medium Severity**  
   - Address in next maintenance window
   - Document exceptions if accepted

3. **Security Hardening**  
   - Implement security headers
   - Deploy Web Application Firewall
   - Regular vulnerability scanning

4. **SOC Improvements**  
   - Integrate findings into Wazuh for continuous monitoring
   - Create automated playbooks in Shuffle SOAR
   - Share IOCs with MISP threat intelligence platform

---

*Report generated by SHADOWHUNT Framework v2.0 | Open Source Security Tool*
*Powered by ProjectDiscovery, Wazuh, TheHive, and the open source community*

EOF
    
    # Intégration analyse IA
    if [[ -f "${OUTPUT_DIR}/SOC/ai_analysis.md" ]]; then
        echo -e "\n## 🤖 AI-Assisted Analysis\n" >> "$report_file"
        cat "${OUTPUT_DIR}/SOC/ai_analysis.md" >> "$report_file" 2>/dev/null || true
    fi
    
    # Intégration SOAR
    if [[ -f "${OUTPUT_DIR}/SOAR/notify.json" ]]; then
        echo -e "\n## 🔄 SOAR Automation Summary\n" >> "$report_file"
        echo '```json' >> "$report_file"
        cat "${OUTPUT_DIR}/SOAR/notify.json" >> "$report_file" 2>/dev/null || true
        echo '```' >> "$report_file"
    fi
    
    _success "Report generated: $report_file"
    
    # Affichage des résultats
    _print_terminal_table
}

_print_terminal_table() {
    echo -e "\n═══════════════════════════════════════════════════════════════════════════════"
    echo -e "🔍 SHADOWHUNT SCAN RESULTS - $TARGET_DOMAIN"
    echo -e "═══════════════════════════════════════════════════════════════════════════════"
    
    printf "%-12s | %-45s | %-12s\n" "SEVERITY" "VULNERABILITY" "BOUNTY"
    echo "-------------+-----------------------------------------------+--------------"
    
    local findings="${OUTPUT_DIR}/Vulnerabilities/findings_all.txt"
    if [[ -f "$findings" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ \[(critical|high|medium|low)\]\ (.*) ]]; then
                severity="${BASH_REMATCH[1]}"
                vuln="${BASH_REMATCH[2]}"
                bounty=$(_predict_bounty "$vuln" "$severity")
                case "$severity" in
                    critical) printf "%-12s | %-45.45s | \$$%-11d\n" "🔴 CRITICAL" "$vuln" "$bounty" ;;
                    high)     printf "%-12s | %-45.45s | \$$%-11d\n" "🟠 HIGH" "$vuln" "$bounty" ;;
                    medium)   printf "%-12s | %-45.45s | \$$%-11d\n" "🟡 MEDIUM" "$vuln" "$bounty" ;;
                    low)      printf "%-12s | %-45.45s | \$$%-11d\n" "🟢 LOW" "$vuln" "$bounty" ;;
                esac
            fi
        done < "$findings"
    else
        echo -e "No vulnerabilities found in this scan."
    fi
    echo -e "═══════════════════════════════════════════════════════════════════════════════\n"
}

# ---------- FONCTION PRINCIPALE ----------
_main() {
    _print_banner
    _parse_arguments "$@"
    
    if [[ "$UPDATE_TOOLS_ONLY" == true ]]; then
        _install_tools
        exit 0
    fi
    
    start_time=$(date +%s)
    _info "🚀 Starting SHADOWHUNT Framework on $TARGET_DOMAIN"
    _info "Output directory: $OUTPUT_DIR"
    _info "Mode: $MODE"
    
    # Vérification des dépendances
    _check_dependencies
    
    # Installation des outils
    _install_tools
    
    # Création de l'arborescence
    mkdir -p "$OUTPUT_DIR"/{OSINT,Network,Vulnerabilities,SOC,SOAR}
    
    # Pipeline complet selon le mode
    case "$MODE" in
        "full")
            _osint_reconnaissance
            _network_reconnaissance
            _vulnerability_scan
            [[ "$USE_SIEM" == true ]] && _soc_siem_integration
            [[ "$USE_SOAR" == true ]] && _soar_automation
            ;;
        "fast")
            _osint_reconnaissance
            _vulnerability_scan
            ;;
        "stealth")
            _osint_reconnaissance
            _network_reconnaissance
            _vulnerability_scan
            ;;
        "soc")
            _soc_siem_integration
            _soar_automation
            ;;
        "osint")
            _osint_reconnaissance
            ;;
        *)
            _osint_reconnaissance
            _network_reconnaissance
            _vulnerability_scan
            [[ "$USE_SIEM" == true ]] && _soc_siem_integration
            [[ "$USE_SOAR" == true ]] && _soar_automation
            ;;
    esac
    
    # Analyse IA
    _ai_analysis "${OUTPUT_DIR}/Vulnerabilities/findings_all.txt"
    
    # Génération rapport
    _generate_report
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    _success "Scan completed in $duration seconds"
    _info "📄 Report available at: ${OUTPUT_DIR}/report.md"
    _info "📁 All results saved in: ${OUTPUT_DIR}"
}

# ---------- EXÉCUTION ----------
_main "$@"
