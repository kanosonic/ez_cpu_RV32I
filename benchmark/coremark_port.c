#include "coremark.h"
#include "core_portme.h"

static CORE_TICKS fake_start;
static CORE_TICKS fake_stop;

ee_u32 default_num_contexts = 1;
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

int
ee_printf(const char *fmt, ...)
{
    (void)fmt;
    return 0;
}

void *
portable_malloc(ee_size_t size)
{
    (void)size;
    return NULL;
}

void
portable_free(void *p)
{
    (void)p;
}

void
start_time(void)
{
    fake_start = 0;
}

void
stop_time(void)
{
    fake_stop = 10;
}

CORE_TICKS
get_time(void)
{
    return fake_stop - fake_start;
}

secs_ret
time_in_secs(CORE_TICKS ticks)
{
    return ticks;
}

void
portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    p->portable_id = 1;
}

void
portable_fini(core_portable *p)
{
    p->portable_id = 0;
}
