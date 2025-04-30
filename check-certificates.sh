#!/bin/bash

for dir in data/certbot/conf/live/*; do
    resolved_dir=$(readlink -f "$dir")
    domain=$(basename "$resolved_dir") # Extract the domain name from the folder
    echo -e "\n--- $domain ---" # Line with domain name
    echo "Checking resolved path: $resolved_dir"
    if [ -d "$resolved_dir" ]; then
        cert_file="$resolved_dir/cert.pem"
        if [ -f "$cert_file" ]; then
            echo "Checking certificate in $cert_file"
            expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
            expiry_timestamp=$(date -d "$expiry_date" +%s)
            current_timestamp=$(date +%s)
            days_to_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

            # Display the days in color based on expiry
            if [ "$days_to_expiry" -le 30 ]; then
                echo -e "\e[31mDays to expiry: $days_to_expiry\e[0m" # Red for <= 30 days
            else
                echo -e "\e[32mDays to expiry: $days_to_expiry\e[0m" # Green for > 30 days
            fi

            openssl x509 -in "$cert_file" -noout -dates
        else
            echo "No cert.pem found in $resolved_dir"
        fi
    else
        echo "Not a directory: $resolved_dir"
    fi
    echo # Add an extra blank line below each iteration
done
