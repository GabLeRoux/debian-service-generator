#!/usr/bin/env bash

SERVICE_FILE=$(mktemp)

prompt() {
  local VAL=""
  if [ "$3" = "" ]; then
    while [ "$VAL" = "" ]; do
      echo -n "${2:-$1} : "
      read VAL
      if [ "$VAL" = "" ]; then
        echo "Please provide a value"
      fi
    done
  else
    VAL=${@:3:($#-2)}
  fi
  VAL=$(printf '%s' "$VAL")
  eval $1=$VAL
}

prompt_token() {
  local VAL=""
  if [ "$3" = "" ]; then
    while [ "$VAL" = "" ]; do
      echo -n "${2:-$1} : "
      read VAL
      if [ "$VAL" = "" ]; then
        echo "Please provide a value"
      fi
    done
  else
    VAL=${@:3:($#-2)}
  fi
  VAL=$(printf '%s' "$VAL")
  eval $1=$VAL
  local rstr=$(printf '%q' "$VAL")
  # escape search string for sed
  # http://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern
  rstr=$(echo $rstr | sed -e 's/[\/&]/\\&/g')
  sed -i "s/<$1>/$rstr/g" $SERVICE_FILE
}

prompt 'OS' 'Os (debian|centos)' $1

if [ ! -e service.$OS.sh ]; then
  echo "--- Download $OS init script template ---"
  echo "I'll now download the service.$OS.sh"
  echo "..."
  wget -q https://raw.githubusercontent.com/gableroux/$OS-service-generator/master/service.$OS.sh
  if [ "$?" != 0 ]; then
    echo "I could not download the template!"
    echo "You should now download the service.$OS.sh file manualy. Run therefore:"
    echo "wget https://raw.githubusercontent.com/gableroux/$OS-service-generator/master/service.$OS.sh"
    exit 1
  else
    echo "I downloaded the template successfully"
    echo ""
  fi
fi

echo "--- Copy template ---"
cp service.$OS.sh "$SERVICE_FILE"
chmod +x "$SERVICE_FILE"
echo ""

echo "--- Customize ---"
echo "I'll now ask you some information to customize script"
echo "Press Ctrl+C anytime to abort."
echo "Empty values are not accepted."
echo ""

prompt_token 'NAME'        'Service name' $2

if [ -f "/etc/init.d/$NAME" ]; then
  echo "Error: service '$NAME' already exists"
  exit 1
fi

prompt_token 'DESCRIPTION' ' Description' $3
prompt_token 'COMMAND'     '     Command' $4
prompt_token 'USERNAME'    '        User' $5
if ! id -u "$USERNAME" &> /dev/null; then
  echo "Error: user '$USERNAME' not found"
  exit 1
fi

echo ""

echo "--- Installation ---"

if [ "$OS" = "debian" ]; then
  if [ ! -w /etc/init.d ]; then
    echo "You didn't give me enough permissions to install service myself."
    echo "That's smart, always be really cautious with third-party shell scripts!"
    echo "You should now type those commands as superuser to install and run your service:"
    echo ""
    echo "   mv \"$SERVICE_FILE\" \"/etc/init.d/$NAME\""
    echo "   touch \"/var/log/$NAME.log\" && chown \"$USERNAME\" \"/var/log/$NAME.log\""
    echo "   update-rc.d \"$NAME\" defaults"
    echo "   service \"$NAME\" start"
  else
    set -x
    mv -v "$SERVICE_FILE" "/etc/init.d/$NAME"
    touch "/var/log/$NAME.log" && chown "$USERNAME" "/var/log/$NAME.log"
    update-rc.d "$NAME" defaults
    service "$NAME" start
    set +x
  fi
else
  if [ ! -w /etc/init.d ]; then
    echo "You didn't give me enough permissions to install service myself."
    echo "That's smart, always be really cautious with third-party shell scripts!"
    echo "You should now type those commands as superuser to install and run your service:"
    echo ""
    echo "   mv \"$SERVICE_FILE\" \"/etc/init.d/$NAME\""
    echo "   touch \"/var/log/$NAME.log\" && chown \"$USERNAME\" \"/var/log/$NAME.log\""
    echo "   chkconfig --add $NAME"
    echo "   service \"$NAME\" start"
  else
    set -x
    mv -v "$SERVICE_FILE" "/etc/init.d/$NAME"
    touch "/var/log/$NAME.log" && chown "$USERNAME" "/var/log/$NAME.log"
    chkconfig --add $NAME
    service "$NAME" start
    set +x
  fi
fi

echo ""
echo "---Uninstall instructions ---"
echo "The service can uninstall itself:"
echo "    service \"$NAME\" uninstall"
echo "It will simply run update-rc.d -f \"$NAME\" remove && rm -f \"/etc/init.d/$NAME\""
echo ""
echo "--- Terminated ---"