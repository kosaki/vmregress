/**
 * nanotime.h
 * 
 * Support for high-resolution timers
 */
#ifndef __NANOTIME_H
#define __NONATIME_H

/**
 * rdtsc: Read the current number of clock cycles that have passed
 */
inline unsigned long long rdtsc(void)
{
	unsigned long low_time, high_time;
	asm volatile( 
		"rdtsc \n\t" 
			: "=a" (low_time),
			  "=d" (high_time));
        return ((unsigned long long)high_time << 32) | (low_time);
}

unsigned long long cycles_per_ms(void);

/**
 * cycles_per_second: Return the number of cycles that pass in a second
 */
inline unsigned long long cycles_per_second() {
	return cycles_per_ms() * 1000;
}
#endif
