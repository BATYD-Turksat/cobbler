#MESSAGESPOT=po/messages.pot

TOP_DIR:=$(shell pwd)

prefix=devinstall
statepath=/tmp/cobbler_settings/$(prefix)

all: clean build

clean:
	-rm -rf build rpm-build
	-rm -f *~
	-rm -f cobbler/*.pyc
	-rm -rf dist
	-rm -rf buildiso
	-rm -f MANIFEST
	-rm -f koan/*.pyc
	-rm -f config/version
	-rm -f docs/*.1.gz 
	-rm -f *.tmp
	-rm -f *.log

test:
	make savestate prefix=test
	make rpms
	make install
	make eraseconfig
	/sbin/service cobblerd restart
	-(make nosetests)
	make restorestate prefix=test
	/sbin/service cobblerd restart

nosetests:
	PYTHONPATH=./cobbler/ nosetests -v -w newtests/ 2>&1 | tee test.log

build:
	python setup.py build -f

# Assume we're on RedHat by default ('apache' user),
# otherwise Debian / Ubuntu ('www-data' user)
install: build
	if [ -n "`getent passwd apache`" ] ; then \
		python setup.py install -f; \
		chown -R apache /usr/share/cobbler/web; \
		chown -R apache /var/lib/cobbler/webui_sessions; \
	else \
		python setup.py install -f --install-layout=deb; \
		chown -R www-data /usr/share/cobbler/web; \
		chown -R www-data /var/lib/cobbler/webui_sessions; \
	fi

devinstall:
	-rm -rf /usr/share/cobbler
	make savestate
	make install
	make restorestate

savestate:
	mkdir -p $(statepath)
	cp -a /var/lib/cobbler/config $(statepath)
	cp /etc/cobbler/settings $(statepath)/settings
	cp /etc/cobbler/modules.conf $(statepath)/modules.conf
	if [ -d /etc/httpd ] ; then \
		cp /etc/httpd/conf.d/cobbler.conf $(statepath)/http.conf; \
		cp /etc/httpd/conf.d/cobbler_web.conf $(statepath)/cobbler_web.conf; \
	else \
		if [ -d /etc/nginx/sites-enabled ]; then \
			cp /etc/nginx/conf.d/cobbler.conf $(statepath)/http.conf; \
		else \
			cp /etc/apache2/conf.d/cobbler.conf $(statepath)/http.conf; \
			cp /etc/apache2/conf.d/cobbler_web.conf $(statepath)/cobbler_web.conf; \
		fi; \
	fi
	cp /etc/cobbler/users.conf $(statepath)/users.conf
	cp /etc/cobbler/users.digest $(statepath)/users.digest
	cp /etc/cobbler/dhcp.template $(statepath)/dhcp.template
	cp /etc/cobbler/rsync.template $(statepath)/rsync.template


# Assume we're on RedHat by default, otherwise Debian / Ubuntu
restorestate:
	cp -a $(statepath)/config /var/lib/cobbler
	cp $(statepath)/settings /etc/cobbler/settings
	cp $(statepath)/modules.conf /etc/cobbler/modules.conf
	cp $(statepath)/users.conf /etc/cobbler/users.conf
	cp $(statepath)/users.digest /etc/cobbler/users.digest
	if [ -d /etc/httpd ] ; then \
		cp $(statepath)/http.conf /etc/httpd/conf.d/cobbler.conf; \
		cp $(statepath)/cobbler_web.conf /etc/httpd/conf.d/cobbler_web.conf; \
	else \
		if [ -d /etc/nginx/sites-enabled ]; then \
			cp $(statepath)/http.conf /etc/nginx/conf.d/cobbler.conf; \
		else \
			cp $(statepath)/http.conf /etc/apache2/conf.d/cobbler.conf; \
			cp $(statepath)/cobbler_web.conf /etc/apache2/conf.d/cobbler_web.conf; \
		fi; \
	fi
	cp $(statepath)/dhcp.template /etc/cobbler/dhcp.template
	cp $(statepath)/rsync.template /etc/cobbler/rsync.template
	find /var/lib/cobbler/triggers | xargs chmod +x
	if [ -n "`getent passwd apache`" ] ; then \
		chown -R apache /var/www/cobbler; \
	else \
		chown -R www-data /usr/share/cobbler/web/cobbler_web; \
	fi
	if [ -d /var/www/cobbler ] ; then \
		chmod -R +x /usr/share/cobbler/web; \
		chmod -R +x /var/www/cobbler/svc; \
	fi
	if [ -d /usr/share/cobbler/web ] ; then \
		chmod -R +x /usr/share/cobbler/web/cobbler_web; \
		chmod -R +x /var/www/cobbler/svc; \
	fi
	rm -rf $(statepath)

completion:
	python mkbash.py

webtest: devinstall
	make clean
	make devinstall
	make restartservices

# Assume we're on RedHat by default, otherwise Debian / Ubuntu
restartservices:
	/usr/sbin/service cobblerd restart; \
	if [ -d /etc/nginx/sites-enabled ];then \
		/usr/sbin/service nginx restart; \ 
	else \
		/usr/sbin/service apache2 restart; \
	fi

sdist: clean
	python setup.py sdist

rpms: clean sdist
	mkdir -p rpm-build
	cp dist/*.gz rpm-build/
	rpmbuild --define "_topdir %(pwd)/rpm-build" \
	--define "_builddir %{_topdir}" \
	--define "_rpmdir %{_topdir}" \
	--define "_srcrpmdir %{_topdir}" \
	--define "_specdir %{_topdir}" \
	--define '_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm' \
	--define "_sourcedir  %{_topdir}" \
	-ba cobbler.spec

eraseconfig:
	-rm /var/lib/cobbler/distros*
	-rm /var/lib/cobbler/profiles*
	-rm /var/lib/cobbler/systems*
	-rm /var/lib/cobbler/repos*
	-rm /var/lib/cobbler/networks*
	-rm /var/lib/cobbler/config/distros.d/*
	-rm /var/lib/cobbler/config/images.d/*
	-rm /var/lib/cobbler/config/profiles.d/*
	-rm /var/lib/cobbler/config/systems.d/*
	-rm /var/lib/cobbler/config/repos.d/*
	-rm /var/lib/cobbler/config/networks.d/*

.PHONY: tags
tags: 
	find . \( -name build -o -name .git \) -prune -o -type f -name '*.py' -print | xargs etags -o TAGS --
