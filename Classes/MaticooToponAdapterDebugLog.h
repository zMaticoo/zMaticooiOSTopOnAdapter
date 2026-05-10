//
//  MaticooToponAdapterDebugLog.h
//  Optional NSLog-style traces for MaticooToponAdapter (off unless MATICOO_TOPON_ADAPTER_LOG is set).
//

#ifndef MaticooToponAdapterDebugLog_h
#define MaticooToponAdapterDebugLog_h

#ifdef MATICOO_TOPON_ADAPTER_LOG
#define MaticooToponAdapterDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define MaticooToponAdapterDebugLog(...)
#endif

#endif /* MaticooToponAdapterDebugLog_h */
