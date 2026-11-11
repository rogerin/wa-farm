#!/usr/bin/env bash
# ==============================================================================
# wa-farm (wa-farm.sh) — v1.1.0
# Ultra-Low-RAM Android Emulator Farm for Multi-Account WhatsApp Integration
# Author: Rogério Alencar Filho (@rogerin) — KeyCore Open Source
# License: MIT
# ==============================================================================
set -euo pipefail

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega .env local se existir
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
fi

APK_DIR="${WA_APK_DIR:-${SCRIPT_DIR}/apk}"
WHATSAPP_APK="${APK_DIR}/WhatsApp.apk"
WHATSAPP_URL="${WA_APK_URL:-https://www.whatsapp.com/android/current/WhatsApp.apk}"
MAX_ACCOUNTS="${WA_MAX_ACCOUNTS:-7}"

# Detecta arquitetura da máquina (Apple Silicon ARM64 vs Intel/AMD x86_64)
HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" == "arm64" || "$HOST_ARCH" == "aarch64" ]]; then
  DEFAULT_ABI="arm64-v8a"
  CPU_ARCH="arm64"
else
  DEFAULT_ABI="x86_64"
  CPU_ARCH="x86_64"
fi

ABI_TYPE="${WA_ABI:-$DEFAULT_ABI}"
ANDROID_API="${WA_ANDROID_API:-31}"

# Perfil Ultra-Low-RAM (AOSP puro sem Google Play Services)
SYS_IMAGE="system-images;android-${ANDROID_API};default;${ABI_TYPE}"
SYS_IMAGE_REL="system-images/android-${ANDROID_API}/default/${ABI_TYPE}/"
RAM_MB="${WA_RAM_MB:-896}"
HEAP_MB="${WA_HEAP_MB:-96}"
CPU_CORES="${WA_CPU_CORES:-1}"
LCD_WIDTH="${WA_LCD_WIDTH:-360}"
LCD_HEIGHT="${WA_LCD_HEIGHT:-640}"
LCD_DENSITY="${WA_LCD_DENSITY:-160}"
DATA_SIZE="${WA_DATA_SIZE:-2048M}"

# Detecta ANDROID_SDK_ROOT automaticamente (macOS Homebrew, Android Studio ou Linux)
if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
  if [[ -d "/opt/homebrew/share/android-commandlinetools" ]]; then
    export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
  elif [[ -d "/usr/local/share/android-commandlinetools" ]]; then
    export ANDROID_SDK_ROOT="/usr/local/share/android-commandlinetools"
  elif [[ -d "$HOME/Library/Android/sdk" ]]; then
    export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
  elif [[ -d "$HOME/Android/Sdk" ]]; then
    export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
  else
    export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
  fi
fi
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
mkdir -p "$ANDROID_AVD_HOME" "$APK_DIR"

SDKMANAGER_BIN="$(command -v sdkmanager || echo "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager")"
AVDMANAGER_BIN="$(command -v avdmanager || echo "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/avdmanager")"
ADB_BIN="$(command -v adb || echo "${ANDROID_SDK_ROOT}/platform-tools/adb")"
EMULATOR_BIN="${ANDROID_SDK_ROOT}/emulator/emulator"
if [[ ! -x "$EMULATOR_BIN" ]] && command -v emulator >/dev/null 2>&1; then
  EMULATOR_BIN="$(command -v emulator)"
fi

# Funções utilitárias de mapeamento (Conta 1..N -> wa_01..wa_0N e Porta 5554..5552+2N)
avd_name() {
  printf "wa_%02d" "$1"
}

avd_port() {
  echo $(( 5552 + ($1 * 2) ))
}

avd_serial() {
  echo "emulator-$(avd_port "$1")"
}

find_avd_pid() {
  local name="$1"
  ps aux | grep -E "[q]emu-system-.*-avd ${name}([[:space:]]|$)" | awk '{print $2}' | head -n 1 || true
}

is_avd_headless() {
  local name="$1"
  ps aux | grep -E "[q]emu-system-.*-avd ${name}([[:space:]]|$)" | grep -q -- "-no-window"
}

focus_emulator_window() {
  local idx="$1"
  local name
  name="$(avd_name "$idx")"
  local pid
  pid="$(find_avd_pid "$name")"
  if [[ -n "$pid" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
    osascript -e "tell application \"System Events\" to set frontmost of (every process whose unix id is ${pid}) to true" >/dev/null 2>&1 || true
  fi
}

log_info() {
  printf "\033[1;36m[wa-farm]\033[0m %s\n" "$*"
}

log_ok() {
  printf "\033[1;32m[OK]\033[0m %s\n" "$*"
}

log_warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$*"
}

log_err() {
  printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2
}

require_sdk_tools() {
  if [[ ! -x "$SDKMANAGER_BIN" ]] && ! command -v sdkmanager >/dev/null 2>&1; then
    log_err "Ferramenta 'sdkmanager' não encontrada."
    log_info "No macOS, instale com: brew install --cask temurin android-commandlinetools android-platform-tools"
    log_info "No Ubuntu/Debian, instale: sudo apt install android-sdk-platform-tools && sdkmanager"
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# 1. SETUP: Instala Emulator + Imagem AOSP + Baixa WhatsApp.apk Oficial
# ------------------------------------------------------------------------------
cmd_setup() {
  require_sdk_tools
  log_info "Verificando SDK Android em: ${ANDROID_SDK_ROOT} (Arquitetura: ${ABI_TYPE})"
  yes | "$SDKMANAGER_BIN" --licenses >/dev/null 2>&1 || true

  log_info "Instalando Android Emulator e imagem pura AOSP (${SYS_IMAGE})..."
  "$SDKMANAGER_BIN" "platform-tools" "emulator" "platforms;android-${ANDROID_API}" "${SYS_IMAGE}"

  if [[ ! -f "$WHATSAPP_APK" ]] || [[ "$(wc -c < "$WHATSAPP_APK")" -lt 50000000 ]]; then
    log_info "Baixando APK oficial do WhatsApp direto da Meta (${WHATSAPP_URL})..."
    curl -L --fail -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
      -o "$WHATSAPP_APK" "$WHATSAPP_URL"
    log_ok "WhatsApp.apk salvo em ${WHATSAPP_APK} ($(du -h "$WHATSAPP_APK" | awk '{print $1}'))"
  else
    log_ok "WhatsApp.apk já disponível em ${WHATSAPP_APK} ($(du -h "$WHATSAPP_APK" | awk '{print $1}'))"
  fi

  log_ok "Setup concluído! Próximo passo: execute './wa-farm.sh create all' ou './wa-farm.sh bootstrap 1'."
}

# ------------------------------------------------------------------------------
# 2. CREATE: Cria AVDs wa_01..wa_0N com perfil de Máxima Economia de Memória
# ------------------------------------------------------------------------------
create_single_avd() {
  local idx="$1"
  local name
  name="$(avd_name "$idx")"
  local avd_dir="${ANDROID_AVD_HOME}/${name}.avd"

  if [[ ! -d "${ANDROID_SDK_ROOT}/${SYS_IMAGE_REL}" ]]; then
    log_warn "Imagem ${SYS_IMAGE} ainda não instalada. Executando setup primeiro..."
    cmd_setup
  fi

  log_info "Criando celular virtual ${name} (Conta #${idx} | Porta $(avd_port "$idx") | RAM: ${RAM_MB} MB)..."
  echo "no" | "$AVDMANAGER_BIN" create avd \
    --force \
    --name "$name" \
    --package "${SYS_IMAGE}" \
    --abi "${ABI_TYPE}" >/dev/null

  # Sobrescreve config.ini com tuning extremo de memória e câmera virtual para QR Code
  cat > "${avd_dir}/config.ini" <<EOF
AvdId=${name}
PlayStore.enabled=false
abi.type=${ABI_TYPE}
avd.ini.displayname=WhatsApp Farm #${idx} (${name})
avd.ini.encoding=UTF-8
disk.dataPartition.size=${DATA_SIZE}
fastboot.chosenSnapshotFile=
fastboot.forceChosenSnapshotBoot=no
fastboot.forceColdBoot=yes
fastboot.forceFastBoot=no
hw.accelerometer=no
hw.arc=false
hw.audioInput=no
hw.audioOutput=no
hw.battery=yes
hw.camera.back=virtualscene
hw.camera.front=none
hw.cpu.arch=${CPU_ARCH}
hw.cpu.ncore=${CPU_CORES}
hw.dPad=no
hw.gps=no
hw.gpu.enabled=yes
hw.gpu.mode=auto
hw.initialOrientation=Portrait
hw.keyboard=yes
hw.lcd.density=${LCD_DENSITY}
hw.lcd.height=${LCD_HEIGHT}
hw.lcd.width=${LCD_WIDTH}
hw.mainKeys=no
hw.ramSize=${RAM_MB}
hw.sdCard=no
hw.sensors.magnetic_field=no
hw.sensors.orientation=no
hw.sensors.pressure=no
hw.sensors.proximity=no
hw.trackBall=no
image.sysdir.1=${SYS_IMAGE_REL}
runtime.network.latency=none
runtime.network.speed=full
showDeviceFrame=no
skin.dynamic=yes
skin.name=${LCD_WIDTH}x${LCD_HEIGHT}
skin.path=_no_skin
tag.display=Default Android System Image
tag.id=default
vm.heapSize=${HEAP_MB}
EOF

  log_ok "AVD ${name} configurado em ${avd_dir}/config.ini (${LCD_WIDTH}x${LCD_HEIGHT}@${LCD_DENSITY}dpi, ${RAM_MB}MB RAM)."
}

cmd_create() {
  local target="${1:-all}"
  if [[ "$target" == "all" ]]; then
    for i in $(seq 1 "$MAX_ACCOUNTS"); do
      create_single_avd "$i"
    done
  else
    create_single_avd "$target"
  fi
}

# ------------------------------------------------------------------------------
# 3. START: Inicia 1 ou todos os emuladores (Background Daemon ou --foreground)
# ------------------------------------------------------------------------------
start_single_avd() {
  local idx="$1"
  shift
  local name
  name="$(avd_name "$idx")"
  local port
  port="$(avd_port "$idx")"
  local serial
  serial="$(avd_serial "$idx")"
  local avd_dir="${ANDROID_AVD_HOME}/${name}.avd"

  local headless_flags=()
  local camera_back="virtualscene"
  local gpu_mode="swiftshader_indirect"
  local run_foreground="false"
  local force_gui="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --headless)
        headless_flags=("-no-window")
        gpu_mode="off"
        ;;
      --foreground|--fg|--attach)
        run_foreground="true"
        force_gui="true"
        ;;
      --gui|--show|--window)
        force_gui="true"
        ;;
      --webcam)
        camera_back="webcam0"
        ;;
    esac
    shift
  done

  if [[ ! -d "$avd_dir" ]]; then
    log_warn "AVD ${name} ainda não existe. Criando agora..."
    create_single_avd "$idx"
  fi

  if [[ ! -x "$EMULATOR_BIN" ]]; then
    log_warn "Binário 'emulator' não encontrado. Executando setup..."
    cmd_setup
  fi

  # Verifica se já está rodando
  local existing_pid
  existing_pid="$(find_avd_pid "$name")"
  if [[ -n "$existing_pid" ]]; then
    if [[ "$force_gui" == "true" ]] && is_avd_headless "$name"; then
      log_info "${name} estava em modo headless (-no-window). Reiniciando com janela visível..."
      stop_single_avd "$idx"
      sleep 2
    else
      log_ok "${name} já está rodando em ${serial} (PID: ${existing_pid}). Trazendo janela para frente..."
      focus_emulator_window "$idx"
      return 0
    fi
  fi

  local log_file="/tmp/${name}_emulator.log"
  rm -f "$log_file"

  local emu_cmd=(
    "$EMULATOR_BIN"
    -avd "$name"
    -port "$port"
    -memory "$RAM_MB"
    -cores "$CPU_CORES"
    -no-boot-anim
    -no-audio
    -no-snapshot
    -no-snapshot-save
    -no-snapstorage
    -camera-back "$camera_back"
    -camera-front none
    -gpu "$gpu_mode"
    -netdelay none
    -netspeed full
    ${headless_flags[@]+"${headless_flags[@]}"}
  )

  if [[ "$run_foreground" == "true" ]]; then
    log_info "Iniciando ${name} em FOREGROUND (${serial} | Janela Visível | Pressione Ctrl+C para fechar)..."
    "${emu_cmd[@]}"
    return 0
  fi

  log_info "Iniciando ${name} em ${serial} (RAM máx: ${RAM_MB} MB | Câmera: ${camera_back} | GPU: ${gpu_mode})..."

  # Inicia em nova sessão independente (start_new_session=True) para não morrer ao fechar o terminal
  python3 -c '
import subprocess, sys
log = open(sys.argv[1], "wb")
p = subprocess.Popen(sys.argv[2:], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
print(p.pid)
' "$log_file" "${emu_cmd[@]}" > "/tmp/${name}.pid"

  local emu_pid
  emu_pid="$(cat "/tmp/${name}.pid")"
  log_ok "${name} iniciado (PID: ${emu_pid} | Log: ${log_file})."

  if [[ ${#headless_flags[@]} -eq 0 ]]; then
    sleep 2
    focus_emulator_window "$idx"
  fi
}

cmd_start() {
  local target="${1:-1}"
  shift || true
  if [[ "$target" == "all" ]]; then
    for i in $(seq 1 "$MAX_ACCOUNTS"); do
      start_single_avd "$i" "$@"
      sleep 3
    done
  else
    start_single_avd "$target" "$@"
  fi
}

# ------------------------------------------------------------------------------
# 4. SHOW: Sai do background/headless e mostra a janela do emulador na frente
# ------------------------------------------------------------------------------
cmd_show() {
  local idx="${1:-1}"
  shift || true
  local name
  name="$(avd_name "$idx")"
  local serial
  serial="$(avd_serial "$idx")"

  start_single_avd "$idx" --gui "$@"
  wait_for_boot "$serial"
  # Acorda a tela e abre o WhatsApp na frente do usuário
  "$ADB_BIN" -s "$serial" shell input keyevent 224 >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$serial" shell input keyevent 82 >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$serial" shell monkey -p com.whatsapp -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
  focus_emulator_window "$idx"
  log_ok "Janela do emulador ${name} (${serial}) aberta e trazida para o primeiro plano!"
}

# ------------------------------------------------------------------------------
# 5. WAIT + DEBLOAT + INSTALL-WA: Otimiza Android e instala o WhatsApp.apk
# ------------------------------------------------------------------------------
wait_for_boot() {
  local serial="$1"
  log_info "Aguardando Android iniciar completamente em ${serial}..."
  local boot_completed=""
  local attempts=0
  while [[ "$boot_completed" != "1" ]]; do
    if grep -q "FATAL" /tmp/wa_*_emulator.log 2>/dev/null; then
      log_err "Falha fatal detectada no log do emulador:"
      grep "FATAL" /tmp/wa_*_emulator.log >&2 || true
      return 1
    fi
    boot_completed="$("$ADB_BIN" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [[ "$boot_completed" == "1" ]]; then
      break
    fi
    attempts=$((attempts + 1))
    if [[ "$attempts" -gt 90 ]]; then
      log_err "Timeout aguardando boot de ${serial}."
      return 1
    fi
    sleep 2
  done
  log_ok "Boot concluído em ${serial}!"
}

debloat_android() {
  local serial="$1"
  log_info "Aplicando otimizações internas de economia de RAM em ${serial}..."
  # Desativa todas as animações de janela/transição
  "$ADB_BIN" -s "$serial" shell settings put global window_animation_scale 0.0 || true
  "$ADB_BIN" -s "$serial" shell settings put global transition_animation_scale 0.0 || true
  "$ADB_BIN" -s "$serial" shell settings put global animator_duration_scale 0.0 || true
  # Evita que a tela apague durante leitura de QR Code
  "$ADB_BIN" -s "$serial" shell settings put system screen_off_timeout 1800000 || true
  "$ADB_BIN" -s "$serial" shell svc power stayon true || true

  # Desativa apps de sistema AOSP desnecessários que consomem RAM em background
  local bloat_pkgs=(
    "com.android.calendar"
    "com.android.deskclock"
    "com.android.dialer"
    "com.android.email"
    "com.android.gallery3d"
    "com.android.messaging"
    "com.android.music"
    "com.android.quicksearchbox"
    "com.android.printspooler"
    "com.android.wallpaper.livepicker"
  )
  for pkg in "${bloat_pkgs[@]}"; do
    "$ADB_BIN" -s "$serial" shell pm disable-user --user 0 "$pkg" >/dev/null 2>&1 || true
  done
}

install_wa_single() {
  local idx="$1"
  local serial
  serial="$(avd_serial "$idx")"

  if [[ ! -f "$WHATSAPP_APK" ]]; then
    log_warn "WhatsApp.apk não encontrado em ${WHATSAPP_APK}. Baixando agora..."
    curl -L --fail -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
      -o "$WHATSAPP_APK" "$WHATSAPP_URL"
  fi

  wait_for_boot "$serial"
  debloat_android "$serial"

  if ! "$ADB_BIN" -s "$serial" shell pm list packages 2>/dev/null | grep -q "package:com.whatsapp$"; then
    log_info "Instalando WhatsApp oficial em $(avd_name "$idx") (${serial})..."
    "$ADB_BIN" -s "$serial" install -r "$WHATSAPP_APK"
  else
    log_ok "WhatsApp já está instalado em $(avd_name "$idx") (${serial})."
  fi

  # Concede permissões de câmera e armazenamento antecipadamente para leitura do QR Code
  "$ADB_BIN" -s "$serial" shell pm grant com.whatsapp android.permission.CAMERA >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$serial" shell pm grant com.whatsapp android.permission.READ_CONTACTS >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$serial" shell pm grant com.whatsapp android.permission.WRITE_CONTACTS >/dev/null 2>&1 || true

  log_info "Abrindo o WhatsApp na tela de $(avd_name "$idx")..."
  "$ADB_BIN" -s "$serial" shell monkey -p com.whatsapp -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
  focus_emulator_window "$idx"
  log_ok "WhatsApp instalado e aberto em $(avd_name "$idx") (${serial})!"
}

cmd_install_wa() {
  local target="${1:-1}"
  if [[ "$target" == "all" ]]; then
    for i in $(seq 1 "$MAX_ACCOUNTS"); do
      install_wa_single "$i"
    done
  else
    install_wa_single "$target"
  fi
}

# ------------------------------------------------------------------------------
# 6. BOOTSTRAP: Faz tudo em 1 único comando (Cria -> Abre -> Otimiza -> Instala WA)
# ------------------------------------------------------------------------------
cmd_bootstrap() {
  local idx="${1:-1}"
  shift || true
  if [[ ! -x "$EMULATOR_BIN" ]] || [[ ! -d "${ANDROID_SDK_ROOT}/${SYS_IMAGE_REL}" ]] || [[ ! -f "$WHATSAPP_APK" ]]; then
    cmd_setup
  fi
  local name
  name="$(avd_name "$idx")"
  if [[ ! -d "${ANDROID_AVD_HOME}/${name}.avd" ]]; then
    create_single_avd "$idx"
  fi
  start_single_avd "$idx" --gui "$@"
  install_wa_single "$idx"
}

# ------------------------------------------------------------------------------
# 7. QR CODE & PAIRING CODE: Injeção de QR Code na Câmera Virtual ou Código 8d
# ------------------------------------------------------------------------------
cmd_qr() {
  local idx="${1:?Informe o número da conta (1 a ${MAX_ACCOUNTS})}"
  local qr_path="${2:?Informe o caminho para a imagem PNG do QR Code}"
  local name
  name="$(avd_name "$idx")"
  local avd_dir="${ANDROID_AVD_HOME}/${name}.avd"
  local target_qr="${avd_dir}/qrcode_mensageria.png"

  if [[ ! -f "$qr_path" ]]; then
    log_err "Arquivo de imagem não encontrado: ${qr_path}"
    exit 1
  fi

  mkdir -p "$avd_dir"
  cp -f "$qr_path" "$target_qr"

  # Configura os posters da cena virtual (parede e mesa) com o QR Code
  cat > "${avd_dir}/Toren1BD.posters" <<EOF
poster wall
size 2 2
position 0 0 -1.8
rotation 0 0 0
default ${target_qr}

poster table
size 1.5 1.5
position 0 -0.45 0
rotation -90 0 0
default ${target_qr}
EOF

  log_ok "QR Code injetado na câmera virtual de ${name} (${avd_dir}/Toren1BD.posters)!"
  log_info "Dica: Se o emulador já estiver aberto, abra '...' (Extended Controls) > Camera > Wall/Table > Load Image (${target_qr}), ou use './wa-farm.sh pair ${idx} <CODIGO>' para parear sem câmera."
}

cmd_pair() {
  local idx="${1:?Informe o número da conta (1 a ${MAX_ACCOUNTS})}"
  local code="${2:?Informe o código de pareamento de 8 dígitos (ex: ABCD1234)}"
  local serial
  serial="$(avd_serial "$idx")"
  local clean_code
  clean_code="$(echo "$code" | tr -d ' -')"

  log_info "Digitando código de pareamento '${clean_code}' em $(avd_name "$idx") (${serial})..."
  "$ADB_BIN" -s "$serial" shell input text "$clean_code"
  log_ok "Código enviado para a tela do WhatsApp!"
}

# ------------------------------------------------------------------------------
# 8. LIST / STATUS: Tabela das Contas, Modo (Janela/Headless) e Consumo Total RAM
# ------------------------------------------------------------------------------
cmd_status() {
  printf "\n%-8s | %-8s | %-14s | %-7s | %-8s | %-10s | %-7s | %-10s\n" "CONTA" "AVD" "SERIAL ADB" "CRIADO?" "STATUS" "MODO" "PID" "RAM (MB)"
  printf "%s\n" "---------+----------+----------------+---------+----------+------------+---------+-----------"

  local total_ram_mb=0
  local running_count=0

  for i in $(seq 1 "$MAX_ACCOUNTS"); do
    local name
    name="$(avd_name "$i")"
    local serial
    serial="$(avd_serial "$i")"
    local created="NÃO"
    [[ -d "${ANDROID_AVD_HOME}/${name}.avd" ]] && created="SIM"

    local status="PARADO"
    local mode="-"
    local pid_str="-"
    local ram_mb="0 MB"

    local found_pid
    found_pid="$(find_avd_pid "$name")"
    if [[ -n "$found_pid" ]]; then
      status="RODANDO"
      pid_str="$found_pid"
      if is_avd_headless "$name"; then
        mode="HEADLESS"
      else
        mode="JANELA GUI"
      fi
      local rss_kb
      rss_kb="$(ps -o rss= -p "$found_pid" 2>/dev/null | awk '{print $1}' || echo 0)"
      local mb=$(( rss_kb / 1024 ))
      ram_mb="${mb} MB"
      total_ram_mb=$(( total_ram_mb + mb ))
      running_count=$(( running_count + 1 ))
    fi

    printf "Conta #%d | %-8s | %-14s | %-7s | %-8s | %-10s | %-7s | %-10s\n" "$i" "$name" "$serial" "$created" "$status" "$mode" "$pid_str" "$ram_mb"
  done

  local total_gb
  total_gb="$(awk "BEGIN {printf \"%.2f\", ${total_ram_mb}/1024}")"
  printf "%s\n" "---------+----------+----------------+---------+----------+------------+---------+-----------"
  printf "Total em execução: %d/%d emuladores | Consumo total de RAM: %d MB (%s GB)\n\n" "$running_count" "$MAX_ACCOUNTS" "$total_ram_mb" "$total_gb"
}

# ------------------------------------------------------------------------------
# 9. STOP & HEARTBEAT (Renovação das Contas de 14 em 14 dias com <1GB RAM)
# ------------------------------------------------------------------------------
stop_single_avd() {
  local idx="$1"
  local serial
  serial="$(avd_serial "$idx")"
  local name
  name="$(avd_name "$idx")"

  local found_pid
  found_pid="$(find_avd_pid "$name")"
  if "$ADB_BIN" devices 2>/dev/null | grep -q "^${serial}[[:space:]]" || [[ -n "$found_pid" ]]; then
    log_info "Desligando ${name} (${serial})..."
    "$ADB_BIN" -s "$serial" emu kill >/dev/null 2>&1 || true
    sleep 1
    if [[ -n "$found_pid" ]] && kill -0 "$found_pid" 2>/dev/null; then
      kill "$found_pid" >/dev/null 2>&1 || true
    fi
    log_ok "${name} desligado."
  else
    log_info "${name} já está parado."
  fi
}

cmd_stop() {
  local target="${1:-all}"
  if [[ "$target" == "all" ]]; then
    for i in $(seq 1 "$MAX_ACCOUNTS"); do
      stop_single_avd "$i"
    done
  else
    stop_single_avd "$target"
  fi
}

cmd_heartbeat() {
  log_info "Iniciando ciclo de Heartbeat Headless nas ${MAX_ACCOUNTS} contas (1 por vez para máxima economia de RAM)..."
  for i in $(seq 1 "$MAX_ACCOUNTS"); do
    local name
    name="$(avd_name "$i")"
    if [[ ! -d "${ANDROID_AVD_HOME}/${name}.avd" ]]; then
      log_warn "${name} ainda não foi criado. Pulando..."
      continue
    fi
    start_single_avd "$i" --headless
    local serial
    serial="$(avd_serial "$i")"
    wait_for_boot "$serial"
    log_info "Abrindo WhatsApp em ${name} por 60s para sincronizar sessão Multi-Device..."
    "$ADB_BIN" -s "$serial" shell monkey -p com.whatsapp -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
    sleep 60
    stop_single_avd "$i"
    sleep 3
  done
  log_ok "Heartbeat concluído nas contas criadas!"
}

# ------------------------------------------------------------------------------
# HELP / CLI ROUTER
# ------------------------------------------------------------------------------
cmd_help() {
  cat <<EOF
wa-farm v${VERSION} — Ultra-Low-RAM Android Emulator Farm for WhatsApp

Uso: ./wa-farm.sh <comando> [argumentos] [flags]

Comandos Principais:
  list, status, ps              Exibe a tabela das ${MAX_ACCOUNTS} contas, modo (JANELA GUI / HEADLESS), PID, Total em execução e Consumo Total de RAM
  show <1..${MAX_ACCOUNTS}>                   Sai do modo background/headless, abre a janela gráfica do emulador e traz para a frente da tela
  bootstrap <1..${MAX_ACCOUNTS}> [flags]      TUDO EM 1: Cria o AVD, abre o emulador, otimiza o Android e já instala/abre o WhatsApp
  start <1..${MAX_ACCOUNTS}|all> [flags]      Inicia o emulador de uma conta ou de todas
  setup                         Instala o Android Emulator (${ABI_TYPE}), imagem AOSP pura (Android ${ANDROID_API}) e baixa o WhatsApp.apk oficial
  create [1..${MAX_ACCOUNTS}|all]             Cria os celulares virtuais (wa_01 a wa_0${MAX_ACCOUNTS}) com perfil de máxima economia de RAM (${RAM_MB} MB, ${LCD_WIDTH}x${LCD_HEIGHT})
  install-wa <1..${MAX_ACCOUNTS}|all>         Otimiza o sistema Android via ADB e instala/abre o WhatsApp.apk oficial
  qr <1..${MAX_ACCOUNTS}> <imagem.png>        Injeta a imagem do QR Code do sistema de mensageria na câmera virtual traseira do emulador
  pair <1..${MAX_ACCOUNTS}> <CODIGO8D>        Digita automaticamente o código de pareamento de 8 dígitos no WhatsApp do emulador
  stop [1..${MAX_ACCOUNTS}|all]               Desliga o emulador de uma conta ou de todas
  heartbeat                     Liga cada uma das contas em modo headless por 60s (1 por vez) para renovar a sessão de 14 dias

Flags de Visibilidade / Execução (para 'start' e 'bootstrap'):
  --foreground, --fg            Roda o emulador anexado diretamente ao terminal atual (sem ir para background) com janela visível
  --gui, --show, --window       Garante abertura com janela gráfica visível (se estiver em --headless, reinicia com janela e foca na tela)
  --headless                    Roda em background sem janela gráfica (-no-window -gpu off) para máxima economia de RAM
  --webcam                      Usa a webcam física do computador (webcam0) na câmera traseira para ler QR Code
EOF
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  setup)                  cmd_setup "$@" ;;
  create)                 cmd_create "$@" ;;
  bootstrap)              cmd_bootstrap "$@" ;;
  start)                  cmd_start "$@" ;;
  show|attach|gui)        cmd_show "$@" ;;
  install-wa)             cmd_install_wa "$@" ;;
  qr)                     cmd_qr "$@" ;;
  pair)                   cmd_pair "$@" ;;
  list|ls|status|ps)      cmd_status "$@" ;;
  stop)                   cmd_stop "$@" ;;
  heartbeat)              cmd_heartbeat "$@" ;;
  --version|-v)           echo "wa-farm v${VERSION}" ;;
  --help|-h|help)         cmd_help ;;
  *)                      cmd_help ;;
esac
