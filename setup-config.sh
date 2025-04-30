#!/bin/bash

echo
echo "RUNNING: setup-config.sh -------------------------------------------------- "
echo

echo "This script reads '.env.nginx', loops the sites, re-builds the 'nginx/config' and restarts 'nginx' container."
echo "Each server name config can either be 'http' or 'https'"

echo
echo " ----------------------- -------------------------------------------------- "
echo

# * - - Generating nginx conf file

# Menu for choosing setup type
echo "Choose setup type:"
echo "1) HTTPS"
echo "2) HTTP"
echo "3) CUSTOM"
read -p "Enter your choice [1-3]: " choice

case $choice in
  1) setup_type="https" ;;
  2) setup_type="http" ;;
  3) setup_type="custom" ;;
  *) echo "Invalid choice. Exiting." ; exit 1 ;;
esac

# Load environment variables from ".env.nginx "
export $(grep -v '^#' .env.nginx | xargs)

# Clear any existing nginx.conf
> data/nginx/conf.d/nginx.conf

echo " - Generating config: data/nginx/conf.d/nginx.conf"
echo

for i in {1..20}; do
  site_domain_var="SITE_${i}_DOMAIN"
  site_container_var="SITE_${i}_CONTAINER"
  site_port_var="SITE_${i}_PORT"
  site_port_mapped_var="SITE_${i}_PORT_MAPPED"
  site_http_only_var="SITE_${i}_USE_ONLY_HTTP"

  # Check if the site SITE_X_DOMAIN exist (finish loop)
  if [ -z "${!site_domain_var}" ]; then
    break
  fi

  export SITE_DOMAIN="${!site_domain_var}"
  export SITE_CONTAINER="${!site_container_var}"
  export SITE_PORT="${!site_port_var}"
  export SITE_PORT_MAPPED="${!site_port_mapped_var}" 
  export SITE_USE_ONLY_HTTP="${!site_http_only_var:-false}" # Default to "false"

  # Populate nginx.conf
  echo "# * Website: ${SITE_CONTAINER} - ${SITE_PORT_MAPPED}:${SITE_PORT}" >> data/nginx/conf.d/nginx.conf
  echo "# * ${SITE_DOMAIN}" >> data/nginx/conf.d/nginx.conf
  echo "" >> data/nginx/conf.d/nginx.conf
  
  # Decide which template to use based on setup type and SITE_USE_ONLY_HTTP
  if [ "$setup_type" = "http" ] || [ "$SITE_USE_ONLY_HTTP" = "true" ]; then
    echo "Generating HTTP config for ${SITE_DOMAIN}..."
    envsubst < data/nginx/template_http.conf >> data/nginx/conf.d/nginx.conf
  else
    echo "Generating HTTPS config for ${SITE_DOMAIN}..."
    envsubst < data/nginx/template_https.conf >> data/nginx/conf.d/nginx.conf
  fi

  echo "" >> data/nginx/conf.d/nginx.conf
done

# Replace placeholders with actual Nginx variables
sed -i 's/__HOST__/$host/g' data/nginx/conf.d/nginx.conf
sed -i 's/__REQUEST_URI__/$request_uri/g' data/nginx/conf.d/nginx.conf
sed -i 's/__HTTP_HOST__/$http_host/g' data/nginx/conf.d/nginx.conf
sed -i 's/__REMOTE_ADDR__/$remote_addr/g' data/nginx/conf.d/nginx.conf
sed -i 's/__PROXY_ADD_X_FORWARDED_FOR__/$proxy_add_x_forwarded_for/g' data/nginx/conf.d/nginx.conf
sed -i 's/__SCHEME__/$scheme/g' data/nginx/conf.d/nginx.conf
sed -i 's/__HTTP_UPGRADE__/$http_upgrade/g' data/nginx/conf.d/nginx.conf

# * - - Setup nginx & reload it

# Check if docker-compose is installed
if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

echo "### Restarting nginx ..."
docker-compose down
docker-compose up --force-recreate -d nginx
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
echo

docker ps