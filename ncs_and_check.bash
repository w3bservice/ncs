#!/bin/bash
#
# ncs_and_check.bash
#
# v1.0.0 - 2016-12-13 - Nelbren <nelbren@gmail.com>
#

show_task() {
  echo -ne "\t$1... " 
}

color() {
  echo -en "\e[0m"
  case $1 in
    0) echo -en "\e[30;48;5;82m";; # OK
    1) echo -en "\e[30;48;5;11m";; # WARNING
    2) echo -en "\e[30;48;5;9m";;  # CRITICAL
    9) echo -en "\e[1;37m";;
  esac
}

check_task() {
  r=$1
  if [ "$r" == "0" ]; then
    color 0
    echo -n "[ OK ]"
  else
    if [ -n "$warning" ] ; then
      color 1
    else
      color 2
    fi
    echo -n "[ FAIL! ]"
  fi
  echo -en "\e[0m"
  echo ""
}

check_conf1() {
  show_task "Exist ${conf}"
  if [ -r $conf ]; then
    r=0 
  else
    r=1
  fi
  check_task $r
  if [ "$r" != "0" ]; then
    echo -e "\n\tTry this to fix:\n\n\tcd $base\n\tmv ncs.conf.example ncs.conf\n"
    exit 1
  fi
}

check_bash() {
  bash="#!/bin/bash"
  echo -en "\t${bash} "
  if [ "$line" == "$bash" ]; then
    r=0
  else
    r=1
  fi
  check_task $r
  if [ "$r" != "0" ]; then
    echo -e "\n\tTry this to fix:\n\n\tcd $base\n\techo '$bash'; cat $conf > /tmp/ncs.conf\n\tmv /tmp/ncs.conf ncs.conf\n"
    exit 1
  fi
}

check_param_comun() {
  p=$1
  v=$2
  c=$3
  v1=$4
  v2=$5
  echo -e "\t${p} ="
  echo -en "\t\t${v} "
  case $c in
    choices) if [ "$v" == "$v1" -o "$v" == "$v2" ]; then
               r=0
             else
               r=1
             fi;;
 different) if [ "$v" != "$v1" ]; then
              r=0
            else
              r=1
            fi;;
 directory) if [ -d "$v" ]; then
              r=0
            else
              r=1
            fi;;
executable) if [ -n "$v1" ]; then
              owner=$(stat -c '%U' $v)
              if [ "$owner" == "$v1" ]; then
                r=0
              else
                if [ -x "$v" ]; then
                  r=0
                else
                  r=1
                fi
              fi
            else
              if [ -x "$v" ]; then
                r=0
              else
                r=1
              fi
            fi;;
    socket) if [ -n "$v1" ]; then
              owner=$(stat -c '%U' $v)
              if [ "$owner" == "$v1" ]; then
                r=0
              else
                if [ -S "$v" ]; then
                  r=0
                else
                  r=1
                fi
              fi
            else
              if [ -S "$v" ]; then
                r=0
              else
                r=1
              fi
            fi;;
   special) if [ -c "$v" ]; then
              r=0
            else
              r=1
            fi;;
      read) if [ -r "$v" ]; then
              r=0
            else
              r=1
            fi;;
       mp3) v="$(echo $v | sed "s/\"//g")"
            file=$(file "$v")
            type="MPEG ADTS, layer III, v1, 128 kbps, 44.1 kHz, JntStereo"
            if echo $file | grep -q "$type"; then
              r=0
            else
              r=1
            fi;;
  esac
  check_task $r
}


check_param() {
  l=$1

  p=$(echo $l | cut -d"="  -f1)
  v=$(echo $l | cut -d"="  -f2)
  
  case $p in
    lang) check_param_comun $p "$v" choices "en" "es";;
    name) check_param_comun $p "$v" different "";;
    base) base=$v
          check_param_comun $p "$v" directory;;
    ncs_and_report_to_console) v1=$base/$(basename "$v")
          check_param_comun $p "$v1" executable;;
    ncs_from_local_or_remote) v1=$base/$(basename "$v")
          check_param_comun $p "$v1" executable;;
    live_sock) check_param_comun $p "$v" socket nagios;;
    nagiostats) check_param_comun $p "$v" executable nagios;;
    console) check_param_comun $p "$v" special;;
    mail_background) check_param_comun $p "$v" choices "screen_saver" "terminal";;
    mail_to) check_param_comun $p "$v" different "";;
    mail_from) check_param_comun $p "$v" different "";;
    dir_mp3) dir_mp3=$v
             check_param_comun $p "$v" directory;;
    mp3_ok) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    mp3_warning) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    mp3_critical) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    mp3_unknown) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    domain) check_param_comun $p "$v" different "";;
    server_*_name) check_param_comun $p "$v" different "";;
    server_*_host) check_param_comun $p "$v" different "";;
    server_*_port) check_param_comun $p "$v" different "";;
  esac
}

check_conf2() {
  n=0
  cat $conf | \
  while read line; do
    n=$((n+1)) 
    if [ "$n" == "1" ]; then
      check_bash
    else
      check_param "$line"
    fi
  done
}

check_files1() {
  check_param_comun "ansi2html" "$base/resources/ansi2html.sh" executable
  check_param_comun "send_email.php" "$base/resources/send_email.php" executable
}

check_files2() {
  warning=1
  check_param_comun "mplayer" "/usr/bin/mplayer" executable
  check_param_comun "espeak" "/usr/bin/espeak" executable
  warning=0
}


base=/usr/local/ncs
conf=${base}/ncs.conf

echo -e "\nCONFIGURATION:\n"
check_conf1
check_conf2
echo -e "\nFILES NEEDED:\n"
check_files1
echo -e "\nFILES OPTIOMAL:\n"
check_files2

exit
