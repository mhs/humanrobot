# Description:
#   Alarm your people
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot remind me at <time> to <action> repeat <repeat>
#
# Author:
#   ross-hunter

moment = require 'moment'

class Reminders
  constructor: (@robot) ->
    @cache = []
    @current_timeout = null

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.reminders
        @cache = @robot.brain.data.reminders
        @queue()

  add: (reminder) ->
    @cache.push reminder
    @cache.sort (a, b) -> a.time - b.time
    @robot.brain.data.reminders = @cache
    @queue()

  removeFirst: ->
    reminder = @cache.shift()
    @robot.brain.data.reminders = @cache
    return reminder

  queue: ->
    clearTimeout @current_timeout if @current_timeout
    if @cache.length > 0
      now = new Date().getTime()
      @removeFirst() until @cache.length is 0 or @cache[0].time > now
      if @cache.length > 0
        trigger = =>
          reminder = @removeFirst()
          @robot.reply reminder.msg_envelope, 'you asked me to remind you to ' + reminder.action
          if reminder.repeat != "none"
            reminder.nextRepeat
            @.add reminder
          @queue()
        # setTimeout uses a 32-bit INT
        extendTimeout = (timeout, callback) ->
          if timeout > 0x7FFFFFFF
            @current_timeout = setTimeout ->
              extendTimeout (timeout - 0x7FFFFFFF), callback
            , 0x7FFFFFFF
          else
            @current_timeout = setTimeout callback, timeout
        extendTimeout @cache[0].time - now, trigger

class Reminder
  constructor: (@msg_envelope, @time, @action, @repeat) ->

  dueDate: ->
    @time.format()

  nextRepeat: ->
    if @repeat == "daily"
      @time = @time.add('days', 1)
    else if @repeat == "weekly"
      @time = @time.add('weeks', 1)


module.exports = (robot) ->

  reminders = new Reminders robot

  # robot.respond /remind me at (.*)? to (.*)? repeat (none|daily|weekly)/i, (msg) ->
  robot.respond /remind me/i, (msg) ->
    # time = moment(msg.match[1])
    # action = msg.match[2]
    # repeat = msg.match[3]
    time = moment(new Date('may 19 14:00')).year(moment().year())
    msg.send time.format()
    action = "do things"
    repeat = "none"
    reminder = new Reminder msg.envelope, time, action, repeat
    reminders.add reminder
    msg.send 'I\'ll remind you to ' + action + ' on ' + reminder.dueDate() + ' and repeat ' + repeat
