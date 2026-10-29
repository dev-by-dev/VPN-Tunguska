#include "tunguska_sc.h"

CFPropertyListRef CF_RETURNS_RETAINED
tunguska_SCPreferencesGetValue(SCPreferencesRef prefs, CFStringRef key) {
    // SCPreferencesGetValue lends the value owned by the preferences session
    // (invalidated by subsequent session calls), so retain it before handing
    // it to ARC.
    CFPropertyListRef value = SCPreferencesGetValue(prefs, key);
    if (value == NULL) {
        return NULL;
    }
    return CFRetain(value);
}

CFDictionaryRef CF_RETURNS_RETAINED
tunguska_SCPreferencesCopyServicesDictionary(SCPreferencesRef prefs, CFStringRef key) {
    CFPropertyListRef value = tunguska_SCPreferencesGetValue(prefs, key);
    if (value == NULL) {
        return NULL;
    }
    if (CFGetTypeID(value) != CFDictionaryGetTypeID()) {
        CFRelease(value);
        return NULL;
    }
    return (CFDictionaryRef)value;
}
