#!/bin/bash

echo ""
echo "RUNNING: setup-https.sh -------------------------------------------------- "
echo ""

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
  
  envsubst < data/nginx/template_https.conf >> data/nginx/conf.d/nginx.conf
  echo "" >> data/nginx/conf.d/nginx.conf
done

# Replace placeholders with actual Nginx variables
sed -i 's/__HOST__/$host/g' data/nginx/conf.d/nginx.conf
sed -i 's/__REQUEST_URI__/$request_uri/g' data/nginx/conf.d/nginx.conf
sed -i 's/__HTTP_HOST__/$http_host/g' data/nginx/conf.d/nginx.conf
sed -i 's/__REMOTE_ADDR__/$remote_addr/g' data/nginx/conf.d/nginx.conf
sed -i 's/__PROXY_ADD_X_FORWARDED_FOR__/$proxy_add_x_forwarded_for/g' data/nginx/conf.d/nginx.conf

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