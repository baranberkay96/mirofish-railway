#!/bin/sh
# Starts the MiroFish backend on Railway: checks the required keys, keeps model
# downloads on the volume, sizes CPU thread pools from the service's CPU quota and
# runs upstream's own entry point (backend/run.py). MiroFish itself is unmodified.
set -eu

UPLOAD_DIR=/app/backend/uploads
MAX_AUTO_THREADS=8

log() { printf '[mirofish] %s\n' "$*"; }
fail() { printf '[mirofish] ERROR: %s\n' "$*" >&2; exit 1; }

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Railway may create optional variables with an empty value. Upstream reads them
# with os.environ.get(name, default), so "" would replace the default (int("")
# crashes, base_url="" breaks the OpenAI client). Drop empty ones.
for var in LLM_BASE_URL LLM_MODEL_NAME OASIS_DEFAULT_MAX_ROUNDS \
           REPORT_AGENT_MAX_TOOL_CALLS REPORT_AGENT_MAX_REFLECTION_ROUNDS \
           REPORT_AGENT_TEMPERATURE LLM_BOOST_API_KEY LLM_BOOST_BASE_URL \
           LLM_BOOST_MODEL_NAME ZEP_API_URL SECRET_KEY HF_TOKEN HF_HOME \
           FLASK_HOST MIROFISH_CPU_THREADS; do
  eval "value=\${$var-}"
  if [ -z "$value" ]; then
    unset "$var"
  fi
done

missing=""
[ -n "${LLM_API_KEY:-}" ] || missing="$missing LLM_API_KEY"
[ -n "${ZEP_API_KEY:-}" ] || missing="$missing ZEP_API_KEY"
if [ -n "$missing" ]; then
  fail "missing required variable(s):$missing. Set them on the MiroFish service and redeploy."
fi
if [ -n "${ZEP_API_URL:-}" ]; then
  fail "ZEP_API_URL is set, but MiroFish only supports Zep Cloud. Remove the variable."
fi
for var in OASIS_DEFAULT_MAX_ROUNDS REPORT_AGENT_MAX_TOOL_CALLS REPORT_AGENT_MAX_REFLECTION_ROUNDS; do
  eval "value=\${$var-}"
  if [ -n "$value" ] && ! is_uint "$value"; then
    fail "$var must be a whole number (got '$value')."
  fi
done
if [ -n "${LLM_BOOST_API_KEY:-}" ] && { [ -z "${LLM_BOOST_BASE_URL:-}" ] || [ -z "${LLM_BOOST_MODEL_NAME:-}" ]; }; then
  log "WARNING: LLM_BOOST_API_KEY is set without LLM_BOOST_BASE_URL and LLM_BOOST_MODEL_NAME; set all three."
fi

# Upstream's Flask server (werkzeug, threaded, not asyncio) on "::" accepts IPv4
# and IPv6, which covers Railway's IPv4 healthcheck and IPv6 private networking.
export FLASK_HOST="${FLASK_HOST:-::}"
export FLASK_PORT="${PORT:-5001}"
export FLASK_DEBUG="${FLASK_DEBUG:-false}"
if ! is_uint "$FLASK_PORT"; then
  fail "PORT must be a number (got '$FLASK_PORT')."
fi

# Projects, simulations and reports live in backend/uploads (upstream path).
mkdir -p "$UPLOAD_DIR"
if ! grep -qs " $UPLOAD_DIR " /proc/mounts; then
  log "WARNING: $UPLOAD_DIR is not a mounted volume; projects and simulations will be lost on redeploy."
fi

# OASIS downloads Twitter/twhin-bert-base (~1.1 GB) for Twitter simulations; keep it on the volume.
export HF_HOME="${HF_HOME:-$UPLOAD_DIR/.cache/huggingface}"
mkdir -p "$HF_HOME"

# Thread pools (torch/OpenMP/BLAS) default to the host's core count, not the
# service's CPU share. Size them from the cgroup quota, capped at MAX_AUTO_THREADS.
cpu_quota_threads() {
  limit=""
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if is_uint "${quota:-}" && is_uint "${period:-}" && [ "$period" -gt 0 ]; then
      limit=$(( (quota + period - 1) / period ))
    fi
  elif [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
    quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
    period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
    if is_uint "$quota" && is_uint "$period" && [ "$period" -gt 0 ]; then
      limit=$(( (quota + period - 1) / period ))
    fi
  fi
  if [ -z "$limit" ]; then
    limit=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
  fi
  if ! is_uint "$limit" || [ "$limit" -lt 1 ]; then
    limit=1
  fi
  if [ "$limit" -gt "$MAX_AUTO_THREADS" ]; then
    limit=$MAX_AUTO_THREADS
  fi
  echo "$limit"
}

if [ -n "${MIROFISH_CPU_THREADS:-}" ]; then
  if ! is_uint "$MIROFISH_CPU_THREADS" || [ "$MIROFISH_CPU_THREADS" -lt 1 ]; then
    fail "MIROFISH_CPU_THREADS must be a positive whole number (got '$MIROFISH_CPU_THREADS')."
  fi
  threads=$MIROFISH_CPU_THREADS
else
  threads=$(cpu_quota_threads)
fi
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$threads}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-$threads}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-$threads}"
export NUMEXPR_MAX_THREADS="${NUMEXPR_MAX_THREADS:-$threads}"

base_host=$(printf '%s' "${LLM_BASE_URL:-https://api.openai.com/v1}" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##')
log "listen [${FLASK_HOST}]:${FLASK_PORT}  model=${LLM_MODEL_NAME:-gpt-4o-mini}  llm_host=${base_host}  max_rounds=${OASIS_DEFAULT_MAX_ROUNDS:-10}  threads=${OMP_NUM_THREADS}  hf_home=${HF_HOME}"

cd /app/backend
exec /app/backend/.venv/bin/python run.py
