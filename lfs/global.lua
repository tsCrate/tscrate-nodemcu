HttpTimer = nil
DataSets = {}
RequestQueue = {}
RequestInFlight = false
StatusTimer = tmr.create()

SetupReqFailed = false
SetupCodeExpired = false
ServerUnreachable = false
SetupCodeRequested = false
