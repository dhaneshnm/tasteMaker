# How a scheduled day is written, in one place: the masthead, the queue, and
# the flash messages all read from here.
Date::DATE_FORMATS[:daily] = "%a, %b %-d"       # Mon, Aug 3
Date::DATE_FORMATS[:daily_long] = "%A, %B %-d"  # Monday, August 3
