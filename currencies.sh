#!/bin/bash


# cryptocurrencies other than btc/eth to check
CURRENCIES="ARK MCO NAV NEO OMG XVG"


# set variables
CURL="curl -s --connect-timeout 2 -m 5"
FILE="/tmp/$(basename ${0})-$(whoami)"
PRG="$(basename ${0})"


# set file
if [[ ! -f "${FILE}" ]]; then
  install -m 0600 /dev/null ${FILE} || exit 1
fi


# check output
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


# set functions
function format() {
  rev | sed "s/.\{3\}/&'/g" | rev | sed "s/^'//"
}
function lykke() {
  awk '{print $2}' | sed 's/,$//'
}


# check ip
if ! ip a | grep inet | awk '{print $2}' | grep -qvE "^127.0.0.1"; then
  echo " | No IP | " > ${FILE}

  if tty -s; then
    echo -e "\nNo IP!\n"
  fi

  exit 1
fi


# get lykke btc prices
BTC="$(${CURL} "https://lykke-public-api.azurewebsites.net/api/Market/BTCCHF" | python -mjson.tool 2> /dev/null)"
if [[ ! -z "${BTC}" ]]; then
  BTCBUY="$(echo "${BTC}" | grep "\"ask\"" | lykke | awk -F'.' '{print $1}' | format)"
  BTCSLL="$(echo "${BTC}" | grep "\"bid\"" | lykke | awk -F'.' '{print $1}' | format)"
  CRYPTO=" | BTC: ${BTCBUY} ${BTCSLL}"
else
  CRYPTO=" | BTC: error"
fi

# get lykke eth prices
ETH="$(${CURL} "https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF" | python -mjson.tool 2> /dev/null)"
if [[ ! -z "${ETH}" ]]; then
  ETHBUY="$(echo "${ETH}" | grep "\"ask\"" | lykke | awk -F'.' '{print $1}' | format)"
  ETHSLL="$(echo "${ETH}" | grep "\"bid\"" | lykke | awk -F'.' '{print $1}' | format)"
  CRYPTO+=" | ETH: ${ETHBUY} ${ETHSLL}"
else
  CRYPTO+=" | ETH: error"
fi


# calculate bittrex prices
if [[ ! -z "${BTC}" ]]; then
BTCPRICE="$(echo "${BTC}" | grep "\"bid\"" | lykke)"
  for i in ${CURRENCIES}; do
    CRC="$(${CURL} "https://bittrex.com/api/v1.1/public/getticker?market=BTC-${i}" | python -mjson.tool 2> /dev/null)"

    if [[ ! -z "${CRC}" ]]; then
      CRCPRICE="$(echo "${CRC}" | grep "\"Bid\"" | awk '{print $2}' | sed -e 's/,$//' -e 's/[eE]+*/\*10\^/')"
      CALC="$(echo "${BTCPRICE} * ${CRCPRICE}" | bc -l | sed -e 's/^\./0\./' -e 's/\.$/\.00/')"

      PRC="$(echo "${CALC}" | awk -F'.' '{print $1}' | format)"
      DEC="$(echo "${CALC}" | awk -F'.' '{print $2}')"

      # set rounding
      if [[ "${PRC}" != "0" ]]; then
        ROUND="2"
      else
        ROUND="4"
      fi

      CRYPTO+="$(echo -n " | ${i}: ${PRC}.${DEC:0:${ROUND}}")"
    fi
  done
fi


# generate output
echo "${CRYPTO} | " > ${FILE}

if tty -s; then
  echo "${CRYPTO}" | sed -e 's/^ | //' -e 's/ | /\n/g' | column -ets':'
fi

exit $?
