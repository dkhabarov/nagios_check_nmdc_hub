# nagios_check_nmdc_hub
Контроль доступности NMDC хабов в системе мониторинга Nagios


 Плагин проверки работоспособности/доступности NMDC хабов для системы мониторинга Nagios. Работает по такому-же принципу, как и хаблисты.
В качестве пингера используется NMDC Hubs Pinger, который ранее выкладывал alex82.


В дебиане ставим всё нужное:
```shell
sudo apt-get -y install lua5.1 liblua5.1-socket2 liblua5.1-md5-0
```

md5 библиотека тут нужна только для того, что если вы совсем параноик, вы можете проверять md5 имени хаба. laughing.gif зачем это нужно, думайте сами.
Итак, собственно забираем плагин:
```shell
git clone https://bitbucket.org/Saymon21/nagios_check_nmdc_hub.git && cd nagios_check_nmdc_hub
```
Копируем плагин в директорию с плагинами, и устанавливаем права на исполнение.
```
cp check_nmdc.lua /usr/lib/nagios/plugins/check_nmdc.lua
chmod +x /usr/lib/nagios/plugins/check_nmdc.lua
```
Пингер я так-же приложил в наш репозиторий. Надеюсь его автор будет не против.
Копируем его куда надо:
```
cp pinger.lua /usr/share/lua/5.1/nmdc_pinger.lua
```
Теперь создаём конфиг-файл для комады проверки:
```
touch /etc/nagios-plugins/config/nmdc.cfg
```
И записываем в него:
```
define command {
    command_name check_nmdc
    command_line /usr/lib/nagios/plugins/check_nmdc.lua --addr='$HOSTADDRESS$'
}
```
Теперь осталось определить проверку сервиса, перезапустить nagios, и радоваться.

```
define service {
        contacts                root
        use                     generic-service
        host_name               mydc.ru
        service_description     PtokaX
        check_command           check_nmdc
}

```
```
sudo /etc/init.d/nagios3 restart
```


Из дополнительных фич:
По умолчанию для пингера установлен ник nmdcnagios. Изменить можно добавив аргумент `--nick='желаемый ник'`, если он зарегистрирован, добавляем параметр --password='пароль_для_ника'.
Установка шары для бота производится через параметр `--sharesize='размер'`. Например, чтобы установить шару 50 ГБ надо указать `--sharesize=50GB`
Использование Nagios Performance Data указываем параметр `--perfdata` (Не протестировано)
Alert warning if users >= COUNT - `--usersmaxwarn=num`
Alert critical if users >= COUNT - `--usersmaxcritical=num`
Проверка MD5 имени хаба: `--expecthubname='Ожидаемое имя хаба'`
На случай случайно-занятого ника есть параметр `--randomnick`, который в конец ника позволит добавить случайное число от 1 до 33.
Проверка хаба, который на порту != 411 `--port=номер_порта `
