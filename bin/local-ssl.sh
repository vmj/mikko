#!/bin/sh
#
# "Don't use variables in printf format...".
#shellcheck disable=SC2059

LOCAL_SSL_DIR=${LOCAL_SSL_DIR:-./etc}
LOCAL_SSL_ROOT_KEY_NAME=${LOCAL_SSL_ROOT_KEY_NAME:-root-ca.key}
LOCAL_SSL_ROOT_SRL_NAME=${LOCAL_SSL_ROOT_SRL_NAME:-root-ca.srl}
LOCAL_SSL_ROOT_CRT_NAME=${LOCAL_SSL_ROOT_CRT_NAME:-root-ca.crt}
LOCAL_SSL_HOST_KEY_NAME=${LOCAL_SSL_HOST_KEY_NAME:-localhost.key}
LOCAL_SSL_HOST_CSR_NAME=${LOCAL_SSL_HOST_CSR_NAME:-localhost.csr}
LOCAL_SSL_HOST_CRT_NAME=${LOCAL_SSL_HOST_CRT_NAME:-localhost.crt}

# TODO: Detect if no color is wanted or supported
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'

X='\033[0m'

if [ -d "$LOCAL_SSL_DIR" ]; then
  printf "${G}Directory $LOCAL_SSL_DIR already exists.${X}\n"
else
  printf "${Y}Creating directory $LOCAL_SSL_DIR...${X}\n"
  mkdir -p "$LOCAL_SSL_DIR"
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR. See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

if [ -s "$LOCAL_SSL_DIR/server.csr.cnf" ] ; then
  printf "${G}SSL configuration $LOCAL_SSL_DIR/server.csr.cnf already exists.${X}\n"
else
  printf "${Y}Creating SSL configuration $LOCAL_SSL_DIR/server.csr.cnf${X}\n"
  cat >"$LOCAL_SSL_DIR/server.csr.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=US
ST=RandomST
L=RandomL
O=RandomO
OU=RandomOU
emailAddress=you@example.com
CN = www.example.com
EOF
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR/server.csr.cnf. See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

if [ -s "$LOCAL_SSL_DIR/v3.ext" ] ; then
  printf "${G}SSL configuration $LOCAL_SSL_DIR/v3.ext already exists.${X}\n"
else
  printf "${Y}Creating SSL configuration $LOCAL_SSL_DIR/v3.ext${X}\n"
  cat >"$LOCAL_SSL_DIR/v3.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
EOF
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR/v3.ext. See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

if [ -s "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME" ]; then
  printf "${G}RSA private key ($LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME) for the root certificate already exists.${X}\n"
else
  printf "${Y}Creating RSA private key for the root certificate: $LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME${X}\n"
  openssl genrsa -des3 -passout pass:test -out "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME" 2048
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME. See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

if [ -s "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME" ]; then
  printf "${G}Self-signed root certificate $LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME already exists.${X}\n"
else
  printf "${Y}Creating self-signed root certificate $LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME${X}\n"
  openssl req -x509 -sha256 -new -nodes -days 30 -passin pass:test \
    -config "$LOCAL_SSL_DIR/server.csr.cnf" \
    -key "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME" \
    -out "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME"
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME. See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

printf "${R}NOTE:${X} Make sure your system trusts the root certificate.\n"
printf "      * Open Keychain\n"
printf "      * select File -> Import Items...\n"
printf "      * select $LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME\n"
printf "        You should now see the certificate in the Certificates category\n"
printf "      * Double click the imported certificate\n"
printf "      * In Trust section, select 'Always Trust' for 'When using this certificate'\n"

if [ -s "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME" ]; then
  printf "${G}RSA private key ($LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME) for the host certificate already exists.${X}\n"
else
  printf "${Y}Creating RSA private key for the host certificate: $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME${X}\n"
  openssl genrsa -out "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME" 2048
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME. See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

if [ -s "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME" ]; then
  printf "${G}Certificate signing request $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME already exists.${X}\n"
else
  printf "${Y}Creating certificate signing request $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME${X}\n"
  openssl req -sha256 -new -nodes \
    -config "$LOCAL_SSL_DIR/server.csr.cnf" \
    -key "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME" \
    -out "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME"
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME.  See error above.  Exiting.${X}\n"
    exit 1
  fi
fi

#if [ -s "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME" ] && [ -s "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME" ]; then
#  printf "${G}Host certificate key $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME already exists.${X}\n"
#else
#  printf "${Y}Creating host certificate key $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME${X}\n"
#  openssl req -sha256 -new -nodes -newkey rsa:2048 \
#    -config "$LOCAL_SSL_DIR/server.csr.cnf" \
#    -keyout "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME" \
#    -out "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME"
#  if [ $? -ne 0 ]; then
#    printf "${R}Failed to create $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_KEY_NAME.  See error above.  Exiting.${X}\n"
#    exit 1
#  fi
#
#  printf "${Y}Creating host certificate $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME${X}\n"
#  openssl x509 -sha256 -req -days 30 \
#    -CAserial "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_SRL_NAME" -CAcreateserial \
#    -extfile "$LOCAL_SSL_DIR/v3.ext" \
#    -CAkey "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME" \
#    -CA "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME" \
#    -in "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME" \
#    -out "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME"
#  if [ $? -ne 0 ]; then
#    printf "${R}Failed to create $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME.  See error above.  Exiting.${X}\n"
#    exit 1
#  fi
#fi

if [ -s "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME" ]; then
  printf "${G}Host certificate $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME already exists.${X}\n"
else
  printf "${Y}Creating host certificate $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME${X}\n"
  openssl x509 -sha256 -req -days 30 \
    -CAserial "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_SRL_NAME" -CAcreateserial \
    -extfile "$LOCAL_SSL_DIR/v3.ext" \
    -passin pass:test \
    -CAkey "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_KEY_NAME" \
    -CA "$LOCAL_SSL_DIR/$LOCAL_SSL_ROOT_CRT_NAME" \
    -in "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CSR_NAME" \
    -out "$LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME"
  if [ $? -ne 0 ]; then
    printf "${R}Failed to create $LOCAL_SSL_DIR/$LOCAL_SSL_HOST_CRT_NAME.  See error above.  Exiting.${X}\n"
    exit 1
  fi
fi
