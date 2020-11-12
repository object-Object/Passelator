# Passelator

## Dependencies
* [Luvit](https://luvit.io/)
* [Discordia](https://github.com/SinisterRectus/Discordia/)
* [lit-sqlite3](https://github.com/SinisterRectus/lit-sqlite3)

## Installation
I'd prefer if you would just invite my bot to your server using the invite link (this repo's website). However, if you want to run your own version, here's how.
* Download Passelator.
* Install the dependencies.
* Create the `options.lua` file in the bot's main directory, using the template in `templates/`.
* Run `./luvit create-db.lua`.
* Included is a shell script to start the bot using [PM2](https://pm2.keymetrics.io/), or just run `./luvit main.lua`.

## Other info
This bot uses the command framework from [Yot](https://github.com/object-Object/Yot), another one of my projects.