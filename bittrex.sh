#!/bin/bash


# set variables
COLOR_GREEN="\033[01;32m"
COLOR_RED="\033[01;31m"
COLOR_NONE="\033[00m"


#set functions
function bittrex_call() {
  # start output
  echo

  # check apicall string
  if [[ -z "${APICALL}" ]]; then
    APICALL="currency"
  fi

  # get required input
  if [[ -z "${NOINPUT}" ]] && [[ -z "${QUIET}" ]]; then
    read_input
  fi

  # combine apicall string and given input
  if [[ ! -z "${BTINPUT}" ]]; then
    CRCY="&${APICALL}=${BTINPUT}"
  fi

  APIURL="https://bittrex.com/api/v1.1/account/${APITAG}"
  APIKEYTAG="?apikey=${APIKEY}&nonce=$(date '+%s')${CRCY}"
  SIGN="$(echo -n "${APIURL}${APIKEYTAG}" | openssl sha512 -hmac "${SECRETKEY}" | awk '{print $NF}')"

  TMOUT="2"
  TMOUTMAX="5"
  TMOUTMSG="Connection timed out after ${TMOUT} to ${TMOUTMAX} seconds!"

  # get data
  CALL="$(curl -s --connect-timeout ${TMOUT} -m ${TMOUTMAX} -H "apisign: ${SIGN}" "${APIURL}${APIKEYTAG}" || echo -e "${TMOUTMSG}")"
  DATA="$(echo "${CALL}" | python -mjson.tool 2> /dev/null)"

  # check if success flag true
  if echo "${DATA}" | grep -q "\"success\": true"; then
    echo -e "${COLOR_GREEN}$(echo "${DATA}" | sed -e '1,2d' | head -n -2 | sed 's/^    //')${COLOR_NONE}"

  elif echo "${DATA}" | grep -q "${TMOUTMSG}"; then
    echo "${COLOR_RED}${TMOUTMSG}${COLOR_NONE}"

  else
    echo -en "An error occurred: "
    echo -e "${COLOR_RED}$(echo "${DATA}" | grep "\"message\":" | awk -F':' '{print $2}' | sed -e 's/^ "//' -e 's/",$//')${COLOR_NONE}"
  fi
  echo

  # set run flag
  BTRUN="1"
}
function help_api() {
  echo -e "\n$(basename ${0}) requires an API key and a secret key:\n" >&2
  echo -e " -k APIKEY" >&2
  echo -e " -s SECRETKEY" >&2
  echo -e "\nAPI keys can be acquired at https://bittrex.com/Manage#sectionApi\n" >&2
}
function help_optional() {
  echo -e "\nOptional arguments for $(basename ${0}), require an argument and can be used multiple times:\n" >&2

  OPTHELP+=" -a : addresses for deposits on Bittrex\n"
  OPTHELP+=" -b : balance of all currencies\n"
  OPTHELP+=" -c : balance of specific currency\n"
  OPTHELP+=" -d : deposit history\n"
  OPTHELP+=" -h : order history\n"
  OPTHELP+=" -w : withdrawal history\n"
  OPTHELP+="\n -q : quiet mode, don't ask for input\n"
  echo -e "${OPTHELP}" | column -ets':'
  exit 1
}
function read_input(){
  echo -n "Choose ${APICALL}: "
  read BTINPUT
  echo
}


# set switches
while getopts ":qk:s:abcdhow" opt; do
  case ${opt} in
    q)
      QUIET="1"
      ;;

    k)
      APIKEY="${OPTARG}"
      ;;
    s)
      SECRETKEY="${OPTARG}"
      ;;

    a)
      DEPOSIT="1"
      ;;
    b)
      BALANCES="1"
      ;;
    c)
      CURRENCY="1"
      ;;
    d)
      DEPOSITHIST="1"
      ;;
    h)
      ORDERHIST="1"
      ;;
    o)
      ORDER="1"
      ;;
    w)
      WITHDRAWALHIST="1"
      ;;
    \?)
      echo -e "\nInvalid option: \"-${OPTARG}\"\n" >&2
      help_api
      help_optional
      ;;
  esac
done


# check if given API
if [[ -z "${APIKEY}" ]] || [[ -z "${SECRETKEY}" ]]; then
  help_api
  help_optional
fi


if [[ ! -z "${BALANCES}" ]]; then
  APITAG="getbalances"
  NOINPUT="1"
  bittrex_call

elif [[ ! -z "${CURRENCY}" ]]; then
  APITAG="getbalance"
  bittrex_call

elif [[ ! -z "${DEPOSIT}" ]]; then
  APITAG="getdepositaddress"
  bittrex_call

elif [[ ! -z "${DEPOSITHIST}" ]]; then
  APITAG="getdeposithistory"
  bittrex_call

elif [[ ! -z "${ORDER}" ]]; then
  APITAG="getorder"
  APICALL="order"
  bittrex_call

elif [[ ! -z "${ORDERHIST}" ]]; then
  APITAG="getorderhistory"
  APICALL="market"
  bittrex_call

elif [[ ! -z "${WITHDRAWALHIST}" ]]; then
  APITAG="getwithdrawalhistory"
  bittrex_call
fi

if [[ -z "${BTRUN}" ]]; then
  help_optional
fi

exit 0
