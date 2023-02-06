
/*
 * (C) 2010-2011 Alibaba Group Holding Limited
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */


#include "tsar.h"


struct statistic statis;
struct configure conf;
struct module   *mods[MAX_MOD_NUM];
struct module_sub *mod_subs[MAX_MODSUB_NUM];

pthread_mutex_t module_record_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t module_warn_mutex = PTHREAD_MUTEX_INITIALIZER;
U_64 fire_warn;

void
usage()
{
    int    i;
    struct module *mod;

    fprintf(stderr,
            "Usage: mservice [options]\n"
            "Options:\n"
#ifdef OLDTSAR
            /*used for check alert*/
            "    -check         display last record for alert\n"
            /*end*/
#endif
            "    --check/-C     display last record for alert.example:sysak mservice --check / tsar --check --cpu --io\n"
            "    --watch/-w     display last records in N mimutes. example:sysak mservice --watch 30 / tsar --watch 30 --cpu --io\n"
            "    --cron/-c      run in cron mode, output data to file\n"
            "    --interval/-i  specify intervals numbers, in minutes if with --live, it is in seconds\n"
            "    --list/-L      list enabled modules\n"
            "    --live/-l      running print live mode, which module will print\n"
            "    --file/-f      specify a filepath as input\n"
            "    --ndays/-n     show the value for the past days (default: 1)\n"
            "    --date/-d      show the value for the specify day(n or YYYYMMDD)\n"
            "    --merge/-m     merge multiply item to one\n"
            "    --detail/-D    do not conver data to K/M/G\n"
            "    --spec/-s      show spec field data, sysak mservice --cpu -s sys,util\n"
            "    --item/-I      show spec item data, sysak mservice --io -I sda\n"
            "    --serv/-S      run as service \n"
            "    --help/-h      help\n");

    fprintf(stderr,
            "Modules Enabled:\n"
           );

    for (i = 0; i < statis.total_mod_num; i++) {
        mod = mods[i];
        fprintf(stderr, "%s\n", mod->usage);
    }

    exit(0);
}


struct option longopts[] = {
    { "cron", no_argument, NULL, 'c' },
    { "check", no_argument, NULL, 'C' },
    { "watch", required_argument, NULL, 'w' },
    { "interval", required_argument, NULL, 'i' },
    { "list", no_argument, NULL, 'L' },
    { "live", no_argument, NULL, 'l' },
    { "file", required_argument, NULL, 'f' },
    { "ndays", required_argument, NULL, 'n' },
    { "date", required_argument, NULL, 'd' },
    { "merge", no_argument, NULL, 'm' },
    { "detail", no_argument, NULL, 'D' },
    { "spec", required_argument, NULL, 's' },
    { "item", required_argument, NULL, 'I' },
    { "serv", no_argument, NULL, 'S' },
    { "help", no_argument, NULL, 'h' },
    { 0, 0, 0, 0},
};


static void
main_init(int argc, char **argv)
{
    int    opt, oind = 0;
#ifdef OLDTSAR
    /* check option for tsar1.0 */
    if (argc >= 2) {
        if (!strcmp(argv[1], "-check") && argc == 2) {
            conf.running_mode = RUN_CHECK;
            conf.print_mode = DATA_DETAIL;
            conf.print_interval = 60;
            conf.print_tail = 0;
            conf.print_nline_interval = conf.print_interval;
            return;
        }
    }
    /*end*/
#endif
    while ((opt = getopt_long(argc, argv, ":cCw:i:Llf:n:d:s:I:mhDS", longopts, NULL)) != -1) {
        oind++;
        switch (opt) {
            case 'c':
                conf.running_mode = RUN_CRON;
                break;
            case 'C':
                conf.running_mode = RUN_CHECK_NEW;
                break;
            case 'w':
                conf.running_mode = RUN_WATCH;
                conf.print_nminute = atoi(optarg);
                oind++;
                break;
            case 'i':
                conf.print_interval = atoi(optarg);
                oind++;
                break;
            case 'L':
                conf.running_mode = RUN_LIST;
                break;
            case 'l':
                conf.running_mode = RUN_PRINT_LIVE;
                break;
            case 'f':
                strncpy(conf.output_file_path, optarg, LEN_128);
                break;
            case 's':
                set_special_field(optarg);
                break;
            case 'I':
                set_special_item(optarg);
                break;
            case 'n':
                conf.print_ndays = atoi(optarg);
                oind++;
                break;
            case 'd':
                conf.print_day = atoi(optarg);
                oind++;
                break;
            case 'm':
                conf.print_merge  = MERGE_ITEM;
                break;
            case 'D':
                conf.print_detail = TRUE;
                break;
            case 'S':
                conf.running_mode = RUN_SERVICE;
                break;
            case 'h':
                usage();
                break;
            case ':':
                printf("must have parameter\n");
                usage();
                break;
            case '?':
                if (argv[oind] && strstr(argv[oind], "--")) {
                    strncat(conf.output_print_mod, argv[oind], LEN_512 - sizeof(DATA_SPLIT));
                    strcat(conf.output_print_mod, DATA_SPLIT);

                } else {
                    usage();
                }
        }
    }
    /* set default parameter */
    if (!conf.print_ndays) {
        conf.print_ndays = 1;
    }

    if (!conf.print_interval) {
        conf.print_interval = DEFAULT_PRINT_INTERVAL;
    }

    if (RUN_NULL == conf.running_mode) {
        conf.running_mode = RUN_PRINT;

    } else if (conf.running_mode == RUN_CHECK_NEW) {
        conf.print_interval = 60;
        conf.print_tail = 0;
    }

    if (!strlen(conf.output_print_mod)) {
        conf.print_mode = DATA_SUMMARY;

    } else {
        conf.print_mode = DATA_DETAIL;
    }

    strcpy(conf.config_file, DEFAULT_CONF_FILE_PATH);
    if (access(conf.config_file, F_OK)) {
        do_debug(LOG_FATAL, "main_init: can't find tsar.conf");
    }
}


void
shut_down()
{
    free_modules();

/*
    memset(&conf, 0, sizeof(struct configure));
    memset(mods, 0, sizeof(mods));
    memset(&statis, 0, sizeof(struct statistic));
*/
}


void
running_list()
{
    int    i;
    struct module *mod;

    printf("tsar enable follow modules:\n");

    for (i = 0; i < statis.total_mod_num; i++) {
        mod = mods[i];
        printf("    %s\n", mod->name + 4);
    }
}


void
running_cron()
{
    int    have_collect = 0;
    /* output interface */
    if (strstr(conf.output_interface, "file")) {
        /* output data */
        collect_record();
        output_file();
        have_collect = 1;
    }

    if (strstr(conf.output_interface, "db")) {
        output_db(have_collect);
    }
    if (strstr(conf.output_interface, "nagios")) {
        output_nagios();
    }
    if (strstr(conf.output_interface, "tcp")) {
        output_multi_tcp(have_collect);
    }
}

void *cron_thread(void *arg)
{
    while (1) {
	pthread_mutex_lock(&module_record_mutex);
	statis.cur_time = time(NULL);
        running_cron();
	collect_record_stat();
	pthread_mutex_unlock(&module_record_mutex);
        sleep(conf.cron_period);
    }
}

extern unsigned int gnr_cpus;
void *warn_record_thread(void *arg)
{
	struct top_utils top;

	if (strlen(conf.output_directory) < 1)
		return 0;
	/* Todo: The inits of all warn events may be summary in *a* function */
	init_top_struct(&top, conf.output_directory);
	gnr_cpus = sysconf(_SC_NPROCESSORS_CONF);
	while (1) {
		/* dispatch it */
		if (fire_warn | PERCPU_TRIGER<<32) {
 			record_top_util_proces(&top);
			fire_warn &= ~(PERCPU_TRIGER<<32);
		}
		/* todo: ugly! we should be sync but not poll, please help me!!^_^ */
		sleep(1);
	}
}

void run_agent(void)
{
    system(conf.agent_cmd);
}

static void serivce_main(void)
{
    pthread_t th, th_warn;
    int res;

    printf("server mode %s\n", conf.server_mode);
    if (strstr(conf.server_mode, "local")) {
        printf("mservice start local server..\n");
        res = pthread_create(&th, NULL, cron_thread, NULL);
        if (res) {
           printf("create cron thread failed\n");
           return;
        }
    }
	res = pthread_create(&th_warn, NULL, warn_record_thread, NULL);
	if (res) {
		printf("create warn record thread failed\n");
		return;
	}

    if (strstr(conf.server_mode, "http")) {
        printf("mservice start http server..\n");
        http_server();
    }

    if (strstr(conf.server_mode, "agent")){
        printf("mservice start agent: %s\n", conf.agent_cmd);
        run_agent();
    }

}

int
main(int argc, char **argv)
{

    parse_config_file(DEFAULT_CONF_FILE_PATH);

    load_modules();

    statis.cur_time = time(NULL);

    conf.print_day = -1;

    main_init(argc, argv);
    /*
     * enter running
     */
    switch (conf.running_mode) {
        case RUN_LIST:
            running_list();
            break;

        case RUN_CRON:
            conf.print_mode = DATA_DETAIL;
            running_cron();
            break;
#ifdef OLDTSAR
            /*for check option*/
        case RUN_CHECK:
            reload_check_modules();
            /* disable module when n_col is zero */
            running_check(RUN_CHECK);
            break;
            /*end*/
#endif
        case RUN_CHECK_NEW:
            if (reload_modules(conf.output_print_mod)) {
                conf.print_mode = DATA_DETAIL;
            };
            /* disable module when n_col is zero */
            disable_col_zero();
            running_check(RUN_CHECK_NEW);
            break;
        case RUN_PRINT:
            /* reload module by output_stdio_mod and output_print_mod*/
            reload_modules(conf.output_stdio_mod);
            reload_modules(conf.output_print_mod);

            /* disable module when n_col is zero */
            disable_col_zero();

            /* set conf.print_nline_interval */
            conf.print_nline_interval = conf.print_interval;

            running_print();
            break;

        case RUN_PRINT_LIVE:
            /* reload module by output_stdio_mod and output_print_mod*/
            reload_modules(conf.output_stdio_mod);
            reload_modules(conf.output_print_mod);

            /* disable module when n_col is zero */
            disable_col_zero();

            running_print_live();
            break;
        case RUN_WATCH:
            /* reload module by output_stdio_mod and output_print_mod*/
            reload_modules(conf.output_stdio_mod);
            reload_modules(conf.output_print_mod);

            /* disable module when n_col is zero */
            disable_col_zero();

            /* set conf.print_nline_interval */
            conf.print_nline_interval = conf.print_interval;

            running_print();
            break;
        case RUN_SERVICE:
            serivce_main();
            break;

        default:
            break;
    }

    shut_down();
    return 0;
}
