#!/bin/bash


# set variable variables
CRCYFILE="${HOME}/.currencies"
SLEEPTIME="10"


# set global variables
PRG="$(basename ${0})"
ALRTFILE="/tmp/${PRG}-alerts"
COLOR_GREEN="\033[01;32m"
COLOR_RED="\033[01;31m"
COLOR_NONE="\033[00m"
TERM_WIDTH="$(tput cols)"
COLUMNS="$(printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -)"


if tty -s; then
  echo
fi

if [[ ! -f "${CRCYFILE}" ]]; then
  if tty -s; then
    echo -e "Need file ${CRCYFILE} to read cryptocurrencies!\n"
  fi
  exit 1
fi


while true ; do
  for crc in $(echo "BTC ETH $(cat ${CRCYFILE})" | tr ' ' '\n' | tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ' '); do
    CRCY="$(echo "${crc}" | tr '[:lower:]' '[:upper:]')"
    CHCKFILE="/tmp/${PRG}-${crc}"

    if [[ "${CRCY}" == "BTC" ]]; then
      MARKET="USDT-${CRCY}"
    else
      MARKET="BTC-${CRCY}"
    fi

    DATA="$(curl -s --connect-timeout 2 -m 5 "https://bittrex.com/api/v1.1/public/getticker?market=${MARKET}" | python -mjson.tool 2> /dev/null)"

    if echo "${DATA}" | grep -q "\"success\": true"; then
      PRC="$(echo "${DATA}" | grep "\"Bid\"" | awk '{print $2}' | sed -e 's/,$//' -e 's/[eE]+*/\*10\^/' | bc -l | sed -e 's/^\./0./' -e 's/[0]*$//' -e 's/\.$/.00/')"
      if [[ ! -z "${PRC}" ]]; then
        if [[ "${CRCY}" == "BTC" ]]; then
          PRICE="${PRC}"
        else
          PRICE="$(echo "${PRC} * 100000000" | bc -l | awk -F'.' '{print $1}')"
        fi

        echo "${PRICE}" >> ${CHCKFILE}

        if [[ -f ${CHCKFILE} ]]; then
          if [[ "$(wc -l ${CHCKFILE} | awk '{print $1}')" -ge "1" ]]; then
            while read line; do
              if [[ ! -z "${line}" ]]; then
                PERC="$(echo "(${line} - ${PRICE}) / ${PRICE} * 100" | bc -l | awk -F'.' '{print $1}' | sed 's/^-//')"

                if [[ "$(echo "${PRICE}>${line}" | bc -l)" -ge "1" ]]; then
                  COLOR_ALERT="${COLOR_GREEN}"
                  TEXT_ALERT="more"
                else
                  COLOR_ALERT="${COLOR_RED}"
                  TEXT_ALERT="less"
                fi

                if [[ "${PERC}" -ge "10" ]]; then
                  if tty -s; then
                    echo -e "${COLUMNS}"
                    OUTPUT="${COLOR_ALERT}${CRCY} > ${PERC}% ${TEXT_ALERT}${COLOR_NONE}\n"
                    OUTPUT+="Date > $(date '+%F %T')\n"
                    OUTPUT+="Before > ${line}\n"
                    OUTPUT+="Now > ${PRICE}"
                    echo -e "${OUTPUT}" | column -ets'>'
                    echo -e "${COLUMNS}\n"
                  fi

                  if ! grep -qs "${CRCY}" ${ALRTFILE}; then
                    ALRTFILE_TEXT="${CRCY} $(cat ${ALRTFILE} 2> /dev/null)"
                    echo "${ALRTFILE_TEXT}" | sed 's/[ ]*$//' > ${ALRTFILE}
                  fi
                  break
                fi
              fi
            done < ${CHCKFILE}
          fi

          until [[ "$(wc -l ${CHCKFILE} | awk '{print $1}')" -le "5" ]]; do
            sed -i 1d ${CHCKFILE}
          done
        fi
      fi
    fi
  done

  sleep ${SLEEPTIME}
done

exit 0
