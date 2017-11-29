#!/bin/bash


# check arguments
while getopts "k:s:" opt; do
  case ${opt} in
    k)
      APIKEY="${OPTARG}"
      ;;
    s)
      SECRETKEY="${OPTARG}"
      ;;
  esac
done

if [[ -z "${APIKEY}" ]] || [[ -z "${SECRETKEY}" ]]; then
  echo -e "\n$(basename ${0}) requires an API key and a secret key:\n" >&2
  echo -e " -k APIKEY" >&2
  echo -e " -s SECRETKEY" >&2
  echo -e "\nAPI keys can be acquired at https://bittrex.com/Manage#sectionApi\n" >&2
  exit 1
fi


# set variables
TMOUT="2"
TMOUTMAX="5"


# get BTC in CHF
BTC="$(curl -s --connect-timeout ${TMOUT} -m ${TMOUTMAX} "https://data.bitlog.ch/btc/price.txt")"
if [[ -z "${BTC}" ]]; then
  echo -e "BTC error"
  exit 1
fi


# get account information
APIURL="https://bittrex.com/api/v1.1/account/getbalances?apikey=${APIKEY}&nonce=$(date '+%s')"
SIGN="$(echo -n "${APIURL}" | openssl sha512 -hmac "${SECRETKEY}" | awk '{print $NF}')"
ACCOUNT="$(curl -s --connect-timeout ${TMOUT} -m ${TMOUTMAX} -H "apisign: ${SIGN}" "${APIURL}" | python -mjson.tool 2> /dev/null)"

# check account information success
if echo "${ACCOUNT}" | grep -q \""success\": false"; then
  echo "$(echo "${ACCOUNT}" | grep "\"message\":" | awk -F':' '{print $2}' | sed -e 's/^ "//' -e 's/",$//')"
fi


# get all wallets
if [[ ! -z "${ACCOUNT}" ]]; then
  WALLETS="$(echo "${ACCOUNT}" | grep -E 'Balance|Currency' | awk '{print $2}' | sed -e 's/"//g' -e 's/,$//' | tac | tr '\n' ' ' | sed 's/ /\n/2;P;D' | grep -v " 0.0$" | sort)"

else
  echo -e "\nCouldn't access account\n"
  exit 1
fi


# functions
function calc() {
  sed -e 's/[eE]+*/\*10\^/' | bc -l | sed -e 's/^\./0\./' -e 's/\.$/\.00/'
}
function format() {
  rev | sed "s/.\{3\}/&'/g" | rev | sed "s/^'//"
}
function tochf() {
  COINCALC="$(echo "${CALC} * ${COINS}" | calc)"

  CALCFLL="$(echo "${CALC}" | sed 's/^\./0./' | awk -F'.' '{print $1}')"
  CALCDEC="$(echo "${CALC}" | awk -F'.' '{print $2}')"

  TOTAL+="+${COINCALC}"
  TOTALCALC="$(echo "${TOTAL}" | bc)"
  TOTALCHF="$(echo "${TOTALCALC}" | sed 's/^\./0./' | awk -F'.' '{print $1}' | format)"
  TOTALDEC="$(echo "${TOTALCALC}" | awk -F'.' '{print $2}')"

  CHFFLL="$(echo "${COINCALC}" | sed 's/^\./0./' | awk -F'.' '{print $1}' | format)"
  CHFDEC="$(echo "${COINCALC}" | awk -F'.' '{print $2}')"
}


# calculate all cryptos
TOTAL="0"
printf '%s\n' "$WALLETS" | while IFS= read -r line; do
  RUN="1"
  CRC="$(echo "${line}" | awk '{print $1}')"
  COINS="$(echo "${line}" | awk '{print $2}')"
  COINSHOW="$(echo "${COINS}" | sed -e 's/[eE]+*/\*10\^/' | bc -l | sed -e 's/^\./0./' -e 's/[0]*$//' -e 's/\.$/\.00/')"

  if [[ "${CRC}" != "BTC" ]]; then
    CRCPRC="$(curl -s --connect-timeout 2 -m 5 "https://bittrex.com/api/v1.1/public/getticker?market=BTC-${CRC}" | python -mjson.tool 2> /dev/null)"

    if [[ ! -z "${CRCPRC}" ]]; then
      CRCPRICE="$(echo "${CRCPRC}" | grep "\"Bid\"" | awk '{print $2}' | sed 's/,$//')"
      CALC="$(echo "${BTC} * ${CRCPRICE}" | calc)"

    else
      RUN="0"
    fi

  else
    CALC="${BTC}"
  fi

  if [[ "${RUN}" == "1" ]]; then
    tochf
    echo "${CRC} > Amount: ${COINSHOW} > Price: ${CALCFLL}.${CALCDEC:0:2} > CHF: ${CHFFLL}.${CHFDEC:0:2} > Total: ${TOTALCHF}.${TOTALDEC:0:2}"

  else
    echo "${CRC} > ERROR!"
  fi
done | column -ets'>'

exit 0
