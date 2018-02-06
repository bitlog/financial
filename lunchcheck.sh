#!/bin/bash

# check parameters
if [[ -z "${@}" ]]; then
  ERROR="require at least one parameter (card number)"

elif echo "${@}" | grep -q "[^0-9 ]"; then
  ERROR="non numeric characters entered"
fi

# output errors
if [[ ! -z "${ERROR}" ]]; then
  echo -e "\n$(basename ${0}) error: ${ERROR}\n"
  exit 1
fi


# set variables
OUTPUT="Error"
TOTAL=""
OUTFILE="/tmp/$(basename ${0})"


# set system variables
CURL="curl -s --connect-timeout 2 -m 5 --write-out \n\n%{http_code}"
SECS="$(date '+%S')"


# get lunch check
if tty -s || [[ "${SECS}" == "15" ]] || [[ "${SECS}" == "45" ]]; then
  for i in $(echo "${@}" | tr ' ' '\n' | sort -u); do
    COUNTER="0"
    SALDO=""
    until [[ ! -z "${SALDO}" ]] || [[ "${COUNTER}" -gt "3" ]]; do
      ((COUNTER++))
      CALL="$(${CURL} "https://www.lunch-card.ch/saldo/saldo.aspx?crd=${i}")"
      sleep 0.5

      if echo "${CALL}" | tail -1 | grep -q "^200$"; then
        SALDO="$(echo "${CALL}" | grep "SheetContentPlaceHolder_ctl00_ctl01_lblBalance" | sed -e 's/<[^>]*>//g' | grep -Eo '[0-9.]{1,}')"
        if [[ ! -z "${SALDO}" ]]; then
          CALC+="${SALDO} + "
        fi
      fi
    done
  done

  if [[ ! -z "${CALC}" ]]; then
    TTL="$(echo "${CALC} 0" | bc)"
    TOTAL="$(echo "${TTL}" | awk -F'.' '{print $1}' | rev | sed "s/.\{3\}/&'/g" | rev | sed "s/^'//")"
    if [[ -z "${TOTAL}" ]]; then
      TOTAL="0"
    fi
    PART="$(echo "${TTL}" | awk -F'.' '{print $2}')00"
    TOTAL="${TOTAL}.${PART:0:2}"

    echo "${TOTAL} CHF" > ${OUTFILE}
  fi
fi


# output
if [[ -s "${OUTFILE}" ]]; then
  OUTPUT="$(cat ${OUTFILE})"
fi

# check for missing terminal aka tmux line
if ! tty -s; then
  echo -n " | Lunch: "
fi

# show total
echo "${OUTPUT}"

exit 0
