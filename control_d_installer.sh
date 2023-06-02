#!/bin/sh

cat << EOF

        __         .__       .___
  _____/  |________|  |    __| _/
_/ ___\   __\_  __ \  |   / __ |
\  \___|  |  |  | \/  |__/ /_/ |
 \___  >__|  |__|  |____/\____ |
     \/       installer       \/

EOF

# Check for root/system permissions
#if command -v id >/dev/null 2>&1; then
#  [ "$(id -u)" -eq 0 ] || { echo "Please re-run this command with root/system permissions."; exit 1; }
#fi

# Detect OS and architecture
OS=""
OS_VENDOR=""
OS_VERSION=""
ARCH="$(uname -m)"
BINARY_PATH=""
INSTALL_PATH=""

# Detect OS
if [ "$(uname -s)" = "Linux" ]; then
  OS="linux"
  if [ -f "/etc/os-release" ]; then
    . /etc/os-release
    OS_VENDOR="$ID"
    OS_VERSION="$VERSION"

    # Check for Ubiquiti EdgeRouter
    if [ "$OS_VENDOR" = "debian" ] || [ "$OS_VENDOR" = "Debian" ]; then
      if command -v /opt/vyatta/bin/vyatta-op-cmd-wrapper >/dev/null 2>&1; then
        HW_MODEL=$(/opt/vyatta/bin/vyatta-op-cmd-wrapper show version | grep "HW model:" | awk -F ':' '{print $2}' | xargs)
        if echo "$HW_MODEL" | grep -q "EdgeRouter"; then
          OS_VENDOR="EdgeOS"
          ROUTER_MODEL="$HW_MODEL"
          OS_VERSION=$(/opt/vyatta/bin/vyatta-op-cmd-wrapper show version | grep "Version:" | awk -F ':' '{print $2}' | xargs)
        fi
      fi
    fi
  else
    OS_VENDOR="$(uname -s)"
  fi
  # Check for ASUSWRT-Merlin, DD-WRT, and Tomato using uname -o
  os_name="$(uname -o 2>/dev/null)"
  case $os_name in
    "ASUSWRT-Merlin")
      OS_VENDOR="ASUSWRT-Merlin"
      ;;
    "DD-WRT")
      OS_VENDOR="DD-WRT"
      ;;
    "Tomato")
      OS_VENDOR="Tomato"
      ;;
  esac
  # Check for Synology
  if [ "$(uname -u 2>/dev/null | cut -d '_' -f 1)" = "synology" ]; then
    OS_VENDOR="Synology"
  fi
elif [ "$(uname -s)" = "FreeBSD" ]; then
  OS="freebsd"
  OS_VENDOR="FreeBSD"
  # Detect if the system is running pfSense
    if uname -v | grep "pfSense"; then
      OS_VENDOR="pfSense"
    fi
elif [ "$(uname -s)" = "Darwin" ]; then
    OS="darwin"
    OS_VENDOR="MacOS"
    if command -v sw_vers >/dev/null 2>&1; then
        OS_VERSION=$(sw_vers -productVersion)
    fi
else
  echo "Unsupported operating system"
  exit 1
fi

# Some UBIOS routers return Debian as the OS vendor - override this
if command -v ubnt-device-info >/dev/null 2>&1; then
  if ubnt-device-info summary | grep -q "Device information summary"; then
    OS_VENDOR="ubios"
  fi
fi

# Set binary path and install path based on architecture
case "$OS" in
  linux)
    case "$ARCH" in
      i386|i686) BINARY_PATH="linux/386/ctrld" ;;
      x86_64) BINARY_PATH="linux/amd64/ctrld" ;;
      aarch64)
        if [ "$OS_VENDOR" = "ASUSWRT-Merlin" ] || [ "$OS_VENDOR" = "DD-WRT" ] || [ "$OS_VENDOR" = "Tomato" ]; then
               BINARY_PATH="linux/armv5/ctrld"
             else
               BINARY_PATH="linux/arm64/ctrld"
             fi
             ;;
      armv5*) BINARY_PATH="linux/armv5/ctrld" ;;
      armv6*) BINARY_PATH="linux/armv6/ctrld" ;;
      armv7*)
             if [ "$OS_VENDOR" = "ASUSWRT-Merlin" ] || [ "$OS_VENDOR" = "DD-WRT" ] || [ "$OS_VENDOR" = "Tomato" ]; then
               BINARY_PATH="linux/armv5/ctrld"
             else
               BINARY_PATH="linux/armv7/ctrld"
             fi
             ;;
      mips64) BINARY_PATH="linux/mips64/ctrld" ;;
      mips*)
        if [ -n "$(hexdump -s 5 -n 1 $(command -v hexdump) | sed -n '/ 0001/p')" ]; then
            BINARY_PATH="linux/mipsle/ctrld"
        else
            BINARY_PATH="linux/mips_softfloat/ctrld"
        fi
        ;;
      *) echo "Unsupported architecture"; exit 1 ;;
    esac
    ;;
  freebsd)
    case "$ARCH" in
      i386) BINARY_PATH="freebsd/386/ctrld" ;;
      amd64) BINARY_PATH="freebsd/amd64/ctrld" ;;
      aarch64) BINARY_PATH="freebsd/arm64/ctrld" ;;
      armv6*) BINARY_PATH="freebsd/armv6/ctrld" ;;
      armv7*) BINARY_PATH="freebsd/armv7/ctrld" ;;
      *) echo "Unsupported architecture"; exit 1 ;;
    esac
    ;;
  darwin)
      case "$ARCH" in
        amd64|x86_64) BINARY_PATH="darwin/amd64/ctrld" ;;
        arm64) BINARY_PATH="darwin/arm64/ctrld" ;;
        *) echo "Unsupported architecture"; exit 1 ;;
      esac
      ;;
  *)
    echo "Unsupported operating system"
    exit 1
    ;;
esac

# Set install path based on OS_VENDOR
if [ "$OS_VENDOR" = "ASUSWRT-Merlin" ]; then
  INSTALL_PATH="/jffs/controld"
elif [ "$OS_VENDOR" = "DD-WRT" ]; then
  if [ "$(nvram get enable_jffs2)" = "0" ]; then
    echo "JFFS is not enabled on your DD-WRT router. Please enable it and try again. https://wiki.dd-wrt.com/wiki/index.php/JFFS_File_System"
    exit 1
  fi
  INSTALL_PATH="/jffs/controld"
elif [ "$OS_VENDOR" = "Tomato" ]; then
  if [ "$(nvram get jffs2_on)" = "0" ]; then
    echo "JFFS is not enabled on your Tomato router. Please enable it and try again. https://wiki.freshtomato.org/doku.php/admin-jffs2"
    exit 1
  fi
  INSTALL_PATH="/jffs/controld"
elif [ "$OS_VENDOR" = "openwrt" ] || [ "$OS_VENDOR" = "ubios" ] || [ "$OS_VENDOR" = "Synology" ]; then
  if [ "$OS_VENDOR" = "ubios" ] && [ -d "/data" ]; then
    INSTALL_PATH="/data/controld"
    if [ ! -d "$INSTALL_PATH" ]; then
      mkdir -p "$INSTALL_PATH"
    fi
  else
    INSTALL_PATH="/usr/sbin"
  fi
elif [ "$OS_VENDOR" = "EdgeOS" ]; then
  INSTALL_PATH="/usr/sbin"
else
  INSTALL_PATH="/usr/local/bin"
fi

BASE_URL="https://assets.controld.com/ctrld"
BINARY_URL="$BASE_URL/$BINARY_PATH"

# Get CPU name
CPU_NAME=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -n 1 | cut -d ':' -f 2 | xargs 2>/dev/null || true)

if [ -z "$CPU_NAME" ]; then
  if command -v lscpu >/dev/null 2>&1; then
    CPU_NAME=$(lscpu | grep "Model name" | cut -d ':' -f 2 | xargs)
  elif which sysinfo >/dev/null 2>&1; then
    CPU_NAME=$(sysinfo | grep "Processor" | awk -F ':' '{print $2}' | head -n 1 | awk '{$1=$1};1')
  elif command -v sysctl >/dev/null 2>&1; then
    if [ "$OS" = "darwin" ]; then
      CPU_NAME=$(sysctl -n machdep.cpu.brand_string)
    elif [ "$OS" = "freebsd" ]; then
      CPU_NAME=$(sysctl hw.model | cut -d ':' -f 2 | xargs)
    fi
  fi
fi

# Use OPENWRT_ARCH as fallback if CPU name is still blank
if [ -z "$CPU_NAME" ] && [ -n "$OPENWRT_ARCH" ]; then
  CPU_NAME="$OPENWRT_ARCH"
elif [ -z "$CPU_NAME" ]; then
  CPU_NAME="N/A"
fi

# Get total and available RAM
TOTAL_RAM=""
AVAILABLE_RAM=""
if [ "$OS" = "linux" ]; then
  TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  AVAILABLE_RAM=$(grep MemFree /proc/meminfo | awk '{print $2}')
  TOTAL_RAM=$((TOTAL_RAM / 1024))
  AVAILABLE_RAM=$((AVAILABLE_RAM / 1024))
elif [ "$OS" = "freebsd" ]; then
  TOTAL_RAM=$(sysctl -n hw.physmem)
  # Workaround for 'unknown oid' error
  if sysctl -n hw.availmem >/dev/null 2>&1; then
    AVAILABLE_RAM=$(sysctl -n hw.availmem)
    AVAILABLE_RAM=$((AVAILABLE_RAM / 1024))
  else
    AVAILABLE_RAM=$(sysctl -a | grep 'Free Memory' | awk '{print $3}' | tr -d 'K')
  fi
  TOTAL_RAM=$((TOTAL_RAM / 1024 / 1024))
  AVAILABLE_RAM=$((AVAILABLE_RAM / 1024))
elif [ "$OS" = "darwin" ]; then
  TOTAL_RAM=$(sysctl -n hw.memsize)
  AVAILABLE_RAM=$(vm_stat | awk '/Pages free:/ {free=$3} /Pages inactive:/ {inactive=$3} /Pages speculative:/ {speculative=$3} END {print free+inactive+speculative}')
  TOTAL_RAM=$((TOTAL_RAM / 1024 / 1024))
  AVAILABLE_RAM=$((AVAILABLE_RAM * 4096 / 1024 / 1024))
else
  TOTAL_RAM="?"
  AVAILABLE_RAM="?"
fi

# Detect if actually running on router platform
ROUTER_PLATFORM="no"
for platform in openwrt ddwrt "ASUSWRT-Merlin" "DD-WRT" "Tomato" ubios "EdgeOS"; do
  if echo "$OS_VENDOR" | grep -i -q "$platform"; then
    ROUTER_PLATFORM="yes"
    break
  fi
done

# Get router model name and version if running on router platform (ubios)
if [ "$ROUTER_PLATFORM" = "yes" ] && [ "$OS_VENDOR" = "ubios" ]; then
  if command -v mca-cli-op info >/dev/null 2>&1; then
    ROUTER_MODEL=$(mca-cli-op info | grep "Model:" | cut -d ':' -f 2 | xargs)
    OS_VERSION=$(mca-cli-op info | grep "Version:" | cut -d ':' -f 2 | xargs)
  fi
fi

# Print detected information
echo "---------------------"
echo "|    System Info    |"
echo "---------------------"
echo "OS Type      : $OS"
echo "OS Vendor    : $OS_VENDOR"
if [ -n "$OS_VERSION" ]; then
  echo "OS Version   : $OS_VERSION"
fi
echo "Is Router    : $ROUTER_PLATFORM"
if [ -n "$ROUTER_MODEL" ]; then
  echo "Router Model : $ROUTER_MODEL"
fi
echo "Arch         : $ARCH"
echo "CPU          : $CPU_NAME"
echo "Free RAM     : ${AVAILABLE_RAM} MB / ${TOTAL_RAM} MB"
echo "---------------------"
echo "|  Install Details  |"
echo "---------------------"
[ -n "$1" ] && echo "Resolver ID  : $1"
echo "Binary URL   : $BINARY_URL"
echo "Install Path : $INSTALL_PATH"
echo "---------------------"

# Check if install path exists
if [ ! -d "$INSTALL_PATH" ]; then
  if [ "$OS_VENDOR" = "ASUSWRT-Merlin" ] || [ "$OS_VENDOR" = "DD-WRT" ] || [ "$OS_VENDOR" = "Tomato" ]; then
    mkdir -p "$INSTALL_PATH"
  else
    echo "Install path $INSTALL_PATH does not exist. Please create it manually and try again."
    exit 1
  fi
fi

# Get user confirmation to proceed further
if [ "$2" != "forced" ]; then
  read -p "Install binary and run it? (y/n): " choice
  if [ "$choice" != "y" ]; then
    echo "We were so close, but ok. Exiting."
    exit 0
  fi
fi

# Check if process is already running
UPGRADE="no"
if [ -f "$INSTALL_PATH/ctrld" ]; then
  "$INSTALL_PATH/ctrld" service status >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    UPGRADE="yes"
    echo " - Detected running process, this is an upgrade"
  fi
fi

if [ "$UPGRADE" = "yes" ]; then
  # Download binary to a temp location
  TEMP_BINARY_PATH="$INSTALL_PATH/ctrld_temp"
  echo " - Starting download"
  if { command -v curl || which curl; } >/dev/null 2>&1; then
    curl -sS -o "$TEMP_BINARY_PATH" "$BINARY_URL"
  elif { command -v wget || which wget; } >/dev/null 2>&1; then
    wget -O "$TEMP_BINARY_PATH" "$BINARY_URL"
  else
    echo "wget or curl not found. Please install one of them."
    exit 1
  fi

  # Stop the running process
  echo " - Stopping running process"
  "$INSTALL_PATH/ctrld" stop -s

  # Move the temp binary to the install path
  echo " - Replacing old binary with the new one"
  mv "$TEMP_BINARY_PATH" "$INSTALL_PATH/ctrld"
else
  # Download binary
  echo " - Starting download"
  if { command -v curl || which curl; } >/dev/null 2>&1; then
    curl -sS -o "$INSTALL_PATH/ctrld" "$BINARY_URL"
  elif { command -v wget || which wget; } >/dev/null 2>&1; then
    wget -O "$INSTALL_PATH/ctrld" "$BINARY_URL"
  else
    echo "wget or curl not found. Please install one of them."
    exit 1
  fi
fi

# Make binary executable
echo " - Making binary executable"
chmod +x "$INSTALL_PATH/ctrld"

echo " - Launching $INSTALL_PATH/ctrld"
echo "---------------------"

# Execute binary
if [ -z "$1" ]; then
  "$INSTALL_PATH/ctrld"
else
  if [ "$ROUTER_PLATFORM" = "yes" ]; then
    if [ "$2" = "debug" ]; then
      "$INSTALL_PATH/ctrld" setup auto --cd "$1" -vv
    else
      "$INSTALL_PATH/ctrld" setup auto --cd "$1" -v
    fi
  else
    if [ "$2" = "debug" ]; then
      "$INSTALL_PATH/ctrld" start --cd "$1" -vv
    else
      "$INSTALL_PATH/ctrld" start --cd "$1" -v
    fi
  fi
fi
