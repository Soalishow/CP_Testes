# Diretório onde os repositórios serão clonados. Substituir "caminho" pelo caminho real.
REPO_DIR="caminho"

# Repositórios. Atualizar os URLs dos repositórios.
REPO=("URL" "URL")

# Usuário com sudo e sem SSH.
SUDO_USER="usuario_sudo"

# Usuário sem sudo e com SSH.
SSH_USER="usuario_ssh"

# Senha.
SENHA="senha_usuarios"

# Diretório do site no repositório.
SITE_DIR="caminho"

# Diretório do DocumentRoot do Apache (geralmente o caminho padrão é esse de baixo).
APACHE_DOCUMENT_ROOT="/var/www/html"

# Usuários e senhas do Mosquitto (matrizes contendo cada valor das variáveis).
MQTT_USERS=("usuario1" "usuario2")
MQTT_SENHAS=("senha1" "senha2")

# Portas a serem abertas no firewall (matriz contendo as portas).
PORTAS=("...")

# Configurações do MySQL.
MYSQL_ROOT_SENHA="senha_root"
MYSQL_DATABASE="nome_banco"
MYSQL_USER="usuario_mysql"
MYSQL_SENHA="senha_mysql"

# Pacotes do Python a serem instalados.
PYTHON_PACKAGES=("python3" "python3-pip" "python3-matplotlib" "python3-seaborn" "python3-numpy" "python3-mysql.connector" "python3-telegram-bot")

# Atualizando o SO (sempre importante).
sudo apt update
sudo apt upgrade -y




# Função para configurar os usuários.

config_users() {

    # Criando o usuário com sudo.

    sudo adduser --disabled-password --gecos "NOME_SUDO" "$SUDO_USER"
    echo "$SUDO_USER:$SENHA" | sudo chpasswd
    echo "$SUDO_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$SUDO_USER" #Rever isso porque parece errado

    # Criando o usuário sem sudo.

    sudo adduser --disabled-password --gecos "NOME_SSH" "$SSH_USER"
    echo "$SSH_USER:$SENHA" | sudo chpasswd

    # Configurando acesso SSH para o user sem sudo.

    sudo mkdir -p "/home/$SSH_USER/.ssh"
    sudo chmod 700 "/home/$SSH_USER/.ssh"
    sudo touch "/home/$SSH_USER/.ssh/authorized_keys"
    sudo chmod 600 "/home/$SSH_USER/.ssh/authorized_keys"
    echo "Informe a senha SSH pública para o usuário $SSH_USER:"
    read ssh_key
    sudo echo "$ssh_key" | sudo tee "/home/$SSH_USER/.ssh/authorized_keys"
}




# Clonando os repositórios.

for repository in "${REPO[@]}"; do

    git clone "$repository" "$REPO_DIR/$(basename "$repository" .git)"

done




# Função para alterar o DocumentRoot.

config_apache() {

    sudo sed -i "s|DocumentRoot $APACHE_DOCUMENT_ROOT|DocumentRoot $REPO_DIR/$SITE_DIR|" "#/etc/apache2/sites-available/000-default.conf"
    sudo sed -i "s|<Directory $APACHE_DOCUMENT_ROOT>|<Directory $REPO_DIR/$SITE_DIR>|" "#/etc/apache2/sites-available/000-default.conf"
    sudo systemctl restart apache2
}




# Função para configurar o Mosquitto

config_mosquitto() {

    # Criando usuários e senhas do Mosquitto


    sudo touch "/etc/mosquitto/passwd"

    for ((i = 0; i < ${MQTT_USERS[@]}; i++)); do
        nome_usuario="${MQTT_USERS[$i]}"
        senhaMQTT="${MQTT_PASSWORDS[$i]}"
        sudo mosquitto_passwd -b "/etc/mosquitto/passwd" "$nome_usuario" "$senhaMQTT"

    done


    # Reiniciando o serviço do Mosquitto

    sudo systemctl restart mosquitto
}




# Ativando o firewall e abrindo portas necessárias

sudo ufw enable

for porta in "${PORTAS[@]}"; do

    sudo ufw allow "$porta"

done




# Função para instalar o MySQL e criar tabelas

config_mysql() {

    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_SENHA"
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_SENHA"
    sudo apt install -y mysql-server

    # Criando as tabelas no MySQL

    sudo mysql -uroot -p$MYSQL_ROOT_SENHA -e "CREATE DATABASE $MYSQL_DATABASE;"
    sudo mysql -uroot -p$MYSQL_ROOT_SENHA -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_SENHA';"
    sudo mysql -uroot -p$MYSQL_ROOT_SENHA -e "GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'localhost';"
    sudo mysql -uroot -p$MYSQL_ROOT_SENHA -e "FLUSH PRIVILEGES;"
}




# Função para instalar pacotes do Python

python_packages() {

    sudo apt install -y "${PYTHON_PACKAGES[@]}"

}




# Função para configurar o Supervisor

config_supervisor() {

    sudo tee "$SUPER_CONF" > /dev/null << EOF
[program:supervisor]

directory=$REPO_DIR/$SITE_DIR
command=/home/ubuntu/idle.sh
autostart=true
autorestart=true
user=$SSH_USER
redirect_stderr=true
EOF

    sudo supervisorctl reread
    sudo supervisorctl update
}




# Função para criar diretórios para armazenar as imagens

image_direc() {

    sudo mkdir -p "$IMG_DIR"
    sudo mkdir -p "$REPO_DIR/$SITE_DIR/imagens"
    sudo chown -R "$IMG_DIR"
    sudo chown -R "$REPO_DIR/$SITE_DIR/imagens"
    sudo chmod -R 755 "$REPO_DIR/$SITE_DIR"

}




# Executando as tarefas

clone_repositories
config_users
config_apache
config_mosquitto
config_firewall
config_mysql
python_packages
config_supervisor
image_direc