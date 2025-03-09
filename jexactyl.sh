#!/bin/bash

generate_password() {
    local length=12
    openssl rand -base64 48 | cut -c1-$length
}

read -p "Do you want to create your own MySQL password? (y/n): " CREATE_OWN_PASSWORD

if [[ "$CREATE_OWN_PASSWORD" == "y" ]]; then
    read -p "Enter MySQL password for the Jexactyl user: " MYSQL_PASSWORD
else
    MYSQL_PASSWORD=$(generate_password)
    echo "Generated MySQL password: $MYSQL_PASSWORD"
    echo "$MYSQL_PASSWORD" > ~/password.txt
    echo "Your generated password has been saved to ~/password.txt"
fi

read -p "Enter your domain name or IP address: " DOMAIN_NAME
read -p "Enter the port for the web server (default is 80): " WEB_PORT
WEB_PORT=${WEB_PORT:-80}

sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common curl
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip php8.1-bcmath php8.1-json
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo apt install -y mysql-server
sudo mysql_secure_installation

sudo mysql -u root -p -e "CREATE DATABASE jexactyl;"
sudo mysql -u root -p -e "CREATE USER 'jexactyl'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON jexactyl.* TO 'jexactyl'@'localhost';"
sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

cd /var/www/
sudo curl -Lo jexactyl.tar.gz https://github.com/Jexactyl/Jexactyl/releases/latest/download/jexactyl.tar.gz
sudo tar -xzvf jexactyl.tar.gz
sudo mv jexactyl/* jexactyl/.htaccess /var/www/jexactyl
sudo chown -R www-data:www-data /var/www/jexactyl
sudo chmod -R 755 /var/www/jexactyl

cd /var/www/jexactyl
sudo composer install --no-dev --optimize-autoloader
sudo cp .env.example .env
sudo php artisan key:generate
sudo sed -i "s/DB_DATABASE=laravel/DB_DATABASE=jexactyl/" .env
sudo sed -i "s/DB_USERNAME=root/DB_USERNAME=jexactyl/" .env
sudo sed -i "s/DB_PASSWORD=/DB_PASSWORD=$MYSQL_PASSWORD/" .env
sudo php artisan migrate --seed --force

sudo apt install -y nginx
cat <<EOL | sudo tee /etc/nginx/sites-available/jexactyl
server {
    listen $WEB_PORT;
    server_name $DOMAIN_NAME;

    root /var/www/jexactyl/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/jexactyl /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d $DOMAIN_NAME

sudo systemctl status certbot.timer || {
    echo "Setting up automatic renewal for SSL certificates."
    echo "0 0 * * * /usr/bin/certbot renew --quiet" | sudo tee -a /etc/crontab
}
echo "Jexactyl installation complete. Access it at https://$DOMAIN_NAME"