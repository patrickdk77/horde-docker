ARG BASE_IMAGE=docker.patrickdk.com/ubuntubase:20.04
ARG DOCKERIZE_VERSION=v0.6.1
ARG PHP_VERSION=7.4
ARG PHP_ETC_DIR=/etc/php/$PHP_VERSION
ARG PHP_MOD_DIR=/usr/lib/php/20190902



FROM $BASE_IMAGE AS phpbuild
ARG DOCKERIZE_VERSION
ARG PHP_ETC_DIR
ARG PHP_MOD_DIR
ARG PHP_VERSION

COPY php-ext-brotli-0.13.1/ /php-ext-brotli/

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends  \
    php-dev php-curl php-mysql php-odbc php-pear php-sqlite3 php-json php-mbstring php-zip php-gd \
    curl wget git gcc make patch libmcrypt-dev libmcrypt4 \
 && pear channel-discover pear.horde.org \
 && pear update-channels \
 && pecl install lzf \
 && pecl install mcrypt \
 && pecl install horde/horde_lz4 \
 && cd /php-ext-brotli/brotli \
 && make \
 && cd .. \
 && phpize \
 && ./configure \
 && make \
 && make install \
 && mkdir /build \
 && cp $PHP_MOD_DIR/mcrypt.so /build/ \
 && cp $PHP_MOD_DIR/lzf.so /build/ \
 && cp $PHP_MOD_DIR/horde_lz4.so /build/ \
 && cp $PHP_MOD_DIR/brotli.so /build/ \
 && echo 'Build PHP Complete'


FROM $BASE_IMAGE
ARG DOCKERIZE_VERSION
ARG PHP_ETC_DIR
ARG PHP_MOD_DIR
ARG PHP_VERSION
ENV HOME /root

COPY --from=phpbuild /build/*.so $PHP_MOD_DIR/

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apache2 mysql-client gnupg2 openssl \
	patch fonts-ipafont-mincho fonts-ipafont-gothic fonts-arphic-ukai fonts-arphic-uming fonts-nanum \
	php-pear php-mysqlnd php-bcmath php-cli php-fpm php-curl php-gd php-geoip php-gnupg php-imagick php-imap \
	php-intl php-mail php-mbstring php-mysql php-pspell php-tidy php-xml php-soap php-xml-svg php-zip php-xmlrpc \
	php-memcache php-net-sieve php${PHP_VERSION}-opcache libmcrypt4 php-igbinary wget libapache2-mod-xsendfile \
	php-auth-sasl php-net-smtp php-text-captcha php-text-figlet php-text-languagedetect \
	ssl-cert php-pecl-http php-msgpack php-bz2 ttf-dejavu-core php-image-text \
        aspell-en aspell-de aspell-cs aspell-ca aspell-br aspell-bg aspell-ar aspell-af aspell-da aspell-el aspell-eo \
        aspell-es aspell-et aspell-eu aspell-fr aspell-ga aspell-he aspell-hi aspell-hr aspell-hu aspell-hy aspell-id \
        aspell-is aspell-it aspell-lt aspell-lv aspell-nl aspell-no aspell-pl aspell-pt aspell-pt-br aspell-pt-pt \
        aspell-ro aspell-ru aspell-sk aspell-sl aspell-sv aspell-ta aspell-uk aspell-uz aspell \
 && a2enmod proxy_fcgi setenvif actions rewrite socache_shmcb xsendfile ssl headers http2 brotli \
 && a2disconf charset localized-error-pages php${PHP_VERSION}-fpm serve-cgi-bin other-vhosts-access-log security \
 && rm /etc/apache2/mods-enabled/deflate.conf \
 && a2dissite 000-default \
# && a2enconf php${PHP_VERSION}-fpm \
 && pear channel-update pear.php.net \
 && sed -i -r -e 's|(if .)(time.. - .cacheid)|\1\$cacheid \&\& \2|' /usr/share/php/PEAR/REST.php \
 && pear upgrade --force PEAR \
 && apt-get -y install --no-install-recommends --reinstall php-xml \
 && sed -i -r -e 's|(if .)(time.. - .cacheid)|\1\$cacheid \&\& \2|' /usr/share/php/PEAR/REST.php \
 && pear install Net_DNS2 \
 && printf '; configuration for php MCrypt module\n\
; priority=20\n\
extension=mcrypt.so\n\
' > $PHP_ETC_DIR/mods-available/mcrypt.ini \
 && phpenmod mcrypt \
 && printf '; configuration for php LZF module\n\
; priority=20\n\
extension=lzf.so\n\
' > $PHP_ETC_DIR/mods-available/lzf.ini \
 && phpenmod lzf \
 && printf '; configuration for php horde_lz4 module\n\
; priority=20\n\
extension=horde_lz4.so\n\
' > $PHP_ETC_DIR/mods-available/horde_lz4.ini \
 && phpenmod horde_lz4 \
 && printf '; configuration for php brotli module\n\
; priority=20\n\
extension=brotli.so\n\
\n\
brotli.output_compression=1\n\
brotli.output_compression=5\n\
' > $PHP_ETC_DIR/mods-available/brotli.ini \
 && phpenmod brotli \
 && printf '/var/log/apache2/*.log {\n\
	daily\n\
	missingok\n\
	rotate 14\n\
	compress\n\
	delaycompress\n\
	notifempty\n\
	create 640 root adm\n\
	sharedscripts\n\
	postrotate\n\
        	/usr/sbin/apache2ctl -k graceful\n\
	endscript\n\
}\n' > /etc/logrotate.d/apache2 \
 && echo "Removing SUID/GUID programs" \
 && find / -mount -perm /2000 -type f -gid 42 -ls -delete \
 && find / -mount -perm /4000 -type f -ls -delete \
 && apt-get clean \
 && apt-get autoremove -y --purge \
 && rm -f /etc/cron.weekly/fstrim /etc/cron.daily/dpkg /etc/cron.daily/passwd /etc/cron.daily/apt-compat /etc/cron.daily/apt \
 && rm -f /var/lib/apt/lists/*.lz4 /var/lib/apt/lists/*.gz \
 && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* \
 && rm -f /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin \
 && rm -rf /tmp/* /var/tmp/* /usr/share/GeoIP/*

RUN pear install Date_Holidays_USA-0.1.1 Date_Holidays_UNO-0.1.3 Date_Holidays_Ukraine-0.1.2 Date_Holidays_Spain-0.1.4 \
        Date_Holidays_Russia-0.1.0 Date_Holidays_Romania-0.1.2 Date_Holidays_Portugal-0.1.1 Date_Holidays_Norway-0.1.2 \
        Date_Holidays_Netherlands-0.1.4 Date_Holidays_Japan-0.1.3 Date_Holidays_Italy-0.1.1 Date_Holidays_Ireland-0.1.3 \
        Date_Holidays_Iceland-0.1.2 Date_Holidays_Germany-0.1.2 Date_Holidays_France-0.1.0 Date_Holidays_EnglandWales-0.1.5 \
        Date_Holidays_Denmark-0.1.3 Date_Holidays_Czech-0.1.0 Date_Holidays_Brazil-0.1.2 Date_Holidays_Austria-0.1.6 \
        Date_Holidays_Australia-0.2.2 Date_Holidays_Venezuela-0.1.1 Date_Holidays-0.21.8 XML_Serializer-0.21.0 \
        File_Find MDB2 MDB2#mysqli \
 && pear channel-discover pear.nrk.io \
 && pear channel-update pear.nrk.io \
 && pear install nrk/Predis
RUN pear channel-discover pear.horde.org \
 && pear channel-update pear.horde.org \
 && pear install horde/horde_role \
# && pear run-scripts horde/horde_role \
 && pear config-set -c horde horde_dir /usr/share/horde \
 && pear install -o -B horde/horde horde/Horde_Imap_Client horde/Horde_Db horde/Horde_Controller horde/Horde_Core \
        horde/Horde_ActiveSync horde/Horde_Alarm horde/Horde_Auth horde/Horde_Cache horde/Horde_Cli \
        horde/Horde_Compress horde/Horde_Compress_Fast horde/Horde_Crypt horde/Horde_Crypt_Blowfish \
        horde/Horde_CssMinify horde/Horde_Css_Parser horde/Horde_Data horde/Horde_Date horde/Horde_Date_Parser \
        horde/Horde_Dav horde/Horde_Feed horde/Horde_Form horde/Horde_Group horde/Horde_HashTable \
        horde/Horde_History horde/Horde_Http horde/Horde_Icalendar horde/Horde_Idna horde/Horde_Image \
        horde/Horde_Imsp horde/Horde_JavascriptMinify horde/Horde_JavascriptMinify_Jsmin horde/Horde_Lock \
        horde/Horde_Log horde/Horde_LoginTasks horde/Horde_Mail horde/Horde_Mail_Autoconfig \
        horde/Horde_ManageSieve horde/Horde_Mapi horde/Horde_Mime horde/Horde_Mime_Viewer horde/Horde_Nls \
        horde/Horde_Notification horde/Horde_Oauth horde/Horde_Pack horde/Horde_Pdf horde/Horde_Perms \
        horde/Horde_Prefs horde/Horde_Queue horde/Horde_Routes horde/Horde_Rpc horde/Horde_Editor \
        horde/Horde_Scribe horde/Horde_Secret horde/Horde_Serialize horde/Horde_SessionHandler \
        horde/Horde_Share horde/Horde_Smtp horde/Horde_SpellChecker horde/Horde_Support horde/Horde_SyncMl \
        horde/Horde_Template horde/Horde_Text_Diff horde/Horde_Text_Filter horde/Horde_Text_Filter_Jsmin \
        horde/Horde_Text_Flowed horde/Horde_Thrift horde/Horde_Timezone horde/Horde_Token horde/Horde_Translation \
        horde/Horde_Util horde/Horde_Vfs horde/Horde_View horde/Horde_Stringprep horde/Horde_Tree \
        horde/Horde_Stream_Wrapper horde/Horde_Autoloader horde/Horde_Argv \
        horde/gollem horde/imp horde/ingo horde/kronolith horde/mnemo horde/nag horde/passwd horde/timeobjects horde/turba \
# && pear upgrade-all \
 && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
 && tar -C /usr/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
 && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
 && mkdir /etc/horde \
 && mv /usr/share/horde/imp/config /etc/horde/imp \
 && ln -s /etc/horde/imp /usr/share/horde/imp/config \
 && mv /usr/share/horde/nag/config /etc/horde/nag \
 && ln -s /etc/horde/nag /usr/share/horde/nag/config \
 && mv /usr/share/horde/content/config /etc/horde/content \
 && ln -s /etc/horde/content /usr/share/horde/content/config \
 && mv /usr/share/horde/gollem/config /etc/horde/gollem \
 && ln -s /etc/horde/gollem /usr/share/horde/gollem/config \
 && mv /usr/share/horde/passwd/config /etc/horde/passwd \
 && ln -s /etc/horde/passwd /usr/share/horde/passwd/config \
 && mv /usr/share/horde/kronolith/config /etc/horde/kronolith \
 && ln -s /etc/horde/kronolith /usr/share/horde/kronolith/config \
 && mv /usr/share/horde/ingo/config /etc/horde/ingo \
 && ln -s /etc/horde/ingo /usr/share/horde/ingo/config \
 && mv /usr/share/horde/mnemo/config /etc/horde/mnemo \
 && ln -s /etc/horde/mnemo /usr/share/horde/mnemo/config \
 && mv /usr/share/horde/config /etc/horde/horde \
 && ln -s /etc/horde/horde /usr/share/horde/config \
 && mv /usr/share/horde/turba/config /etc/horde/turba \
 && ln -s /etc/horde/turba /usr/share/horde/turba/config \
 && mkdir /var/cache/horde \
 && mv /usr/share/horde/static  /var/cache/horde/static \
 && chown -R www-data:www-data /var/cache/horde/static \
 && ln -s /var/cache/horde/static /usr/share/horde/static \
# && mv /usr/share/horde/js/excanvas ../../javascript/excanvas \
# && ln -s /usr/share/javascript/excanvas /usr/share/horde/js/excanvas \
# && mv /usr/share/horde/js/scriptaculous ../../javascript/scriptaculous \
# && ln -s /usr/share/javascript/scriptaculous /usr/share/horde/js/scriptaculous \
# && mv /usr/share/horde/js/ckeditor ../../javascript/ckeditor3 \
# && ln -s /usr/share/javascript/ckeditor3 /usr/share/horde/js/ckeditor \
# && mv /etc/horde /etc/.horde \
 && echo "Removing SUID/GUID programs" \
 && find / -mount -perm /2000 -type f -gid 42 -ls -delete \
 && find / -mount -perm /4000 -type f -ls -delete \
 && apt-get clean \
 && apt-get autoremove -y --purge \
 && rm -f /etc/cron.weekly/fstrim /etc/cron.daily/dpkg /etc/cron.daily/passwd /etc/cron.daily/apt-compat /etc/cron.daily/apt \
 && rm -f /var/lib/apt/lists/*.lz4 /var/lib/apt/lists/*.gz \
 && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* \
 && rm -f /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin \
 && rm -rf /tmp/* /var/tmp/* /usr/share/GeoIP/*

COPY rootfs/ /

RUN chmod +x /etc/my_init.d/horde-init.sh \
 && mv /etc/.service/* /etc/service/ \
 && rm -rf /etc/.service \
 && chmod +x /etc/service/*/* \
 && a2dissite horde \
 && printf ';optimize php\n\
opcache.enable=1\n\
opcache.memory_consumption=192\n\
opcache.max_accelerated_files=20051\n\
opcache.max_wasted_percentage=10\n\
opcache.validate_timestamps=0\n\
opcache.interned_strings_buffer=32\n\
opcache.fast_shutdown=1\n' > $PHP_ETC_DIR/mods-available/zzz-defaults.ini \
 && phpenmod zzz-defaults \
 && sed -ri -e 's/#?SSLCipherSuite.HIGH.*/SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA/' \
        -e 's/#?SSLHonorCipherOrder .*/SSLHonorCipherOrder on/' /etc/apache2/mods-available/ssl.conf \
 && sed -i -e 's/new Predis.Client.*/new Predis\\Client($redis_params,array("replication" => "sentinel", "service" => "mymaster", "parameters" => $common ))/' /usr/share/php/Horde/Core/Factory/HashTable.php \
 && chmod +x /docker-entrypoint.sh

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/sbin/my_init"]
#VOLUME /etc/.horde
