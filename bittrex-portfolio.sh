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
CURL="curl -s --connect-timeout 2 -m 5"
OUTFILE="/tmp/$(basename ${0})_total.txt"


# get BTC in CHF
BTC="$(${CURL} "https://data.bitlog.ch/btc/price.txt")"
if [[ -z "${BTC}" ]]; then
  echo -e "BTC error"
  exit 1
fi


# get account information
APIURL="https://bittrex.com/api/v1.1/account/getbalances?apikey=${APIKEY}&nonce=$(date '+%s')"
SIGN="$(echo -n "${APIURL}" | openssl sha512 -hmac "${SECRETKEY}" | awk '{print $NF}')"
ACCOUNT="$(${CURL} -H "apisign: ${SIGN}" "${APIURL}" | python -mjson.tool 2> /dev/null)"

# check account information success
if echo "${ACCOUNT}" | grep -q \""success\": false"; then
  echo "$(echo "${ACCOUNT}" | grep "\"message\":" | awk -F':' '{print $2}' | sed -e 's/^ "//' -e 's/",$//')"
fi


# get all wallets
if [[ ! -z "${ACCOUNT}" ]]; then
  WALLETS="$(echo "${ACCOUNT}" | grep -E 'Balance|CryptoAddress|Currency' | awk '{print $2}' | sed -e 's/"//g' -e 's/,$//' | tac | tr '\n' ' ' | sed 's/ /\n/3;P;D' | grep -v " 0.0$" | sort)"

else
  echo -e "\nCouldn't access account\n"
  exit 1
fi


# create output file
if [[ ! -a "${OUTFILE}" ]] && [[ ! -f "${OUTFILE}" ]]; then
  touch ${OUTFILE}
fi


# functions
function calc() {
  sed -e 's/[eE]+*/\*10\^/' | bc -l | sed -e 's/^\./0./' -e 's/[0]*$//' -e 's/\.$/.00/'
}
function format() {
  rev | sed "s/.\{3\}/&'/g" | rev | sed "s/^'//"
}
function tochf() {
  COINCALC="$(echo "${CALC} * ${COINS}" | calc)"

  CALCFLL="$(echo "${CALC}" | sed 's/^\./0./' | awk -F'.' '{print $1}' | format)"
  CALCDEC="$(echo "${CALC}" | awk -F'.' '{print $2}')00"
  if [[ "${CALCFLL}" != "0" ]]; then
    CALCROUND="2"
  else
    CALCROUND="4"
  fi

  CHFFLL="$(echo "${COINCALC}" | sed 's/^\./0./' | awk -F'.' '{print $1}' | format)"
  CHFDEC="$(echo "${COINCALC}" | awk -F'.' '{print $2}')00"
  if [[ "${CHFFLL}" != "0" ]]; then
    CHFROUND="2"
  else
    CHFROUND="4"
  fi

  TOTAL+="+${COINCALC}"
  TOTALCALC="$(echo "${TOTAL}" | bc)"
  TOTALCHF="$(echo "${TOTALCALC}" | sed 's/^\./0./' | awk -F'.' '{print $1}' | format)"
  TOTALDEC="$(echo "${TOTALCALC}" | awk -F'.' '{print $2}')00"
  if [[ "${TOTALCHF}" != "0" ]]; then
    TOTALROUND="2"
  else
    TOTALROUND="4"
  fi
}


# calculate all cryptos
TOTAL="0"
printf '%s\n' "$WALLETS" | while IFS= read -r line; do
  RUN="1"
  CRC="$(echo "${line}" | awk '{print $1}')"
  ADDR="$(echo "${line}" | awk '{print $2}')"
  COINS="$(echo "${line}" | awk '{print $3}')"
  COINSHOW="$(echo "${COINS}" | calc)"

  # calculations when currency is not BTC
  if [[ "${CRC}" != "BTC" ]]; then
    CRCPRC="$(${CURL} "https://bittrex.com/api/v1.1/public/getticker?market=BTC-${CRC}" | python -mjson.tool 2> /dev/null)"

    if [[ ! -z "${CRCPRC}" ]]; then
      CRCPRICE="$(echo "${CRCPRC}" | grep "\"Bid\"" | awk '{print $2}' | sed 's/,$//' | calc)"
      CALC="$(echo "${BTC} * ${CRCPRICE}" | calc)"

    else
      RUN="0"
    fi

  else
    CRCPRICE="1"
    CALC="${BTC}"
  fi

  if [[ "${RUN}" == "1" ]]; then
    tochf

    # output
    echo "Currency: ${CRC} > Address: ${ADDR} > Amount: ${COINSHOW} > BTC: ${CRCPRICE} > CHF: ${CALCFLL}.${CALCDEC:0:${CALCROUND}} > Total: ${CHFFLL}.${CHFDEC:0:${CHFROUND}}"

    # output total amount into outfile
    if [[ -f "${OUTFILE}" ]]; then
      echo "${TOTALCHF}.${TOTALDEC:0:${TOTALROUND}}" > ${OUTFILE}
    fi

  else
    echo "Currency: ${CRC} > ERROR!"
  fi
done | column -ets'>'

if [[ -s "${OUTFILE}" ]]; then
  echo -e "\nTotal CHF $(cat ${OUTFILE})"
  rm ${OUTFILE}
fi

exit 0
