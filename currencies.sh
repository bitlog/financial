#!/bin/bash

FILE="/tmp/$(basename ${0})-$(whoami)"

if [[ ! -f "${FILE}" ]]; then
  install -m 0600 /dev/null ${FILE} || exit 1
fi

if ! tty -s; then
  SECS="$(date '+%S' | sed 's/^0//')"
  if [[ "${SECS}" -ne "0" ]] && (( ${SECS} % 15 != 0 )); then
    numerical='^[0-9]+$'
    if ! [[ "${1}" =~ ${numerical} ]] || ! [[ "${2}" =~ ${numerical} ]]; then
      echo " | NR ERROR"
      exit 1
    fi

    TTYWIDTH="${1}"
    TTYMAX="${2}"
    FOLD="$((TTYMAX-20))"

    cat ${FILE} | fold -sw $((TTYWIDTH-FOLD)) | head -1 | awk 'BEGIN{FS=OFS="|"} NF--' | sed 's/[ \t]*$//'

    exit $?
  fi
fi


URLS="# Format is as follows, separated by pipes (|): Description|Amount of decimals to round to, empty equals 2|URL|JSON element
# URLs and JSON elements are required for this to work and can be stacked infinitely
ETH||https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF|ask|https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF|bid
NEO||https://bittrex.com/api/v1.1/public/getticker?market=usdt-neo|Ask|https://bittrex.com/api/v1.1/public/getticker?market=usdt-neo|Bid
QTUM|5|https://bittrex.com/api/v1.1/public/getticker?market=btc-qtum|Ask|https://bittrex.com/api/v1.1/public/getticker?market=btc-qtum|Bid
OMG|5|https://bittrex.com/api/v1.1/public/getticker?market=btc-omg|Ask|https://bittrex.com/api/v1.1/public/getticker?market=btc-omg|Bid
BCC|0|https://bittrex.com/api/v1.1/public/getticker?market=usdt-bcc|Ask|https://bittrex.com/api/v1.1/public/getticker?market=usdt-bcc|Bid
BTC|0|https://lykke-public-api.azurewebsites.net/api/Market/BTCCHF|ask|https://lykke-public-api.azurewebsites.net/api/Market/BTCCHF|bid
USD|3|https://api.fixer.io/latest?base=CHF|USD|https://api.fixer.io/latest?base=USD|CHF
EUR|3|https://api.fixer.io/latest?base=CHF|EUR|https://api.fixer.io/latest?base=EUR|CHF"

function prices(){
  printf '%s\n' "${URLS}" | while IFS= read -r line; do
    RUN="2"
    if ! echo "${line}" | grep -qE "^$|^[[:space:]]*$|^#"; then
      EXCH="$(echo "${line}" | awk -F'|' '{print $1}')"
      ROUND="$(echo "${line}" | awk -F'|' '{print $2}')"
      if [[ -z "${ROUND}" ]]; then
        ROUND="2"
      fi

      END="$(echo "${line}" | tr '|' '\n' | wc -l)"
      echo -n " | ${EXCH}: "

      unset TOTAL
      until [[ "${RUN}" -eq "${END}" ]]; do
        ((RUN++))
        CALL="$(curl -s $(echo "${line}" | awk -F'|' -v var="${RUN}" '{print $var}') | python -mjson.tool 2> /dev/null)"

        ((RUN++))
        CALC="$(echo "${CALL}" | grep "\"$(echo "${line}" | awk -F'|' -v var="${RUN}" '{print $var}')\": " | awk -F\: '{print $2}' | sed 's/[^.0-9]//g' | xargs printf "%.${ROUND}f\n")"

        PRICE="$(echo "${CALC}" | awk -F'.' '{print $1}' | rev | sed "s/.\{3\}/&'/g" | rev | sed "s/^'//")"
        DECIMALS="$(echo "${CALC}" | awk -F'.' '{print $2}')"
        if [[ ! -z "${DECIMALS}" ]]; then
          DECIMALS=".${DECIMALS}"
        fi

        TOTAL+="${PRICE}${DECIMALS} "
      done
      echo -n "$(echo "${TOTAL}" | sed 's/ $//')"
    fi
  done
}


if ip a | grep inet | awk '{print $2}' | grep -qvE "^127.0.0.1"; then
  PRICES="$(prices)"
  echo "${PRICES} | " > ${FILE}

  if tty -s; then
    echo "${PRICES}" | sed -e 's/^ | //' -e 's/ | /\n/g' | column -ets':'
  fi

else
  echo " | No IP | " > ${FILE}

  if tty -s; then
    echo -e "\nNo IP!\n"
  fi

  exit 1
fi

exit $?
