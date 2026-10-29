#ifndef TUNGUSKA_SC_SHIM_H
#define TUNGUSKA_SC_SHIM_H

#import <SystemConfiguration/SystemConfiguration.h>

/*
 * Swift cannot import C functions that return an untyped CFPropertyListRef
 * (ARC cannot infer the memory management convention), and this SDK no
 * longer ships SCPreferencesCopyValue. These wrappers transfer ownership
 * explicitly so Swift receives an ordinary, ARC-managed optional.
 */

CFPropertyListRef _Nullable CF_RETURNS_RETAINED
tunguska_SCPreferencesGetValue(
    SCPreferencesRef prefs,
    CFStringRef key);

CFDictionaryRef _Nullable CF_RETURNS_RETAINED
tunguska_SCPreferencesCopyServicesDictionary(
    SCPreferencesRef prefs,
    CFStringRef key);

#endif /* TUNGUSKA_SC_SHIM_H */
