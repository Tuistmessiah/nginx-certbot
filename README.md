# Boilerplate for nginx with Let’s Encrypt on docker-compose

> This repository is forked from [nginx-certbot](https://github.com/wmnnd/nginx-certbot). There is a [step-by-step guide on how to
set up nginx and Let’s Encrypt with Docker](https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71). The initial author is `github.com/wmnnd/`. Changes were made to eb able to setup certificates and nginx configs for multiple static websites at the same time.

`init-letsencrypt.sh` fetches and ensures the renewal of a Let’s
Encrypt certificate for one or multiple domains in a docker-compose
setup with nginx.
This is useful when you need to set up nginx as a reverse proxy for an
application.

## Installation & Configuration
1. [Install docker-compose](https://docs.docker.com/compose/install/#install-compose).

2. Clone this repository

3. Modify configuration:
- In `/env` add email for certificates and list of domains, separated by space `' '`:
    ```
    DOMAINS="example1.org www.example1.org example2.org www.example2.org"
    EMAIL="my-email@gmail.com"
    STAGING=0
    ```
-   `STAGING=0` is for production environment while `STAGING=1` is used for testing. 
- In `.env.nginx` add configs of your site. The domain it will have, the name of the docker container it will be in, alongside the internal port it is mapped and the external port mapped to the host machine. A max of 20 sites can be listed here:
    ```
    SITE_1_DOMAIN="example1.org"
    SITE_1_CONTAINER="example-1"
    SITE_1_PORT="3000"
    SITE_1_PORT_MAPPED="5173"

    SITE_2_DOMAIN="example2.org"
    SITE_2_CONTAINER="example-2"
    SITE_2_PORT="3000"
    SITE_2_PORT_MAPPED="5151"
    ```

4. Run the npm script:

        npm run server

## How it works

When running `npm run serve` it runs all three scripts by order.

 - First script, `setup-http.sh`
   - takes `.env.nginx` loops it to generate the first `.../conf.d/nginx.conf`
   - starts the `nginx` container
 - Second script, `setup-certificates.sh`
   - takes `.env` loops it to install certificates (asks y/n for each overwrite)
   - runs, temporarily the `certbot` container just to install certificates (they are saved in the mapped folder `/certbot`)
 - Third script, `setup-https.sh`
   - takes `.env.nginx` and re-writes `.../conf.d/nginx.conf` for https
   - restarts the `nginx` container



## Add more websites

First, check if websites are running in their respective PORT. Check also registry in `~/CODE_BREEZE`, where PORT usage is listed. Any website project should have it's own folder in `~/` and run `npm run serve` (having the appropriate `serve.sh` in each to make sure they share the same docker network)

1. Run `npm run serve`
2. Check `docker ps`
3. Check `http://<IP>:<PORT>`
4. Add custom domains to `/.env` and to `.env.nginx` and run `npm run server`.
5. Check working custom domains

## Troubleshoot

To check the status of a certificate: `openssl x509 -in ./data/certbot/conf/live/<domain>/fullchain.pem -text -noout`.
Check `docker logs nginx` to check why the nginx container didn't work (it may restart itself indefinitely)