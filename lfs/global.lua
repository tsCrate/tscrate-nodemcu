HttpTimer = nil

-- Setup server queue for requests to API
RequestQueue = {}
-- Setup server request is in flight
RequestInFlight = false
-- Setup server timer for status requests to API
StatusTimer = tmr.create()

-- Setup server states
SetupReqFailed = false
SetupCodeExpired = false
ServerUnreachable = false
SetupCodeRequested = false

-- Data files queued to be uploaded
QueuedFileNames = {}
-- Current data file being uploaded
FileInFlight = nil