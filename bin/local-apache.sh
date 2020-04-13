#!/bin/sh
#
# "Don't use variables in printf format...".
#shellcheck disable=SC2059

LOCAL_APACHE_CONF_DIR=${LOCAL_APACHE_CONF_DIR:-./etc}
LOCAL_APACHE_CONF_NAME=${LOCAL_APACHE_CONF_NAME:-httpd.conf}
#LOCAL_APACHE_SSL_CONF_NAME=${LOCAL_APACHE_SSL_CONF_NAME:-httpd-ssl.conf}

LOCAL_APACHE_IMG=${LOCAL_APACHE_IMG:-httpd:2.4-alpine}
LOCAL_APACHE_KEY=${LOCAL_APACHE_KEY:-$LOCAL_APACHE_CONF_DIR/localhost.key}
LOCAL_APACHE_CRT=${LOCAL_APACHE_CRT:-$LOCAL_APACHE_CONF_DIR/localhost.crt}
LOCAL_APACHE_DOC=${LOCAL_APACHE_DOC:-./docs}

# TODO: Detect if no color is wanted or supported
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'

X='\033[0m'

if [ -d "$LOCAL_APACHE_CONF_DIR" ]; then
  printf "${G}Directory $LOCAL_APACHE_CONF_DIR already exists.${X}\n"
else
  printf "${Y}Creating directory $LOCAL_APACHE_CONF_DIR...${X}\n"
  mkdir -p "$LOCAL_APACHE_CONF_DIR"
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_APACHE_CONF_DIR.  See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

if [ -w "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME" ]; then
  printf "${G}Apache configuration file $LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME already exists.${X}\n"
else
  printf "${Y}Creating Apache configuration file $LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME...${X}\n"
  docker container run --rm "$LOCAL_APACHE_IMG" cat /usr/local/apache2/conf/httpd.conf >"$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME"
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME.  See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

# Not needed.
#if [ -w "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_SSL_CONF_NAME" ]; then
#  printf "${G}Apache SSL configuration file $LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_SSL_CONF_NAME already exists.${X}\n"
#else
#  printf "${Y}Creating Apache SSL configuration file $LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_SSL_CONF_NAME...${X}\n"
#  docker container run --rm "$LOCAL_APACHE_IMG" cat /usr/local/apache2/conf/extra/httpd-ssl.conf >"$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_SSL_CONF_NAME"
#  if [ $? -ne 0 ]; then
#    printf "${R}Failed to create $LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_SSL_CONF_NAME.  See error above.  Exiting.${X}\n"
#    exit 1
#  fi
#fi

GREP="grep -q"

local_apache_enable() {
  message="$1"
  pattern="$2"
  file="$3"

  $GREP -E "^\s*$pattern\s*\$" "$file"
  if [ $? -eq 0 ]; then
    printf "${G}$message already enabled.${X}\n"
  else
    # Couldn't find whether it is enabled. Check it is disabled.
    $GREP -E "^\s*#\s*$pattern\s*\$" "$file"
    if [ $? -eq 0 ]; then
      # It's disabled. Enable it.
      printf "${Y}Enabling $message...${X}\n"
      sed -i '.tmp' -e "s/^\s*#\s*\($pattern\)\s*\$/\1/" "$file"
      if [ -e "$file.tmp" ] ; then
        #diff -u "$file.tmp" "$file"
        rm "$file.tmp"
      fi
      # Check that it succeeded.
      $GREP -E "^$pattern\$" "$file"
      if [ $? -eq 0 ]; then
        # It is now enabled.  Don't say anything.
        true
      else
        printf "${R}Failed to enable $message.  Check the configuration.  Exiting.${X}\n"
        exit 1
      fi
    else
      # Couldn't determine whether it is disabled or enabled.
      printf "${R}Unable to determine the state of $message.  Check the configuration.  Exiting.${X}\n"
      exit 1
    fi
  fi
}

# TODO: Uncomment the ServerName setting, if still in comments
local_apache_enable "ServerName" "ServerName\s*.*www.example.com:80" "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME"

if [ -r "$LOCAL_APACHE_KEY" ] && [ -r "$LOCAL_APACHE_CRT" ]; then
  # Keys given.  Check the three lines that need to be in the configuration.
  local_apache_enable "SSL Configuration" "Include\s*.*httpd-ssl.conf" "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME"
  local_apache_enable "SSL Module" "LoadModule\s*.*mod_ssl.so" "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME"
  local_apache_enable "SSL Cache" "LoadModule\s*.*mod_socache_shmcb.so" "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME"
  local_apache_enable "SSL Redirect Module" "LoadModule\s*.*mod_rewrite.so" "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME"
  cat >>"$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME" <<EOF
<IfModule rewrite_module>
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</IfModule>
EOF
else
  # Keys not given.  Disable the three lines.
  printf "${Y}SSL keys not given.  TODO: Disable SSL.${X}\n"
fi

if [ -r "$LOCAL_APACHE_KEY" ] && [ -r "$LOCAL_APACHE_CRT" ]; then
  key="$(realpath "$LOCAL_APACHE_KEY")"
  crt="$(realpath "$LOCAL_APACHE_CRT")"
  cnf="$(realpath "$LOCAL_APACHE_CONF_DIR/$LOCAL_APACHE_CONF_NAME")"
  app="$(realpath "$LOCAL_APACHE_DOC")"
  docker container run -it --rm \
    -p 80:80 \
    -p 443:443 \
    -v "$key:/usr/local/apache2/conf/server.key:ro" \
    -v "$crt:/usr/local/apache2/conf/server.crt:ro" \
    -v "$cnf:/usr/local/apache2/conf/httpd.conf:ro" \
    -v "$app:/usr/local/apache2/htdocs/:ro" \
    "$LOCAL_APACHE_IMG"
else
  echo "TODO: run apache without SSL"
fi
