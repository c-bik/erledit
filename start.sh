#!/bin/bash
unamestr=`uname`
if [[ "$unamestr" == 'Linux' || "$unamestr" == 'Darwin' ]]; then
     exename=erl
else
    exename='start //MAX werl.exe'
    #exename='erl.exe'
fi

# Node name
node_name="-name erledit@127.0.0.1"

# Cookie
cookie="-setcookie erledit_cookie"

# PATHS
paths="-pa"
paths=$paths" _build/default/lib/*/ebin"

# sasl opts
sasl_opts="-sasl"
sasl_opts=$sasl_opts" sasl_error_logger false" 

start_opts="$paths $cookie $node_name $sasl_opts"

# DDERL start options
echo "------------------------------------------"
echo "Starting ERLEDIT (Opts)"
echo "------------------------------------------"
echo "Node Name : $node_name"
echo "Cookie    : $cookie"
echo "EBIN Path : $paths"
echo "SASL      : $sasl_opts"
echo "------------------------------------------"

# Starting dderl
$exename $start_opts -s erledit