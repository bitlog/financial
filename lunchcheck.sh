#!/bin/bash


# check for arguments
if [[ -z "${@}" ]]; then
  echo -e "\n$(basename ${0}) is a script to show the current balance of a given Lunch-Check card.\n"
  exit 1
fi


# set variables to check cards against
REGEX="^[0-9]+$"
CARDS="$(echo "${@}" | tr ' ' '\n' | sort | uniq)"

# run through checks
for i in ${CARDS}; do
  if ! [[ "${i}" =~ ${REGEX} ]] ; then
    echo -e "${i} is not a number!"
    exit 1

  else
    SALDO="$(curl -s "https://www.lunch-card.ch/saldo/saldo.aspx?crd=${i}" | grep "SheetContentPlaceHolder_ctl00_ctl01_lblBalance" | sed -e 's/<[^>]*>//g' -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
    echo -e "Card ${i}: ${SALDO}"
  fi
done

exit 0
