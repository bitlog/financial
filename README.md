# Financial

A collection of simple scripts intended for daily usage

1. [accounting.sh](accounting.sh) *Simple accounting script*
   * Manages input/costs in flat files
   * Generates general overview over last months
   * Generates specific overview with search terms
1. [bittrex.sh](bittrex.sh) *Bash script to interact with Bittrex API*
   * Call currency balances, deposit addresses and histories etc
   * For the moment, this script only utilises read only API calls
1. [bittrex-portfolio.sh](bittrex-portfolio.sh) *Bash script to interact with Bittrex API*
   * Get all non-empty wallets from Bittrex
   * Show amount of cryptocurrencies as well as calculate the according CHF worth
1. [currencies.sh](currencies.sh) *Get live currency rates*
   * Get currency conversion rates from multiple API sites using JSON
   * Differentiate between terminals (for example, used by Tmux) and "live terminals" for according output
1. [lunchcheck.sh](lunchcheck.sh) *Get Lunch-Check balance*
   * Get Lunch-Check card balance by adding the card numbers as arguments
