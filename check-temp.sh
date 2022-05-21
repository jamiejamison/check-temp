#!/bin/bash
#
# check-temp.sh
# Displays the CPU and GPU temperature of a Raspberry Pi 4
#
# Use infocmp to see if the terminal can display color.
#
if (/usr/bin/infocmp "$TERM" | grep -q color); then
  COLOR="true"
else
  COLOR="false"
fi
#
# Temperature thresholds
#
WARM=50
HOT=65
#
# Offset to add if --kelvin isn't used.
#
TEMP_OFFSET=0
#
# Degree symbol to use if --kelvin isn't used.
#
DEG_SYM=$(printf "%bC" "\U00B0")
#
# Set CSV to false
#
CSV="false"
#
usage ()
{
  read -r -d '' USAGE<<EOF
Usage:

 $(basename $0) --csv -k|--kelvin --no-color -h| --help

Options:
  --csv\t\t\tOutput date, CPU and GPU temperatures and hostname
\t\t\tin comma separated variable format
  --kelvin\t\tOutput temperature in degrees Kelvin
  --no-color\t\tDon't print color output
  -h, --help\t\tdisplays this help

Example:
  Display CPU and GPU temperatures

  $(basename $0)

  Display CPU and GPU temperatures without color

  $(basename $0) --no-color

  Display CPU and GPU temperatures in degrees Kelvin

  $(basename $0) --kelvin

EOF
  echo -e "$USAGE" >&2
}
#
cool_color()
{
  while read LINE; do
    if [ "$COLOR" = "true" ]; then
      echo -e "\e[01;32m$LINE\e[0m" >&1
    else
      echo -e "$LINE\n" >&1
    fi
  done
}
#
hot_color()
{
  while read LINE; do
    if [ "$COLOR" = "true" ]; then
      echo -e "\e[01;31m$LINE\e[0m" >&1
    else
      echo -e "$LINE"
    fi
  done
}
#
warm_color()
{
  while read LINE; do
    if [ "$COLOR" = "true" ]; then
      echo -e "\e[01;33m$LINE\e[0m" >&1
    else
      echo -e "$LINE" >&1
    fi
  done
}
#
# Read the options.
#
OPTIONS=$(getopt -o hk --long csv,help,kelvin,no-color --name $(basename $0) -- "$@") 2>&1
EXIT_STATUS="$?"
if [ "$EXIT_STATUS" -ne 0 ]; then
  usage
  exit "$EXIT_STATUS"
fi
eval set -- "$OPTIONS"
#
# Extract the options and their arguments into variables.
#
while true; do
  case "$1" in
    -h|--help)
      usage
      exit 0
    ;;
    --csv)
      export CSV=true
      shift
    ;;
    -k|--kelvin)
      export TEMP_OFFSET=273200
      export DEG_SYM="K"
      shift
    ;;
    --no-color)
      COLOR="false"
      shift
    ;;
    --)
      shift
      break
    ;;
  esac
done
#
# We read CPUTEMP from /sys/class/thermal/thermal_zone0/temp
# which returns a number like this:
#
# 40407
#
# Representing the CPU temperature in thousandths of a degree
# Celsius. We only need one digit past the decimal point. printf
# to the rescue.
#
CPUTEMP=$(</sys/class/thermal/thermal_zone0/temp)
CPUTEMP=$((CPUTEMP + TEMP_OFFSET))
CPUTEMP=$(printf %.1f "$((CPUTEMP))e-3")
#
# vcgencmd measure_temp returns a string like this
#
#  temp=40.9'C
#
# Use bash parameter substitution to strip out all of the characters
# that aren't digits.
#
GPUTEMP=$(vcgencmd measure_temp)
GPUTEMP="${GPUTEMP:5:2}${GPUTEMP:8:1}00"
GPUTEMP=$((GPUTEMP + TEMP_OFFSET))
GPUTEMP=$(printf %.1f "$((GPUTEMP))e-3")
#
# Only use the first two digits of CPUTEMP or GPUTEMP
# to compare with the temperature thresholds because
# bash doesn't do floating point.
#
if [ "${CPUTEMP:0:2}" -lt $WARM ]; then
  CPU_FORMATTER=cool_color
elif [ "${CPUTEMP:0:2}" -gt $WARM ] && [ "${CPUTEMP:0:2}" -lt $HOT ]; then
  CPU_FORMATTER=warm_color
elif [ "${CPUTEMP:0:2}" -gt $HOT ]; then
  CPU_FORMATTER=hot_color
fi
#
if [ "${GPUTEMP:0:2}" -lt $WARM ]; then
  GPU_FORMATTER=cool_color
elif [ "${GPUTEMP:0:2}" -gt $WARM ] && [ "${GPUTEMP:0:2}" -lt $HOT ]; then
  GPU_FORMATTER=warm_color
elif [ "${GPUTEMP:0:2}" -gt $HOT ]; then
  GPU_FORMATTER=hot_color
fi
#
if [ "$CSV" = "false" ]; then
  echo "$(date) @ $(hostname)"
  echo "-------------------------------------------"
  echo "CPU Temperature =>" "$(echo $CPUTEMP $DEG_SYM | "$CPU_FORMATTER")"
  echo "GPU Temperature =>" "$(echo $GPUTEMP $DEG_SYM | "$GPU_FORMATTER")"
else
  echo "$(date +%Y%m%d%H%M%S),$CPUTEMP,$GPUTEMP,$(hostname)"
fi

exit 0
