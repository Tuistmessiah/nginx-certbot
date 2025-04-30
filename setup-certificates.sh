#!/bin/bash

# TODO: Add option on start to set if it is dry-run or production
# TODO: .env variable to add new certificate and loop those while maintaining the rest (to generate final nginx/conf)
# ! Probably have an array for this script and another to generate the nginx.conf in the https script. By default it should autoamtically skip existing certificates.
# TODO: organize domain names in .env vertically?

echo
echo "RUNNING: setup-certificates.sh -------------------------------------------------- "
echo

echo "This script reads '.env' and will attempt to install a certificate for each listed domain. It restarts 'nginx' container."

echo
echo " ------------------------------ -------------------------------------------------- "
echo

# * - - Creating Certificates

# Load environment variables from .env
if [ -f .env ]; then
  set -a  # Automatically export all variables
  . .env  # Source the .env file
  set +a
else
  echo "Error: .env file not found."
  exit 1
fi

IFS=' ' read -ra domains <<< "$DOMAINS"
echo "Using the following domains: ${domains[@]}"

rsa_key_size=4096
data_path="./data/certbot"
email="$EMAIL"
staging="$STAGING" # Set to 1, to avoid hitting request limits (developing)

if [ -d "$data_path" ]; then
  read -p "Existing folder /data/certbot found. Would advise to eliminate existing certificates folder. Continue and replace existing certificates? (y/N)" decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ "$staging" -eq 1 ]; then
  staging_arg="--staging"
else
  staging_arg=""
fi

mkdir -p ./data/certbot/www/.well-known/acme-challenge

echo "### Restarting nginx ..."
docker-compose restart nginx
echo

echo
echo " - Install certificates"
echo

# > - Install certificates (loop domains)

for domain in "${domains[@]}"; do
  echo "Processing domain: $domain"

#   // Ask per site if we want a certificate
#   read -p "Proceed with certificate? (y/N) " decision
#   if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
#     continue
#   fi
#   // Create dummy certificate before no longer needed?
# Create dummy certificate
#   path="/etc/letsencrypt/live/$domain"
#   mkdir -p "$data_path/conf/live/$domain"
#   docker-compose run --rm --entrypoint "\
#     openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
#       -keyout '$path/privkey.pem' \
#       -out '$path/fullchain.pem' \
#       -subj '/CN=localhost'" certbot
  
#   echo "### Restarting nginx ..."
#   docker-compose restart nginx
#   echo


  # Request the actual certificate
  docker-compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      --email $email \
      -d $domain \
      --rsa-key-size $rsa_key_size \
      --agree-tos \
      " certbot
    #   --dry-run (same as staging but doesnt save certificates, to simulate without issuing)
    #   --force-renewal (force issuing even if current one is valid) \ 
  echo
done

echo "### Restarting nginx ..."
docker-compose restart nginx
echo
