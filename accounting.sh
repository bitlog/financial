#!/bin/bash


# set required variables
TERM_WIDTH="$(tput cols)"
COLUMNS="$(printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -)"
MONTHS="13"
ACCOUNTINGDIR="${HOME}/bookkeeping"


# create functions
function help_folder() {
  mkdir ${ACCOUNTINGDIR}
  echo -e "\nNo ${ACCOUNTINGDIR} folder available: created.\n"
}
function help_files() {
  echo -e "\nNo financial data available in ${ACCOUNTINGDIR} folder."
  echo -e "\nTemplate for files:\n\nDATE\tCOSTS\tINCOME\tCOMMENT\t--> Variables are seperated by \\\t (tabspace) to ensure correct processing.\n"
}

function month() {
  date --date="-${1} months -$(($(date +%d | sed 's/^0//')-1)) days" '+%Y-%m-'
}
function month_math() {
  echo ${MONTHS}-1 | bc
}


# ensure existence of accounting folder
if [[ ! -d "${ACCOUNTINGDIR}" ]]; then
  echo -e "\n${COLUMNS}"
  help_folder
  echo "${COLUMNS}"
  help_files
  echo -e "${COLUMNS}\n"
  exit 1
fi

# ensure existence of financial data
if [[ "$(find ${ACCOUNTINGDIR} -type f | wc -l)" -eq "0" ]]; then
  help_files
  exit 1
fi

# determine requested financial data
if [[ -n "${@}" ]]; then
  for i in "${@}"; do
    if [[ "${i}" == "${1}" ]] && [[ -z "${ALL}" ]]; then
      # determine if request is for last X months
      for c in $(seq $(month_math) -1 0); do
        if [[ "${MONTHCHECK}" -ne "1" ]]; then
          MONTHCHECK=0; [[ "${i}" == "$(month ${c})" ]] && MONTHCHECK=1
	fi
      done

      # search requested financial data
      if [[ "${MONTHCHECK}" -eq "1" ]]; then
        ALL="$(find ${ACCOUNTINGDIR} -type f -exec grep -hr -- "^${i}" {} \; | sort -n)"
        TXT="$(echo ${i} | sed 's/-$//')"
      else
        ALL="$(find ${ACCOUNTINGDIR} -type f -exec grep -ihr -F -- "${i}" {} \; | sort -n)"
        TXT="${@}"
      fi

    else
      ALL="$(echo "${ALL}" | grep -i -F -- "${i}")"
    fi
  done

# otherwise request last X months
else
  for i in $(seq $(month_math) -1 0); do
    ${0} $(month ${i})

    # print line breaks to increase visibility
    if [[ "${i}" -ne "0" ]];then
      echo -e "${COLUMNS}\n${COLUMNS}"
    fi
  done
  exit 0
fi


# title
echo -e "\nSEARCH >\t${TXT}\n${COLUMNS}"

# calculate income
INCOMING="$(echo "${ALL}" | awk -F"\t" '{if ($3)print $0}')"
INCOMINGTOTAL="$(echo $(echo "${INCOMING}" | awk '{print $2}') | sed -e 's/[^0-9,. ]*//g' -e 's/ /+/g' | bc)"
if [[ -z "${INCOMING}" ]]; then INCOMING="No gains"; fi
if [[ -z "${INCOMINGTOTAL}" ]]; then INCOMINGTOTAL="0"; fi

# print income
echo -e "${INCOMING}\n${COLUMNS}" | sed 's/\t\t/\t/g'


# calculate costs
COSTING="$(echo "${ALL}" | awk -F"\t" '{if ($2)print $0}')"
COSTINGTOTAL="$(echo $(echo "${COSTING}" | awk '{print $2}') | sed -e 's/[^0-9,. ]*//g' -e 's/ /+/g' | bc)"
if [[ -z "${COSTING}" ]]; then COSTING="No costs"; fi
if [[ -z "${COSTINGTOTAL}" ]]; then COSTINGTOTAL="0"; fi

# print costs
echo -e "${COSTING}\n${COLUMNS}" | sed 's/\t\t/\t/g'


# calculate difference
DIFF="$(echo ${INCOMINGTOTAL}-${COSTINGTOTAL} | bc)"
TOTALBAR="$(echo "${DIFF}" | sed 's/[^0-9,.]*//g' | wc -m)"
if ! echo ${DIFF} | grep -q ^\-; then
  SIGN="+"
fi

# print comparison
echo -e "GAINS  >\t+${INCOMINGTOTAL}"
echo -e "COSTS  >\t-${COSTINGTOTAL}"
echo -e "TOTAL  >\t${SIGN}${DIFF}"
printf '\t\t%*s\n\n' "${TOTALBAR}" '' | tr ' ' =


# exit script
exit 0
