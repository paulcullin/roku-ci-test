#########################################################################
# common include file for application Makefiles
#
# Makefile Usage:
# > make
# > make install
# > make remove
#
# to exclude certain files from being added to the zipfile during packaging
# include a line like this:ZIP_EXCLUDE= -x keys\*
# that will exclude any file who's name begins with 'keys'
# to exclude using more than one pattern use additional '-x <pattern>' arguments
# ZIP_EXCLUDE= -x \*.pkg -x storeassets\*
#
# Important Notes: 
# To use the "install" and "remove" targets to install your
# application directly from the shell, you must do the following:
#
# 1) Make sure that you have the curl command line executable in your path
# 2) Set the variable ROKU_DEV_TARGET in your environment to the IP 
#    address of your Roku box. (e.g. export ROKU_DEV_TARGET=192.168.1.1.
#    Set in your this variable in your shell startup (e.g. .bashrc)
##########################################################################  
PKGREL = ../../dist/packages
ZIPREL = ../../dist/zips
SOURCEREL = ..

ROKU_DEV_USERNAME ?= rokudev
ROKU_DEV_PASSWORD ?= 1111
CURL = curl --anyauth -u $(ROKU_DEV_USERNAME):$(ROKU_DEV_PASSWORD)


.PHONY: all $(APPNAME)

$(APPNAME): $(APPDEPS)
	@echo "*** Creating $(APPNAME).zip ***"

	@echo "  >> removing old application zip $(ZIPREL)/$(APPNAME).zip"
	@if [ -e "$(ZIPREL)/$(APPNAME).zip" ]; \
	then \
		rm  $(ZIPREL)/$(APPNAME).zip; \
	fi

	@echo "  >> creating destination directory $(ZIPREL)"	
	@if [ ! -d $(ZIPREL) ]; \
	then \
		mkdir -p $(ZIPREL); \
	fi

	@echo "  >> setting directory permissions for $(ZIPREL)"
	@if [ ! -w $(ZIPREL) ]; \
	then \
		chmod 755 $(ZIPREL); \
	fi

# zip .png files without compression
# do not zip up Makefiles, or any files ending with '~'
	@echo "  >> creating application zip $(ZIPREL)/$(APPNAME).zip"	
	@if [ -d $(SOURCEREL)/$(APPNAME) ]; \
	then \
		(zip -0 -r "$(ZIPREL)/$(APPNAME).zip" . -i \*.png $(ZIP_EXCLUDE)); \
		(zip -9 -r "$(ZIPREL)/$(APPNAME).zip" . -x \*~ -x \*.png -x Makefile $(ZIP_EXCLUDE)); \
	else \
		echo "Source for $(APPNAME) not found at $(SOURCEREL)/$(APPNAME)"; \
	fi

	@echo "*** developer zip  $(APPNAME) complete ***"

install: $(APPNAME)
	@echo "Installing $(APPNAME) to host $(ROKU_DEV_TARGET)"
	@$(CURL) -s -S -F "mysubmit=Install" -F "archive=@$(ZIPREL)/$(APPNAME).zip" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//"

pkg: ROKU_PKG_PASSWORD ?= "$(shell read -p "Roku packaging password: " REPLY; echo $$REPLY)"
pkg: install
	@echo "*** Creating Package ***"

	@echo "  >> creating destination directory $(PKGREL)"
	@if [ ! -d $(PKGREL) ]; \
	then \
		mkdir -p $(PKGREL); \
	fi

	@echo "  >> setting directory permissions for $(PKGREL)"
	@if [ ! -w $(PKGREL) ]; \
	then \
		chmod 755 $(PKGREL); \
	fi

	@echo "Packaging  $(APPNAME) on host $(ROKU_DEV_TARGET)"

	$(eval PKGFILE := $(shell $(CURL) -s -S -Fmysubmit=Package -Fapp_name=$(APPNAME)/$(VERSION) -Fpasswd=$(ROKU_PKG_PASSWORD) -Fpkg_time=`date +%s` "http://$(ROKU_DEV_TARGET)/plugin_package" | grep 'pkgs' | sed 's/.*href=\"\([^\"]*\)\".*/\1/' | sed 's#pkgs//##'))
	@echo $(PKGFILE)

	@if [ -z $(PKGFILE) ]; \
	then \
		echo "Package creation failed! Have you rekeyed your Roku?"; \
		exit 1; \
	fi

	$(eval PKGFULLPATH := $(PKGREL)/$(APPTITLE)_$(VERSION).pkg)
	@echo "Downloading package to " $(PKGFULLPATH)
	curl -v --user $(ROKU_DEV_USERNAME):$(ROKU_DEV_PASSWORD) --digest -o $(PKGFULLPATH) http://$(ROKU_DEV_TARGET)/pkgs/$(PKGFILE)

	@if [ ! -f ""$(PKGFULLPATH)"" ]; \
	then \
		echo "Package download failed! File does not exist: " $(PKGFULLPATH); \
		exit 2; \
	fi

	@echo "*** Package $(APPTITLE) complete ***"

remove:
	@echo "Removing $(APPNAME) from host $(ROKU_DEV_TARGET)"
	@$(CURL) -s -S -F "mysubmit=Delete" -F "archive=" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//"

