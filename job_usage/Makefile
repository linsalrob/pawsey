# Build the job_usage SPANK plugin against the system Slurm headers.
#   make                         build job_usage.so
#   make install PREFIX=/path    install plugin, helper and script
# Override the compiled-in defaults with e.g.
#   make BINDIR=/opt/site/bin

# Plain gcc: the Cray cc wrapper links extra libraries (libxpmem) we do not want.
ifeq ($(origin CC),default)
CC = gcc
endif
CFLAGS  ?= -O2 -Wall -Wextra -Wno-unused-parameter -Werror
SLURM_INCLUDE ?= /usr/include
BINDIR  ?= /software/pawsey/tools/pawseytools/bin
PLUGINDIR ?= /usr/lib64/slurm

DEFS = -DDEFAULT_HELPER='"$(BINDIR)/job_usage_epilog.sh"' \
       -DDEFAULT_SCRIPT='"$(BINDIR)/job_usage.sh"'

all: job_usage.so

job_usage.so: job_usage_spank.c
	$(CC) $(CFLAGS) -fPIC -shared -I$(SLURM_INCLUDE) $(DEFS) -o $@ $<

install: job_usage.so
	install -D -m 0755 job_usage.so $(DESTDIR)$(PLUGINDIR)/job_usage.so
	install -D -m 0755 job_usage_epilog.sh $(DESTDIR)$(BINDIR)/job_usage_epilog.sh
	install -D -m 0755 job_usage.sh $(DESTDIR)$(BINDIR)/job_usage.sh

clean:
	rm -f job_usage.so

.PHONY: all install clean
