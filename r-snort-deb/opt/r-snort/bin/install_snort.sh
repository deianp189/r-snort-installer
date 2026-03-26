#!/bin/bash

###############################################################################
# snort_install_debug - build and install Snort 3 with full diagnostics
###############################################################################
snort_install() {
  local SOFTWARE_DIR="$1"
  local INSTALL_DIR="$2"

  local SRC_DIR="$SOFTWARE_DIR/snort3-src"
  local BUILD_DIR=""
  local LOG_DIR="/tmp/r-snort-debug"
  local CONFIG_LOG="$LOG_DIR/snort_configure.log"
  local MAKE_LOG="$LOG_DIR/snort_make.log"
  local INSTALL_LOG="$LOG_DIR/snort_install.log"

  mkdir -p "$LOG_DIR"

  log "Preparing Snort 3 installation..."
  log "Software directory: $SOFTWARE_DIR"
  log "Install directory: $INSTALL_DIR"
  log "Debug logs directory: $LOG_DIR"

  [[ -d "$SOFTWARE_DIR" ]] || error "Software directory does not exist: $SOFTWARE_DIR"
  [[ -f "$SOFTWARE_DIR/snort3.tar.gz" ]] || error "snort3.tar.gz not found in $SOFTWARE_DIR"

  cd "$SOFTWARE_DIR" || error "Cannot enter software directory: $SOFTWARE_DIR"

  log "Cleaning previous extracted source directory..."
  rm -rf "$SRC_DIR"
  mkdir -p "$SRC_DIR" || error "Cannot create source directory: $SRC_DIR"

  log "Extracting snort3.tar.gz into fixed directory..."
  tar -xzf snort3.tar.gz -C "$SRC_DIR" --strip-components=1 || error "Failed to extract snort3.tar.gz"

  [[ -f "$SRC_DIR/configure_cmake.sh" ]] || error "configure_cmake.sh not found after extraction"

  cd "$SRC_DIR" || error "Cannot enter source directory: $SRC_DIR"

  log "Applying historical NUMTHREADS fix..."
  sed -i 's/\[ \"\\$NUMTHREADS\" -lt \"\\$MINTHREADS\" \]/[ \"${NUMTHREADS:-0}\" -lt \"${MINTHREADS:-1}\" ]/' configure_cmake.sh \
    || error "Failed to patch configure_cmake.sh"

  log "Applying global compatibility patch for fixed-width integer types in snort2lua..."
  local patched_count=0
  while IFS= read -r -d '' f; do
    if grep -Eq '\buint(8|16|32|64)_t\b|\bint(8|16|32|64)_t\b' "$f"; then
      if ! grep -q '^#include <cstdint>$' "$f"; then
        {
          echo '#include <cstdint>'
          cat "$f"
        } > "${f}.tmp" || error "Failed to create patched temporary file for $f"

        mv "${f}.tmp" "$f" || error "Failed to replace patched file $f"
        patched_count=$((patched_count + 1))
        log "Patched: $f"
      fi
    fi
  done < <(find tools/snort2lua -type f \( -name '*.cc' -o -name '*.h' \) -print0)

  log "Global cstdint patch completed. Files patched: $patched_count"

  export CXXFLAGS="-Wno-deprecated-declarations"
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

  log "Checking libdaq version..."
  local daq_ver
  daq_ver=$(pkg-config --modversion libdaq 2>/dev/null || echo 0)
  log "Detected libdaq version: $daq_ver"

  [[ "${daq_ver%%.*}" -lt 3 ]] && error "libdaq $daq_ver detected (< 3.0). Dependency installation failed."

  log "Checking DAQ headers..."
  local hdr_dir
  hdr_dir=$(pkg-config --cflags libdaq | sed -n 's/^-I\([^ ]*\).*$/\1/p')
  [[ -n "$hdr_dir" ]] || error "Could not resolve libdaq include directory from pkg-config"
  [[ -f "$hdr_dir/daq_module_api.h" ]] || error "DAQ headers not found in $hdr_dir"

  log "DAQ include directory: $hdr_dir"

  log "System info before configure:"
  uname -a | tee "$LOG_DIR/uname.log"
  {
    echo "===== free -h ====="
    free -h
    echo
    echo "===== swapon --show ====="
    swapon --show
    echo
    echo "===== nproc ====="
    nproc
    echo
    echo "===== df -h ====="
    df -h
  } | tee "$LOG_DIR/system_state_before_build.log"

  log "Running configure_cmake.sh..."
  ./configure_cmake.sh --prefix="$INSTALL_DIR" 2>&1 | tee "$CONFIG_LOG"
  [[ ${PIPESTATUS[0]} -ne 0 ]] && error "configure_cmake.sh failed. Check $CONFIG_LOG"

  BUILD_DIR="$SRC_DIR/build"
  [[ -d "$BUILD_DIR" ]] || error "Build directory was not created: $BUILD_DIR"

  cd "$BUILD_DIR" || error "Cannot enter build directory: $BUILD_DIR"

  log "Invoking temporary swap logic..."
  temp_swap_if_necessary

  log "System info after temp_swap_if_necessary:"
  {
    echo "===== free -h ====="
    free -h
    echo
    echo "===== swapon --show ====="
    swapon --show
    echo
    echo "===== vmstat 1 5 ====="
    vmstat 1 5
  } | tee "$LOG_DIR/system_state_after_swap.log"

  log "Starting Snort 3 compilation in debug mode..."
  log "Using single-threaded build to reveal the real error clearly."
  make -j1 VERBOSE=1 2>&1 | tee "$MAKE_LOG"
  local make_status=${PIPESTATUS[0]}

  if [[ $make_status -ne 0 ]]; then
    log "Build failed. Running quick diagnostics..."

    if grep -qi "Killed" "$MAKE_LOG"; then
      log "Possible OOM detected: a compiler or linker process was killed."
    fi

    if grep -qi "fatal error" "$MAKE_LOG"; then
      log "A fatal compiler error was detected in the build log."
    fi

    if grep -qi "undefined reference" "$MAKE_LOG"; then
      log "A linker error was detected in the build log."
    fi

    if grep -qi "No such file or directory" "$MAKE_LOG"; then
      log "A missing file/header/library was detected in the build log."
    fi

    {
      echo
      echo "===== Last 120 lines of make log ====="
      tail -n 120 "$MAKE_LOG"
      echo
      echo "===== dmesg tail (OOM hints may appear here) ====="
      dmesg | tail -n 80 || true
    } | tee "$LOG_DIR/post_failure_diagnostics.log"

    error "Snort build failed. Check $MAKE_LOG and $LOG_DIR/post_failure_diagnostics.log"
  fi

  log "Compilation finished successfully. Running installation..."
  sudo make install 2>&1 | tee "$INSTALL_LOG"
  [[ ${PIPESTATUS[0]} -ne 0 ]] && error "make install failed. Check $INSTALL_LOG"

  log "Refreshing linker cache..."
  sudo ldconfig || error "ldconfig failed"

  log "Creating global symlink..."
  sudo ln -sf "$INSTALL_DIR/bin/snort" /usr/local/bin/snort || error "Failed to create snort symlink"

  log "Verifying installed binary..."
  [[ -x "$INSTALL_DIR/bin/snort" ]] || error "Installed snort binary not found at $INSTALL_DIR/bin/snort"

  "$INSTALL_DIR/bin/snort" -V 2>&1 | tee "$LOG_DIR/snort_version.log"
  [[ ${PIPESTATUS[0]} -ne 0 ]] && error "Installed snort binary exists but failed to execute. Check $LOG_DIR/snort_version.log"

  success "Snort 3 installed successfully."
}