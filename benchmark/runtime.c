#include <stdint.h>

uint32_t
__mulsi3(uint32_t a, uint32_t b)
{
    uint32_t result = 0;

    while (b != 0)
    {
        if (b & 1U)
        {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }

    return result;
}

uint32_t
__udivsi3(uint32_t num, uint32_t den)
{
    uint32_t bit = 1;
    uint32_t result = 0;

    if (den == 0)
    {
        return 0xFFFFFFFFU;
    }

    while ((den < num) && ((den & 0x80000000U) == 0))
    {
        den <<= 1;
        bit <<= 1;
    }

    while (bit != 0)
    {
        if (num >= den)
        {
            num -= den;
            result |= bit;
        }
        den >>= 1;
        bit >>= 1;
    }

    return result;
}

uint32_t
__umodsi3(uint32_t num, uint32_t den)
{
    uint32_t bit = 1;

    if (den == 0)
    {
        return num;
    }

    while ((den < num) && ((den & 0x80000000U) == 0))
    {
        den <<= 1;
        bit <<= 1;
    }

    while (bit != 0)
    {
        if (num >= den)
        {
            num -= den;
        }
        den >>= 1;
        bit >>= 1;
    }

    return num;
}
