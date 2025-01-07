#!/bin/bash

# * - - Generating nginx conf file

export $(grep -v '^#' .env.nginx | xargs)

# Clear any existing nginx.conf
> data/nginx/conf.d/nginx.conf

for i in {1..20}; do
  site_domain_var="SITE_${i}_DOMAIN"
  site_container_var="SITE_${i}_CONTAINER"
  site_port_var="SITE_${i}_PORT"
  site_port_mapped_var="SITE_${i}_PORT_MAPPED"

  # Check if the site SITE_X_DOMAIN exist
  if [ -z "${!site_domain_var}" ]; then
    break
  fi

  export SITE_DOMAIN="${!site_domain_var}"
  export SITE_CONTAINER="${!site_container_var}"
  export SITE_PORT="${!site_port_var}"
  export SITE_PORT_MAPPED="${!site_port_mapped_var}" 

  # Populate nginx.conf
  echo "# * Website: ${SITE_CONTAINER} - ${SITE_PORT_MAPPED}:${SITE_PORT}" >> data/nginx/conf.d/nginx.conf
  echo "# * ${SITE_DOMAIN}" >> data/nginx/conf.d/nginx.conf
  echo "" >> data/nginx/conf.d/nginx.conf
  
  envsubst < data/nginx/server_block_template.conf >> data/nginx/conf.d/nginx.conf
  echo "" >> data/nginx/conf.d/nginx.conf
done

# Replace placeholders with actual Nginx variables
sed -i 's/__HOST__/$host/g' data/nginx/conf.d/nginx.conf
sed -i 's/__REQUEST_URI__/$request_uri/g' data/nginx/conf.d/nginx.conf
sed -i 's/__HTTP_HOST__/$http_host/g' data/nginx/conf.d/nginx.conf
sed -i 's/__REMOTE_ADDR__/$remote_addr/g' data/nginx/conf.d/nginx.conf
sed -i 's/__PROXY_ADD_X_FORWARDED_FOR__/$proxy_add_x_forwarded_for/g' data/nginx/conf.d/nginx.conf

# * - - Setup nginx

# Check if docker-compose is installed
if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

echo "### Restarting nginx ..."
docker-compose down
docker-compose up --force-recreate -d nginx
echo



# * - - Creating Certificates

# > - Get .env variables

# Load environment variables from .env
if [ -f .env ]; then
  set -a  # Automatically export all variables
  . .env  # Source the .env file
  set +a
else
  echo "Error: .env file not found."
  exit 1
fi

IFS=' ' read -r -a domains <<< "$DOMAINS"
echo "Using the following domains: ${domains[@]}"

rsa_key_size=4096
data_path="./data/certbot"
email="$EMAIL"
staging="$STAGING" # Set to 1, to avoid hitting request limits (developing)

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

# > - Install certificates (loop domains)

# for domain in "${domains[@]}"; do
#   echo "Processing domain: $domain"
#   read -p "Proceed with certificate? (y/N) " decision
#   if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
#     exit
#   fi
  
#   # Create dummy certificate
#   path="/etc/letsencrypt/live/$domain"
#   mkdir -p "$data_path/conf/live/$domain"
# #   docker-compose run --rm --entrypoint "\
# #     openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
# #       -keyout '$path/privkey.pem' \
# #       -out '$path/fullchain.pem' \
# #       -subj '/CN=localhost'" certbot
  
#   # Request the actual certificate
# #   docker-compose run --rm --entrypoint "\
# #     certbot certonly --webroot -w /var/www/certbot \
# #       $staging_arg \
# #       $email_arg \
# #       -d $domain \
# #       --rsa-key-size $rsa_key_size \
# #       --agree-tos \
# #       --force-renewal" certbot
# done

# > - Reload to apply certificates

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
echo

docker ps