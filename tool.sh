. ./common.sh

function install_tool {
     # install bash-completion
     yum install -y bash-completion
     source /etc/profile.d/bash_completion.sh
     echo 'source /etc/profile.d/bash_completion.sh' >> ~/.bashrc
     # install composer
     [ ! -L /usr/local/bin/php ] && (echo "Please install php first..." && exit)
     curl -sS https://getcomposer.org/installer | php
     mv composer.phar /usr/local/bin/composer
     ln -sf /usr/local/bin/php /usr/bin/
}

install_tool
