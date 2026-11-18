/*
 * job_usage_spank.c - SPANK plugin that runs job_usage.sh when a job ends.
 *
 * Adds two options to sbatch/salloc/srun:
 *
 *   --job-usage[=text|csv|json]   append a usage report when the job ends
 *   --job-usage-output=PATH       write it to PATH instead of the job's
 *                                 StdOut (%j = job id, %u = user name)
 *
 * In the job epilog (run by slurmd as root on every node of the job) the
 * plugin forks a detached process, drops privileges to the job owner, and
 * execs job_usage_epilog.sh. That helper runs only on the batch host, waits
 * for sacct to report a terminal state, then runs job_usage.sh. The epilog
 * itself returns immediately, so node cleanup is never delayed.
 *
 * plugstack.conf arguments (all optional):
 *   helper=PATH   job_usage_epilog.sh   (default DEFAULT_HELPER)
 *   script=PATH   job_usage.sh          (default DEFAULT_SCRIPT)
 *   wait=SECONDS  max time to wait for sacct to finalise the job (300)
 *   default=on    report for every job, unless --job-usage=off is given
 */

#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <pwd.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <slurm/spank.h>

SPANK_PLUGIN(job_usage, 1);

#ifndef DEFAULT_HELPER
#define DEFAULT_HELPER "/software/pawsey/tools/pawseytools/bin/job_usage_epilog.sh"
#endif
#ifndef DEFAULT_SCRIPT
#define DEFAULT_SCRIPT "/software/pawsey/tools/pawseytools/bin/job_usage.sh"
#endif
#define DEFAULT_WAIT 300
#define SAFE_PATH "/usr/local/bin:/usr/bin:/bin"

static char helper_path[1024] = DEFAULT_HELPER;
static char script_path[1024] = DEFAULT_SCRIPT;
static int wait_secs = DEFAULT_WAIT;
static int default_on = 0;

static int check_format(int val, const char *optarg, int remote);
static int check_output(int val, const char *optarg, int remote);

static struct spank_option opt_usage = {
	"job-usage", "[text|csv|json|off]",
	"Append a job_usage.sh report (CPU, memory, walltime efficiency and "
	"service units) to the job output when the job ends.",
	2, 0, check_format
};

static struct spank_option opt_output = {
	"job-usage-output", "PATH",
	"Write the --job-usage report to PATH instead of the job's stdout "
	"file (%j = job id, %u = user name). Implies --job-usage.",
	1, 1, check_output
};

static int valid_format(const char *f)
{
	return !strcmp(f, "text") || !strcmp(f, "csv") ||
	       !strcmp(f, "json") || !strcmp(f, "off");
}

static int check_format(int val, const char *optarg, int remote)
{
	if (optarg && *optarg && !valid_format(optarg)) {
		slurm_error("job_usage: --job-usage takes text, csv, json or "
			    "off, not '%s'", optarg);
		return -1;
	}
	return 0;
}

static int check_output(int val, const char *optarg, int remote)
{
	if (!optarg || !*optarg || strlen(optarg) >= 4096) {
		slurm_error("job_usage: --job-usage-output needs a path");
		return -1;
	}
	return 0;
}

static void parse_args(int ac, char **av)
{
	for (int i = 0; i < ac; i++) {
		if (!strncmp(av[i], "helper=", 7))
			snprintf(helper_path, sizeof(helper_path), "%s",
				 av[i] + 7);
		else if (!strncmp(av[i], "script=", 7))
			snprintf(script_path, sizeof(script_path), "%s",
				 av[i] + 7);
		else if (!strncmp(av[i], "wait=", 5))
			wait_secs = atoi(av[i] + 5);
		else if (!strcmp(av[i], "default=on"))
			default_on = 1;
		else if (!strcmp(av[i], "default=off"))
			default_on = 0;
		else
			slurm_error("job_usage: unknown plugstack argument "
				    "'%s'", av[i]);
	}
	if (wait_secs < 0)
		wait_secs = DEFAULT_WAIT;
}

int slurm_spank_init(spank_t sp, int ac, char **av)
{
	parse_args(ac, av);

	if (spank_option_register(sp, &opt_usage) != ESPANK_SUCCESS ||
	    spank_option_register(sp, &opt_output) != ESPANK_SUCCESS) {
		slurm_error("job_usage: failed to register options");
		return -1;
	}
	return 0;
}

/*
 * Child side of the fork: become the job owner, detach, and exec the helper.
 * Never returns.
 */
static void run_helper(uid_t uid, gid_t gid, uint32_t jobid,
		       const char *format, const char *output)
{
	struct passwd *pw;
	char jobid_s[32], wait_s[32];
	int fd;

	if (setsid() < 0)
		_exit(1);

	/* Second fork: the grandchild is reparented to init, so slurmd
	 * never waits on it. */
	switch (fork()) {
	case -1:
		_exit(1);
	case 0:
		break;
	default:
		_exit(0);
	}

	pw = getpwuid(uid);
	if (!pw)
		_exit(1);

	if (initgroups(pw->pw_name, gid) < 0 || setgid(gid) < 0 ||
	    setuid(uid) < 0)
		_exit(1);
	/* Refuse to continue if root could be regained. */
	if (uid != 0 && (setuid(0) == 0 || geteuid() == 0))
		_exit(1);

	if (chdir(pw->pw_dir) < 0 && chdir("/") < 0)
		_exit(1);
	umask(022);

	fd = open("/dev/null", O_RDWR);
	if (fd >= 0) {
		dup2(fd, STDIN_FILENO);
		dup2(fd, STDOUT_FILENO);
		dup2(fd, STDERR_FILENO);
		if (fd > STDERR_FILENO)
			close(fd);
	}
	for (fd = STDERR_FILENO + 1; fd < 1024; fd++)
		close(fd);

	signal(SIGHUP, SIG_IGN);
	signal(SIGTERM, SIG_DFL);
	signal(SIGINT, SIG_DFL);

	snprintf(jobid_s, sizeof(jobid_s), "%u", jobid);
	snprintf(wait_s, sizeof(wait_s), "%d", wait_secs);

	clearenv();
	setenv("PATH", SAFE_PATH, 1);
	setenv("HOME", pw->pw_dir, 1);
	setenv("USER", pw->pw_name, 1);
	setenv("LOGNAME", pw->pw_name, 1);
	setenv("SHELL", "/bin/bash", 1);

	execl(helper_path, helper_path, "--jobid", jobid_s,
	      "--format", format, "--output", output ? output : "",
	      "--script", script_path, "--wait", wait_s, (char *) NULL);
	_exit(127);
}

int slurm_spank_job_epilog(spank_t sp, int ac, char **av)
{
	char *format = NULL, *output = NULL;
	int requested = default_on;
	uint32_t jobid = 0;
	uid_t uid;
	gid_t gid;
	pid_t pid;

	/* job_script context never calls slurm_spank_init and shares no
	 * state with it, so read the plugstack.conf arguments again here. */
	parse_args(ac, av);

	if (spank_option_getopt(sp, &opt_usage, &format) == ESPANK_SUCCESS)
		requested = 1;
	if (spank_option_getopt(sp, &opt_output, &output) == ESPANK_SUCCESS)
		requested = 1;
	if (!format || !*format)
		format = "text";
	if (!requested || !strcmp(format, "off"))
		return 0;
	if (!valid_format(format)) {
		slurm_error("job_usage: ignoring invalid format '%s'", format);
		return 0;
	}

	if (spank_get_item(sp, S_JOB_ID, &jobid) != ESPANK_SUCCESS ||
	    spank_get_item(sp, S_JOB_UID, &uid) != ESPANK_SUCCESS ||
	    spank_get_item(sp, S_JOB_GID, &gid) != ESPANK_SUCCESS) {
		slurm_error("job_usage: could not read job id/uid/gid");
		return 0;
	}
	if (uid == 0) {
		slurm_verbose("job_usage: not reporting for root job %u",
			      jobid);
		return 0;
	}
	if (access(helper_path, X_OK) < 0) {
		slurm_error("job_usage: helper %s is not executable: %m",
			    helper_path);
		return 0;
	}

	pid = fork();
	if (pid < 0) {
		slurm_error("job_usage: fork failed: %m");
		return 0;
	}
	if (pid == 0)
		run_helper(uid, gid, jobid, format, output);

	/* Reap the intermediate child; the grandchild runs on alone. */
	while (waitpid(pid, NULL, 0) < 0 && errno == EINTR)
		;

	/* A failed report must never fail the epilog and drain the node. */
	return 0;
}
