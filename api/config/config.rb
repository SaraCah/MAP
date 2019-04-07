# create database map character set UTF8mb4 collate utf8mb4_bin;
# grant all on map.* to 'map'@'localhost' identified by 'map123';

AppConfig[:db_url] = "jdbc:mysql://localhost:3306/map?useUnicode=true&characterEncoding=UTF-8&user=map&password=map123&serverTimezone=UTC"
