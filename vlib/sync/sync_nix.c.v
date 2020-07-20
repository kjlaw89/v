// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module sync

import time

#flag -lpthread
#include <semaphore.h>

// [init_with=new_mutex] // TODO: implement support for this struct attribute, and disallow Mutex{} from outside the sync.new_mutex() function.
[ref_only]
pub struct Mutex {
	mutex C.pthread_mutex_t
}

[ref_only]
pub struct RwMutex {
	mutex C.pthread_rwlock_t
}

[ref_only]
struct RwMutexAttr {
	attr C.pthread_rwlockattr_t
}

/* MacOSX has no unnamed semaphores and no `timed_wait()` at all
   so we emulate the behaviour with other devices */
struct MacOSX_Semaphore {
	mtx C.pthread_mutex_t
	cond C.pthread_cond_t
mut:
	count int
}

[ref_only]
struct PosixSemaphore {
	sem C.sem_t
}

[ref_only]
struct CondAttr {
	attr C.pthread_condattr_t
}

pub struct Semaphore {
	/*
	$if macos {
		sem &MacOSX_Semaphore
	} $else {
		sem &PosixSemaphore
	}
	*/
	sem voidptr // since the above does not work, yet
}

pub fn new_mutex() &Mutex {
	m := &Mutex{}
	C.pthread_mutex_init(&m.mutex, C.NULL)
	return m
}

pub fn new_rwmutex() &RwMutex {
	m := &RwMutex{}
	a := &RwMutexAttr{}
	C.pthread_rwlockattr_init(&a.attr)
	// Give writer priority over readers
	C.pthread_rwlockattr_setkind_np(&a.attr, C.PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP)
	C.pthread_rwlockattr_setpshared(&a.attr, C.PTHREAD_PROCESS_PRIVATE)
	C.pthread_rwlock_init(&m.mutex, &a.attr)
	return m
}

// m_lock(), for *manual* mutex handling, since `lock` is a keyword
pub fn (mut m Mutex) m_lock() {
	C.pthread_mutex_lock(&m.mutex)
}

pub fn (mut m Mutex) unlock() {
	C.pthread_mutex_unlock(&m.mutex)
}

// RwMutex has separate read- and write locks
pub fn (mut m RwMutex) r_lock() {
	C.pthread_rwlock_rdlock(&m.mutex)
}

pub fn (mut m RwMutex) w_lock() {
	C.pthread_rwlock_wrlock(&m.mutex)
}

// Windows SRWLocks have different function to unlock
// So provide two functions here, too, to have a common interface
pub fn (mut m RwMutex) r_unlock() {
	C.pthread_rwlock_unlock(&m.mutex)
}

pub fn (mut m RwMutex) w_unlock() {
	C.pthread_rwlock_unlock(&m.mutex)
}

pub fn new_semaphore() Semaphore {
	$if macos {
		s := Semaphore{
			sem: &MacOSX_Semaphore{count: 0}
		}
		C.pthread_mutex_init(&&MacOSX_Semaphore(s.sem).mtx, C.NULL)
		a := &CondAttr{}
		C.pthread_condattr_init(&a.attr)
		C.pthread_condattr_setpshared(&a.attr, C.PTHREAD_PROCESS_PRIVATE)
		C.pthread_cond_init(&&MacOSX_Semaphore(s.sem).cond, &a.attr)
		return s
	} $else {
		s := Semaphore{
			sem: &PosixSemaphore{}
		}
		C.sem_init(&&PosixSemaphore(s.sem).sem, 0, 0)
		return s
	}
}

pub fn (s Semaphore) post() {
	$if macos {
		C.pthread_mutex_lock(&&MacOSX_Semaphore(s.sem).mtx)
		(&MacOSX_Semaphore(s.sem)).count++
		C.pthread_cond_signal(&&MacOSX_Semaphore(s.sem).cond)
		C.pthread_mutex_unlock(&&MacOSX_Semaphore(s.sem).mtx)
	} $else {
		C.sem_post(&&PosixSemaphore(s.sem).sem)
	}
}

pub fn (s Semaphore) wait() {
	$if macos {
		C.pthread_mutex_lock(&&MacOSX_Semaphore(s.sem).mtx)
		for &MacOSX_Semaphore(s.sem).count == 0 {
			C.pthread_cond_wait(&&MacOSX_Semaphore(s.sem).cond, &&MacOSX_Semaphore(s.sem).mtx)
		}
		(&MacOSX_Semaphore(s.sem)).count--
		C.pthread_mutex_unlock(&&MacOSX_Semaphore(s.sem).mtx)
	} $else {
		C.sem_wait(&&PosixSemaphore(s.sem).sem)
	}
}

pub fn (s Semaphore) try_wait() bool {
	$if macos {
		t_spec := time.zero_timespec()
		C.pthread_mutex_lock(&&MacOSX_Semaphore(s.sem).mtx)
		for &MacOSX_Semaphore(s.sem).count == 0 {
			res := C.pthread_cond_timedwait(&&MacOSX_Semaphore(s.sem).cond, &&MacOSX_Semaphore(s.sem).mtx, &t_spec)
			if res == C.ETIMEDOUT {
				break
			}
		}
		mut res := false
		if &MacOSX_Semaphore(s.sem).count > 0 { // success
			(&MacOSX_Semaphore(s.sem)).count--
			res = true
		}
		C.pthread_mutex_unlock(&&MacOSX_Semaphore(s.sem).mtx)
		return res
	} $else {
		return C.sem_trywait(&&PosixSemaphore(s.sem).sem) == 0
	}
}

pub fn (s Semaphore) timed_wait(timeout time.Duration) bool {
	t_spec := timeout.timespec()
	$if macos {
		C.pthread_mutex_lock(&&MacOSX_Semaphore(s.sem).mtx)
		for &MacOSX_Semaphore(s.sem).count == 0 {
			res := C.pthread_cond_timedwait(&&MacOSX_Semaphore(s.sem).cond, &&MacOSX_Semaphore(s.sem).mtx, &t_spec)
			if res == C.ETIMEDOUT {
				break
			}
		}
		mut res := false
		if &MacOSX_Semaphore(s.sem).count > 0 { // success
			(&MacOSX_Semaphore(s.sem)).count--
			res = true
		}
		C.pthread_mutex_unlock(&&MacOSX_Semaphore(s.sem).mtx)
		return res
	} $else {
		return C.sem_timedwait(&&PosixSemaphore(s.sem).sem, &t_spec) == 0
	}
}
