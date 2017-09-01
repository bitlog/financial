#!/bin/bash


# set variables
TERM_WIDTH="$(tput cols)"
COLUMNS="$(printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -)"


#set functions
function bittrex_call() {
  APIURL="https://bittrex.com/api/v1.1/account/${APITAG}"
  APIKEYTAG="?apikey=${APIKEY}&nonce=$(date '+%s')&currency=${i}"
  SIGN="$(echo -n "${APIURL}${APIKEYTAG}" | openssl sha512 -hmac "${SECRET}" | awk '{print $NF}')"

  # get data
  CALL="$(curl -s --connect-timeout 2 -m 5 -H "apisign: ${SIGN}" "${APIURL}${APIKEYTAG}" | python -mjson.tool 2> /dev/null)"

  # check if success flag true
  if echo "${CALL}" | grep -q "\"success\": true"; then
    echo "${CALL}" | sed -e '1,2d' | head -n -2 | sed 's/^    //'

  else
    echo -en "An error occurred:\n - "
    echo "${CALL}" | grep "\"message\": " | awk -F':' '{print $2}' | sed -e 's/^ "//' -e 's/",$//'
  fi

  # end output
  echo -e "${COLUMNS}"
}
function help_api() {
  echo -e "\n$(basename ${0}) requires an API key and a secret key:\n" >&2
  echo -e " -a APIKEY" >&2
  echo -e " -s SECRETKEY" >&2
  echo -e "\nAPI keys can be acquired at https://bittrex.com/Manage#sectionApi\n" >&2
}
function help_optional() {
  echo -e "\nOptional arguments for $(basename ${0}), require an argument and can be used multiple times:\n" >&2
  echo -e " -c (currency) --> specific currency" >&2
  echo -e " -d (currency) --> deposit addresses" >&2
  echo -e " -h (currency) --> deposit history" >&2
  echo -e " -w (currency) --> withdrawal history" >&2
  echo -e " -z --> this help" >&2
  echo
}


# set switches
while getopts ":a:c:d:h:s:w:z" opt; do
  case ${opt} in
    a)
      APIKEY="${OPTARG}"
      ;;
    c)
      CURRENCY+=" ${OPTARG}"
      ;;
    d)
      DEPOSIT+=" ${OPTARG}"
      ;;
    h)
      DEPOSITHIST+=" ${OPTARG}"
      ;;
    s)
      SECRET="${OPTARG}"
      ;;
    w)
      WITHDRAWALHIST+=" ${OPTARG}"
      ;;
    z)
      help_api
      help_optional
      exit 1
      ;;
    \?)
      echo -e "\nInvalid option: \"-${OPTARG}\"\n" >&2
      exit 1
      ;;
  esac
done


# check if given API
if [[ -z "${APIKEY}" ]] || [[ -z "${SECRET}" ]]; then
  help_api
  help_optional
  exit 1
fi


# start output
echo -e "${COLUMNS}"

if [[ ! -z "${CURRENCY}" ]]; then
  APITAG="getbalance"
  for i in ${CURRENCY}; do
    bittrex_call
  done

elif [[ ! -z "${DEPOSIT}" ]]; then
  APITAG="getdepositaddress"
  for i in ${DEPOSIT}; do
    bittrex_call
  done

elif [[ ! -z "${DEPOSITHIST}" ]]; then
  APITAG="getdeposithistory"
  for i in ${DEPOSITHIST}; do
    bittrex_call
  done

elif [[ ! -z "${WITHDRAWALHIST}" ]]; then
  APITAG="getwithdrawalhistory"
  for i in ${WITHDRAWALHIST}; do
    bittrex_call
  done

else
  APITAG="getbalances"
  bittrex_call
fi


# exit script
exit 0
