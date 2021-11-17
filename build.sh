#!/bin/bash

docker-compose down -v
docker-compose up -d

until docker-compose exec node1 mysql -uroot -pmypass \
  -e "CREATE USER 'root'@'%' IDENTIFIED BY 'mypass';" \
  -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;" \
  -e "CREATE DATABASE mydb;"
do
    echo "Waiting for mysql_master database connection..."
    sleep 4
done

docker-compose exec node1 mysql -uroot -pmypass \
  -e "SET @@GLOBAL.group_replication_bootstrap_group=1;" \
  -e "create user 'repl'@'%' IDENTIFIED WITH sha256_password BY 'mypass';" \
  -e "GRANT SELECT,REPLICATION SLAVE ON *.* TO repl@'%';" \
  -e "flush privileges;" \
  -e "change master to master_user='root' for channel 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;" \
  -e "SET @@GLOBAL.group_replication_bootstrap_group=0;" \
  -e "SELECT * FROM performance_schema.replication_group_members;"

for N in 2 3
do docker-compose exec node$N mysql -uroot -pmypass \
  -e "change master to master_user='repl', master_password='mypass' for channel 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;"
done
  
docker-compose exec node1 mysql -uroot -pmypass \
  -e "SHOW VARIABLES WHERE Variable_name = 'hostname';" \
  -e "SELECT * FROM performance_schema.replication_group_members;"

# create_user_stmt='CREATE USER IF NOT EXISTS mydb_slave_user@"%" IDENTIFIED BY "mydb_slave_pwd";'
# docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$create_user_stmt'"

# priv_stmt='GRANT REPLICATION SLAVE ON *.* TO mydb_slave_user@"%"; FLUSH PRIVILEGES;'
# docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"

# until docker-compose exec mysql_slave sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
# do
#     echo "Waiting for mysql_slave database connection..."
#     sleep 4
# done

# docker-ip() {
#     docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@"
# }

# MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
# CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
# CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

# start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='mydb_slave_user',MASTER_PASSWORD='mydb_slave_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS;"
# start_slave_cmd='export MYSQL_PWD=111; mysql -u root -e "'
# start_slave_cmd+="$start_slave_stmt"
# start_slave_cmd+='"'
# docker exec mysql_slave sh -c "$start_slave_cmd"

# auth_stmt="mysql -umydb_slave_user -pmydb_slave_pwd -h '$(docker-ip mysql_master)'"
# docker exec mysql_slave sh -c "$auth_stmt"
# docker exec mysql_slave sh -c "exit"

# docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e 'reset slave'"
# docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e 'start slave'"
# docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"

# until docker-compose exec mysql_slave2 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
# do
#     echo "Waiting for mysql_slave2 database connection..."
#     sleep 4
# done

# docker exec mysql_slave2 sh -c "$start_slave_cmd"

# docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'reset slave'"
# docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'start slave'"
# docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"
