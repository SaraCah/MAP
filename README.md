Running the MAP
===============

Prerequisites
-------------

  * Java 1.8 or above

  * A MySQL database, created like this:

        create database map character set UTF8mb4 collate utf8mb4_bin;
        grant all on map.* to 'map'@'localhost' identified by 'map123';

  * A recent (8.x.y) NodeJS install

  * A recent (3.x.y) Typescript install (`sudo npm install npm typescript -g`)

Setting up
----------

The MAP system consists of a backend ("api") and a frontend ("ui").
You can set them up like this:

     # Install API dependencies
     $ api/bootstrap.sh

     # Install UI dependencies
     $ ui/bootstrap.sh

Once you have all the pieces, you'll just need a pair of config
files.  For development, they look like this (note that you might need
to adjust the credentials/DB names in the db_url settings):

* `api/config/config.local.rb`

          AppConfig[:db_url] = "jdbc:mysql://localhost:3306/map?useUnicode=true&characterEncoding=UTF-8&user=map&password=map123&serverTimezone=UTC"
          AppConfig[:aspace_db_url] = "jdbc:mysql://localhost:3306/archivesspace?useUnicode=true&characterEncoding=UTF-8&user=as&password=as123&serverTimezone=UTC"

          AppConfig[:session_secret] = "development"
          AppConfig[:development_admin_password] = "admin"

* `ui/config/config.local.rb`

          AppConfig[:session_secret] = "development"


Finally, you can create the necessary DB tables:

     api/scripts/setup_database.sh

Then start the API backend:

    api/scripts/devserver.sh

and the UI frontend:

    ui/scripts/devserver.sh

You should then be able to hit `http://localhost:3456/` in a browser
and log in with `admin/admin`.

