#!/bin/bash


#    #   #   #
###     ###  #   ###  ###
# #  #   #   #   # #  # #
###  #   #   ##  ###   ##
                      ###

#
# written by Sean Rütschi
# created on Debian Jessie 8.0
#


# set required variables
ACCOUNTINGDIR="${HOME}/bookkeeping"
MONTHS="13"


# set other variables
COLOR_GRAY="\033[01;30m"
COLOR_GREEN="\033[01;32m"
COLOR_RED="\033[01;31m"
COLOR_WHITE="\033[01;37m"
COLOR_YELLOW="\033[01;33m"
COLOR_NONE="\033[00m"
TERM_WIDTH="$(tput cols)"


# create functions
function print_columns() {
  printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -
}
function help_folder() {
  mkdir ${ACCOUNTINGDIR}
  echo -e "\n${COLOR_RED}No ${ACCOUNTINGDIR} folder available: ${COLOR_GREEN}created.${COLOR_NONE}\n"
}
function help_files() {
  echo -e "\n${COLOR_RED}No financial data available in ${ACCOUNTINGDIR} folder.${COLOR_NONE}"
  echo -e "\nTemplate for files:\n\n${COLOR_YELLOW}DATE\t${COLOR_RED}COSTS\t${COLOR_GREEN}INCOME\t${COLOR_NONE}COMMENT\t-->Variables are seperated by \\\t (tabspace) to ensure correct processing.\n"
}

function month() {
  date --date="-${1} months -$(($(date +%d | sed 's/^0//')-1)) days" '+%Y-%m-'
}
function month_math() {
  echo ${MONTHS}-1 | bc
}


# ensure existence of accounting folder
if [[ ! -d "${ACCOUNTINGDIR}" ]]; then
  help_folder
  print_columns
  help_files
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
  done
  exit 0
fi


# title
echo -e "\n${COLOR_WHITE}SEARCH >\t${TXT}${COLOR_NONE}"
print_columns

# calculate income
INCOMING="$(echo "${ALL}" | awk -F"\t" '{if ($3)print $0}')"
INCOMINGTOTAL="$(echo $(echo "${INCOMING}" | awk '{print $2}') | sed -e 's/[^0-9,. ]*//g' -e 's/ /+/g' | bc)"
if [[ -z "${INCOMING}" ]]; then INCOMING="${COLOR_RED}No gains${COLOR_NONE}"; fi
if [[ -z "${INCOMINGTOTAL}" ]]; then INCOMINGTOTAL="0"; fi

# print income
echo -e "${COLOR_GREEN}${INCOMING}${COLOR_NONE}" | sed 's/\t\t/\t/g'
print_columns


# calculate costs
COSTING="$(echo "${ALL}" | awk -F"\t" '{if ($2)print $0}')"
COSTINGTOTAL="$(echo $(echo "${COSTING}" | awk '{print $2}') | sed -e 's/[^0-9,. ]*//g' -e 's/ /+/g' | bc)"
if [[ -z "${COSTING}" ]]; then COSTING="${COLOR_GREEN}No costs${COLOR_NONE}"; fi
if [[ -z "${COSTINGTOTAL}" ]]; then COSTINGTOTAL="0"; fi

# print costs
echo -e "${COLOR_RED}${COSTING}${COLOR_NONE}" | sed 's/\t\t/\t/g'
print_columns


# set colors for income
if echo ${INCOMINGTOTAL} | grep -q ^0$; then
  COLOR_INCOME="${COLOR_RED}"
else
  COLOR_INCOME="${COLOR_GREEN}"
fi

# set colors for costs
if echo ${COSTINGTOTAL} | grep -q ^0$; then
  COLOR_COSTING="${COLOR_GREEN}"
else
  COLOR_COSTING="${COLOR_RED}"
fi

# calculate difference
DIFF="$(echo ${INCOMINGTOTAL}-${COSTINGTOTAL} | bc)"
TOTALBAR="$(echo "${DIFF}" | sed 's/[^0-9,.]*//g' | wc -m)"
if echo ${DIFF} | grep -q ^\-; then
  COLOR="${COLOR_RED}"
elif echo ${DIFF} | grep -q ^0$; then
  COLOR="${COLOR_YELLOW}+"
else
  COLOR="${COLOR_GREEN}+"
fi

# print comparison
echo -e "GAINS  >\t${COLOR_INCOME}+${INCOMINGTOTAL}${COLOR_NONE}"
echo -e "COSTS  >\t${COLOR_COSTING}-${COSTINGTOTAL}${COLOR_NONE}"
echo -e "TOTAL  >\t${COLOR}${DIFF}${COLOR_NONE}"
printf '\t\t%*s\n\n' "${TOTALBAR}" '' | tr ' ' =


# exit script
exit 0
